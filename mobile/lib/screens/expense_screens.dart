import 'dart:convert';

import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Expense claims: members see their own, unit admins their unit, finance approves.
class ExpensesScreen extends StatelessWidget {
  const ExpensesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense claims'),
        actions: [
          if (AppState.i.can('claim_expense'))
            IconButton(tooltip: 'New claim', icon: const Icon(Icons.add), onPressed: () => push(context, const NewClaimScreen())),
        ],
      ),
      body: Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}expenses') as Map),
        builder: (context, d) {
          final claims = (d['claims'] as List?) ?? [];
          final totals = (d['totals'] as Map?) ?? {};
          final canApprove = d['can_approve'] == true;
          final funds = [for (final f in (d['funds'] as List?) ?? []) f is Map ? f['name'].toString() : f.toString()];
          return [
            SioPanel(
              child: Row(children: [
                Stat(inr(totals['Pending']), 'Pending', color: SioColors.danger),
                Stat(inr(totals['Approved']), 'Approved'),
                Stat(inr(totals['Paid']), 'Paid', color: SioColors.ink),
              ]),
            ),
            const SizedBox(height: 12),
            if (claims.isEmpty) const EmptyNote('No claims yet.'),
            for (final c in claims) ...[ClaimCard(c: Map<String, dynamic>.from(c), canApprove: canApprove, funds: funds), const SizedBox(height: 10)],
          ];
        },
      ),
    );
  }
}

class ClaimCard extends StatelessWidget {
  const ClaimCard({super.key, required this.c, required this.canApprove, this.funds = const []});
  final Map<String, dynamic> c;
  final bool canApprove;
  final List<String> funds;

  Future<void> _set(BuildContext context, String status) async {
    String? mode;
    String? fund;
    if (status == 'Paid') {
      final r = await showModalBottomSheet<(String, String?)>(
        context: context,
        showDragHandle: true,
        builder: (sheet) => _PaySheet(amount: c['amount'], funds: funds),
      );
      if (r == null) return;
      mode = r.$1;
      fund = r.$2;
    }
    if (!context.mounted) return;
    await run(
        context,
        () => Api.call('${Api.m}set_expense_status',
            {'name': c['name'], 'status': status, 'payment_mode': mode, 'paid_from': fund}),
        done: 'Claim ${status.toLowerCase()}.');
  }

  @override
  Widget build(BuildContext context) {
    final status = c['status'].toString();
    return SioPanel(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(children: [
          Expanded(child: Text(c['description'].toString(), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600))),
          Text(inr(c['amount']), style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text([c['category'], c['event'], c['claimed_by_name'], fmtDate(c['expense_date'], 'd MMM'), if (c['paid_from'] != null) 'from ${c['paid_from']}'].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                style: const TextStyle(color: SioColors.textSecondary, fontSize: 12.5)),
          ),
          StatusChip(status, tone: StatusChip.toneFor(status)),
        ]),
        if (canApprove && status == 'Pending') ...[
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: FilledButton(
                style: FilledButton.styleFrom(backgroundColor: SioColors.green, minimumSize: const Size(48, 44)),
                onPressed: () => _set(context, 'Approved'),
                child: const Text('Approve'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: SioColors.danger, minimumSize: const Size(48, 44)),
                onPressed: () => _set(context, 'Rejected'),
                child: const Text('Reject'),
              ),
            ),
          ]),
        ],
        if (canApprove && status == 'Approved') ...[
          const SizedBox(height: 10),
          OutlinedButton(onPressed: () => _set(context, 'Paid'), child: const Text('Mark paid')),
        ],
      ]),
    );
  }
}

class NewClaimScreen extends StatefulWidget {
  const NewClaimScreen({super.key, this.event});
  final String? event;

  @override
  State<NewClaimScreen> createState() => _NewClaimScreenState();
}

class _NewClaimScreenState extends State<NewClaimScreen> {
  final _desc = TextEditingController();
  final _amount = TextEditingController();
  String _category = 'Food';
  String? _event;
  DateTime _date = DateTime.now();
  XFile? _bill;
  List<dynamic> _events = [];
  bool _busy = false;

