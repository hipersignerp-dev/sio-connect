import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

Tone _tone(String s) => switch (s) {
      'Pending' => Tone.amber,
      'Approved' => Tone.blue,
      'Released' => Tone.green,
      'Rejected' => Tone.red,
      _ => Tone.grey,
    };

/// Units ask the area for money to run a programme; finance / area admins approve and release it.
class FundRequestsScreen extends StatefulWidget {
  const FundRequestsScreen({super.key});

  @override
  State<FundRequestsScreen> createState() => _FundRequestsScreenState();
}

class _FundRequestsScreenState extends State<FundRequestsScreen> {
  int _version = 0;
  String _filter = '';

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    return Scaffold(
      appBar: AppBar(title: const Text('Programme funds')),
      floatingActionButton: s.can('request_funds')
          ? AddFab(
              tooltip: 'Ask for funds',
              onPressed: () async {
                final ok = await push(context, const FundRequestFormScreen());
                if (ok == true) setState(() => _version++);
              },
            )
          : null,
      body: Loader<Map<String, dynamic>>(
        key: ValueKey('$_version|$_filter'),
        load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}fund_requests', {'status': _filter}) as Map),
        builder: (context, d) {
          final list = (d['requests'] as List?) ?? [];
          final counts = (d['counts'] as Map?) ?? {};
          final canApprove = d['can_approve'] == true;
          final funds = [for (final f in (d['funds'] as List? ?? [])) f.toString()];
          return [
            SizedBox(
              height: 44,
              child: ListView(scrollDirection: Axis.horizontal, children: [
                for (final f in const ['', 'Pending', 'Approved', 'Released', 'Rejected', 'Closed'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.isEmpty ? 'All' : '$f${counts[f] != null ? ' (${counts[f]})' : ''}'),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                  ),
              ]),
            ),
            const SizedBox(height: 8),
            if (list.isEmpty)
              EmptyNote(s.can('request_funds') ? 'No requests yet. Tap + to ask the area for programme funds.' : 'No requests yet.'),
            for (final r in list) ...[
              _RequestCard(
                r: Map<String, dynamic>.from(r),
                canApprove: canApprove,
                funds: funds,
                changed: () => setState(() => _version++),
              ),
              const SizedBox(height: 10),
            ],
          ];
        },
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  const _RequestCard({required this.r, required this.canApprove, required this.funds, required this.changed});
  final Map<String, dynamic> r;
  final bool canApprove;
  final List<String> funds;
  final VoidCallback changed;

  Future<void> _act(BuildContext context, String action, Map<String, dynamic> extra, String done) async {
    final ok = await run(context, () => Api.call('${Api.m}set_fund_request', {'name': r['name'], 'action': action, ...extra}), done: done);
    if (ok) changed();
  }

  Future<void> _approve(BuildContext context) async {
    final amt = TextEditingController(text: numOf(r['amount_requested']).toStringAsFixed(0));
    final note = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Approve'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount approved', prefixText: '₹ ')),
          const SizedBox(height: 12),
          TextField(controller: note, decoration: const InputDecoration(labelText: 'Note (optional)')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Approve')),
        ],
      ),
    );
    if (go == true && context.mounted) {
      await _act(context, 'approve', {'approved_amount': amt.text.trim(), 'remarks': note.text.trim()}, 'Approved.');
    }
  }

  Future<void> _reject(BuildContext context) async {
    final note = TextEditingController();
    final go = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: const Text('Reject this request?'),
        content: TextField(controller: note, decoration: const InputDecoration(labelText: 'Reason (the unit will see it)')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SioColors.danger),
            onPressed: () => Navigator.pop(d, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (go == true && context.mounted) await _act(context, 'reject', {'remarks': note.text.trim()}, 'Rejected.');
  }

  Future<void> _release(BuildContext context) async {
    final res = await showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ReleaseSheet(amount: numOf(r['approved_amount']) > 0 ? r['approved_amount'] : r['amount_requested'], funds: funds),
    );
    if (res != null && context.mounted) await _act(context, 'release', res, 'Money released to ${r['unit']}.');
  }

  @override
  Widget build(BuildContext context) {
    final status = '${r['status']}';
    final released = numOf(r['released_amount']);
    return SioPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: Text('${r['title']}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink)),
          ),
          StatusChip(status, tone: _tone(status)),
        ]),
        const SizedBox(height: 4),
        Text(
          [r['unit'], r['requested_by_name'], if (r['needed_by'] != null) 'needed by ${fmtDate(r['needed_by'], 'd MMM')}', r['event']]
              .where((x) => x != null && '$x'.isNotEmpty)
              .join(' · '),
          style: const TextStyle(color: SioColors.textSecondary, fontSize: 13),
        ),
        const SizedBox(height: 12),
        Row(children: [
          Stat(inr(r['amount_requested']), 'Asked', color: SioColors.ink),
          if (numOf(r['approved_amount']) > 0) Stat(inr(r['approved_amount']), 'Approved'),
          if (released > 0) Stat(inr(released - numOf(r['spent_amount'])), 'Left', color: SioColors.green),
        ]),
        if (released > 0) ...[
          const SizedBox(height: 10),
          ProgressBar(numOf(r['spent_amount']) / released),
          const SizedBox(height: 4),
          Text('${inr(released)} released · ${inr(r['spent_amount'])} spent'
              '${r['paid_from'] != null ? ' · from ${r['paid_from']}' : ''}',
              style: const TextStyle(color: SioColors.textSecondary, fontSize: 12.5)),
        ],
        const SizedBox(height: 10),
        Text('${r['purpose']}'),
        if ((r['breakdown'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${r['breakdown']}', style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
        ],
        if ((r['remarks'] ?? '').toString().isNotEmpty) ...[
          const SizedBox(height: 8),
          SioBanner(text: 'Area: ${r['remarks']}'),
        ],
        if (canApprove && (status == 'Pending' || status == 'Approved')) ...[
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(foregroundColor: SioColors.danger),
                onPressed: () => _reject(context),
                child: const Text('Reject'),
              ),
            ),
            const SizedBox(width: 8),
            if (status == 'Pending') ...[
              Expanded(child: OutlinedButton(onPressed: () => _approve(context), child: const Text('Approve'))),
              const SizedBox(width: 8),
            ],
            Expanded(child: FilledButton(onPressed: () => _release(context), child: const Text('Release'))),
          ]),
        ],
        if (canApprove && status == 'Released') ...[
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: () => _act(context, 'close', {}, 'Closed.'), child: const Text('Close (programme done)')),
          ),
        ],
      ]),
    );
  }
}