  static const categories = ['Venue', 'Food', 'Printing', 'Travel', 'Rent', 'Materials', 'Other'];

  @override
  void initState() {
    super.initState();
    _event = widget.event;
    Api.call('${Api.m}events').then((v) {
      if (mounted) setState(() => _events = (v as List?) ?? []);
    }).catchError((_) {});
  }

  Future<void> _pick(ImageSource source) async {
    final f = await ImagePicker().pickImage(source: source, maxWidth: 1600, imageQuality: 70);
    if (f != null) setState(() => _bill = f);
  }

  Future<void> _save() async {
    if (_desc.text.trim().isEmpty || (num.tryParse(_amount.text) ?? 0) <= 0) {
      toast(context, 'Enter what it was for and the amount.');
      return;
    }
    setState(() => _busy = true);
    final ok = await run(context, () async {
      String? data;
      if (_bill != null) data = base64Encode(await _bill!.readAsBytes());
      await Api.call('${Api.m}claim_expense', {
        'description': _desc.text.trim(),
        'amount': _amount.text,
        'category': _category,
        'expense_date': apiDate(_date),
        'event': _event,
        'bill_data': data,
        'bill_filename': _bill?.name,
      });
    }, done: 'Claim sent for approval.');
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New expense claim')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        TextField(controller: _desc, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'What was it for?')),
        const SizedBox(height: 14),
        TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _category,
          decoration: const InputDecoration(labelText: 'Category'),
          items: [for (final c in categories) DropdownMenuItem(value: c, child: Text(c))],
          onChanged: (v) => setState(() => _category = v ?? _category),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          initialValue: _event,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Event (optional)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Not for an event')),
            if (_event != null && !_events.any((e) => e['name'] == _event))
              DropdownMenuItem<String?>(value: _event, child: Text(_event!)),
            for (final e in _events) DropdownMenuItem<String?>(value: e['name'].toString(), child: Text(e['title'].toString(), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _event = v),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today),
          label: Text('Spent on ${fmtDate(_date.toIso8601String(), 'd MMM yyyy')}'),
          onPressed: () async {
            final d = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 120)), lastDate: DateTime.now());
            if (d != null) setState(() => _date = d);
          },
        ),
        const SectionTitle('Bill or receipt'),
        if (_bill != null)
          SioPanel(
            child: Row(children: [
              const Icon(Icons.image_outlined, color: SioColors.blue),
              const SizedBox(width: 10),
              Expanded(child: Text(_bill!.name, overflow: TextOverflow.ellipsis)),
              IconButton(tooltip: 'Remove', icon: const Icon(Icons.close), onPressed: () => setState(() => _bill = null)),
            ]),
          )
        else
          Row(children: [
            Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.camera), icon: const Icon(Icons.photo_camera_outlined), label: const Text('Camera'))),
            const SizedBox(width: 12),
            Expanded(child: OutlinedButton.icon(onPressed: () => _pick(ImageSource.gallery), icon: const Icon(Icons.photo_outlined), label: const Text('Gallery'))),
          ]),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Send for approval')),
      ]),
    );
  }
}


/// Finance marks a claim paid: how it was paid and, optionally, which fund paid it.
class _PaySheet extends StatefulWidget {
  const _PaySheet({required this.amount, required this.funds});
  final dynamic amount;
  final List<String> funds;

  @override
  State<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends State<_PaySheet> {
  String _mode = 'Cash';
  String? _fund;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Pay ${inr(widget.amount)}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Paid by'),
            items: [for (final m in const ['Cash', 'UPI', 'Bank Transfer']) DropdownMenuItem(value: m, child: Text(m))],
            onChanged: (v) => setState(() => _mode = v ?? _mode),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String?>(
            initialValue: _fund,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Paid from (fund)'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('General account')),
              for (final f in widget.funds) DropdownMenuItem<String?>(value: f, child: Text(f, overflow: TextOverflow.ellipsis)),
            ],
            onChanged: (v) => setState(() => _fund = v),
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: () => Navigator.pop(context, (_mode, _fund)), child: const Text('Mark paid')),
        ]),
      );
}