class _ReleaseSheet extends StatefulWidget {
  const _ReleaseSheet({required this.amount, required this.funds});
  final dynamic amount;
  final List<String> funds;

  @override
  State<_ReleaseSheet> createState() => _ReleaseSheetState();
}

class _ReleaseSheetState extends State<_ReleaseSheet> {
  late final _amt = TextEditingController(text: numOf(widget.amount).toStringAsFixed(0));
  String _mode = 'UPI';
  String? _fund;

  @override
  Widget build(BuildContext context) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Release money', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(controller: _amt, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount', prefixText: '₹ ')),
          const SizedBox(height: 12),
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
          FilledButton(
            onPressed: () => Navigator.pop(context, {'released_amount': _amt.text.trim(), 'payment_mode': _mode, 'paid_from': _fund}),
            child: const Text('Release'),
          ),
        ]),
      );
}

/// A unit president / secretary asks the area for programme money.
class FundRequestFormScreen extends StatefulWidget {
  const FundRequestFormScreen({super.key});

  @override
  State<FundRequestFormScreen> createState() => _FundRequestFormScreenState();
}

class _FundRequestFormScreenState extends State<FundRequestFormScreen> {
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _purpose = TextEditingController();
  final _breakdown = TextEditingController();
  DateTime? _needed;
  String? _event;
  String? _unit;
  List<dynamic> _events = [];
  List<String> _units = [];
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    Api.call('${Api.m}events').then((v) {
      if (mounted) setState(() => _events = (v as List?) ?? []);
    }).catchError((_) {});
    if (AppState.i.can('all_units')) {
      Api.units().then((v) {
        if (mounted) setState(() => _units = [for (final u in v) u['name'].toString()]);
      }).catchError((_) {});
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      await Api.call('${Api.m}request_fund', {
        'title': _title.text.trim(),
        'amount_requested': _amount.text.trim(),
        'purpose': _purpose.text.trim(),
        'breakdown': _breakdown.text.trim(),
        'needed_by': _needed == null ? null : apiDate(_needed!),
        'event': _event,
        'unit': _unit,
      });
    }, done: 'Request sent to the area.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ask for programme funds')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        TextField(controller: _title, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Programme', hintText: 'e.g. Campus quiz')),
        const SizedBox(height: 14),
        TextField(controller: _amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount needed', prefixText: '₹ ')),
        const SizedBox(height: 14),
        TextField(
          controller: _purpose,
          maxLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'What it is for'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _breakdown,
          maxLines: 3,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Breakdown (optional)', hintText: 'Prizes 3000, printing 1000, hall 1000'),
        ),
        const SizedBox(height: 14),
        if (AppState.i.can('all_units')) ...[
          DropdownButtonFormField<String?>(
            initialValue: _unit,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'For which unit'),
            items: [for (final u in _units) DropdownMenuItem<String?>(value: u, child: Text(u))],
            onChanged: (v) => setState(() => _unit = v),
          ),
          const SizedBox(height: 14),
        ],
        DropdownButtonFormField<String?>(
          initialValue: _event,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Event (optional)'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('Not linked to an event')),
            for (final e in _events)
              DropdownMenuItem<String?>(value: e['name'].toString(), child: Text(e['title'].toString(), overflow: TextOverflow.ellipsis)),
          ],
          onChanged: (v) => setState(() => _event = v),
        ),
        const SizedBox(height: 14),
        OutlinedButton.icon(
          icon: const Icon(Icons.calendar_today, size: 18),
          label: Text(_needed == null ? 'Needed by (optional)' : 'Needed by ${fmtDate(apiDate(_needed!), 'd MMM yyyy')}'),
          onPressed: () async {
            final d = await showDatePicker(
              context: context,
              initialDate: DateTime.now().add(const Duration(days: 7)),
              firstDate: DateTime.now(),
              lastDate: DateTime.now().add(const Duration(days: 365)),
            );
            if (d != null) setState(() => _needed = d);
          },
        ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Send to area')),
      ]),
    );
  }
}
