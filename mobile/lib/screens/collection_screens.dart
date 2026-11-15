import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Ramadan collection. Everyone sees their own pledges; collectors see what they collected;
/// unit admins see their unit; finance and district admins see everything.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, this.title = 'Collection'});
  final String title;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String _filter = 'All';
  static const filters = ['All', 'Pledged', 'Part Paid', 'Paid', 'In-kind Received'];

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}collection') as Map),
        builder: (context, d) {
          final camp = d['campaign'] as Map?;
          if (camp == null) return [const EmptyNote('No collection campaign is open right now.')];
          final totals = d['totals'] as Map?;
          final mine = (d['my_pledges'] as List?) ?? [];
          final entries = ((d['entries'] as List?) ?? []).where((e) => _filter == 'All' || e['status'] == _filter).toList();
          final target = numOf(camp['target']);
          return [
            SioPanel(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Expanded(child: Text(camp['name'].toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink))),
                  if (target > 0) Text('Target ${inr(target)}', style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
                ]),
                if (camp['starts_on'] != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text('${fmtDate(camp['starts_on'], 'd MMM')} – ${fmtDate(camp['ends_on'], 'd MMM yyyy')}',
                        style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
                  ),
                if (totals != null) ...[
                  const SizedBox(height: 14),
                  Row(children: [
                    Stat(inr(totals['collected']), 'Collected'),
                    Stat(inr(totals['pledged']), 'Pledged', color: SioColors.ink),
                    Stat(inr(totals['balance']), 'To receive', color: SioColors.danger),
                  ]),
                  if (target > 0 && totals['scope'] == null) ...[
                    const SizedBox(height: 12),
                    ProgressBar(numOf(totals['collected']) / target),
                  ],
                  const SizedBox(height: 8),
                  Text(
                    totals['scope'] == 'collected_by_me'
                        ? 'What you collected · in-kind ${inr(totals['in_kind'])}'
                        : s.can('all_units')
                            ? 'All units · in-kind ${inr(totals['in_kind'])}'
                            : '${s.me['unit'] ?? 'Your unit'} · in-kind ${inr(totals['in_kind'])}',
                    style: const TextStyle(color: SioColors.textSecondary, fontSize: 13),
                  ),
                ] else if ((camp['description'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(camp['description'].toString()),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Row(children: [
              if (s.can('pledge'))
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => push(context, const NewEntryScreen(forSelf: true)),
                    icon: const Icon(Icons.favorite_outline),
                    label: const Text('My pledge'),
                  ),
                ),
              if (s.can('pledge') && s.can('collect')) const SizedBox(width: 12),
              if (s.can('collect'))
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () => push(context, const NewEntryScreen()),
                    icon: const Icon(Icons.add),
                    label: const Text('New entry'),
                  ),
                ),
            ]),
            if (mine.isNotEmpty) ...[
              const SectionTitle('My pledges'),
              PanelList(children: [for (final e in mine) _EntryRow(e: Map<String, dynamic>.from(e), canPay: false)]),
            ],
            if (d['entries'] != null) ...[
              SectionTitle(s.can('view_collection_totals') ? 'Entries' : 'Collected by me'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final f in filters)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(f == 'In-kind Received' ? 'In-kind' : f),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty) const EmptyNote('Nothing here yet.'),
              if (entries.isNotEmpty)
                PanelList(children: [for (final e in entries) _EntryRow(e: Map<String, dynamic>.from(e), canPay: s.can('collect'))]),
            ],
          ];
        },
      ),
    );
  }
}

class _EntryRow extends StatelessWidget {
  const _EntryRow({required this.e, required this.canPay});
  final Map<String, dynamic> e;
  final bool canPay;

  @override
  Widget build(BuildContext context) {
    final type = e['entry_type'];
    final status = e['status']?.toString() ?? '';
    final amount = type == 'In-kind'
        ? inr(e['in_kind_value'])
        : type == 'Payment'
            ? inr(e['paid_amount'])
            : '${inr(e['paid_amount'])} / ${inr(e['pledged_amount'])}';
    final sub = [e['contributor_type'], type == 'Payment' ? 'Direct payment' : type, if (type == 'In-kind') e['in_kind_details']]
        .where((x) => x != null && '$x'.isNotEmpty)
        .join(' · ');
    return ListTile(
      onTap: canPay && numOf(e['balance_amount']) > 0 ? () => _paymentSheet(context) : null,
      leading: Avatar(e['contributor_name'].toString()),
      title: Text(e['contributor_name'].toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        StatusChip(status == 'In-kind Received' ? 'In-kind' : status, tone: StatusChip.toneFor(status)),
      ]),
    );
  }

  Future<void> _paymentSheet(BuildContext context) async {
    final amount = TextEditingController(text: numOf(e['balance_amount']).toStringAsFixed(0));
    final ref = TextEditingController();
    var mode = 'Cash';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, MediaQuery.of(sheet).viewInsets.bottom + 20),
          child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text('Payment from ${e['contributor_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text('Balance ${inr(e['balance_amount'])}', style: const TextStyle(color: SioColors.textSecondary)),
            const SizedBox(height: 16),
            TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Amount received', prefixText: '₹ ')),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: mode,
              decoration: const InputDecoration(labelText: 'Mode'),
              items: [for (final m in const ['Cash', 'UPI', 'Bank Transfer', 'Cheque']) DropdownMenuItem(value: m, child: Text(m))],
              onChanged: (v) => setSheet(() => mode = v ?? mode),
            ),
            const SizedBox(height: 12),
            TextField(controller: ref, decoration: const InputDecoration(labelText: 'Reference (UPI ID, cheque no.)')),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () async {
                final ok = await run(
                  sheet,
                  () => Api.call('${Api.m}add_payment', {'entry': e['name'], 'amount': amount.text, 'mode': mode, 'reference_no': ref.text}),
                  done: 'Payment saved.',
                );
                if (ok && sheet.mounted) Navigator.pop(sheet);
              },
              child: const Text('Save payment'),
            ),
          ]),
        ),
      ),
    );
  }
}

/// New collection entry (by a collector), or a person's own pledge ([forSelf]).
class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key, this.forSelf = false});
  final bool forSelf;

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  String _kind = 'Pledge';
  String _ctype = 'Well-wisher';
  String _mode = 'Cash';
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _pledge = TextEditingController();
  final _paid = TextEditingController();
  final _value = TextEditingController();
  final _items = TextEditingController();
  final _ref = TextEditingController();
  bool _busy = false;

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}add_collection_entry', {
        'entry_type': widget.forSelf ? 'Pledge' : _kind,
        'for_self': widget.forSelf,
        'contributor_name': _name.text.trim(),
        'contributor_type': _ctype,
        'contributor_mobile': _mobile.text.trim(),
        'pledged_amount': _pledge.text,
        'paid_amount': _paid.text,
        'payment_mode': _mode,
        'reference_no': _ref.text.trim(),
        'in_kind_value': _value.text,
        'in_kind_details': _items.text.trim(),
      }),
      done: widget.forSelf ? 'Thank you! Your pledge is saved.' : 'Entry saved.',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = widget.forSelf;
    final kind = self ? 'Pledge' : _kind;
    return Scaffold(
      appBar: AppBar(title: Text(self ? 'My pledge' : 'New collection entry')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (self)
          SioBanner(text: 'Pledge an amount for the collection, ${AppState.i.firstName}. Pay it to your unit collector; they mark it as received.')
        else ...[
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Pledge', label: Text('Pledge')),
              ButtonSegment(value: 'Payment', label: Text('Payment')),
              ButtonSegment(value: 'In-kind', label: Text('In-kind')),
            ],
            selected: {_kind},
            onSelectionChanged: (v) => setState(() => _kind = v.first),
          ),
          const SizedBox(height: 16),
          TextField(controller: _name, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Contributor name')),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _ctype,
            decoration: const InputDecoration(labelText: 'Contributor type'),
            items: [
              for (final t in const ['Well-wisher', 'Member', 'Associate', 'Alumni', 'Business', 'Unit'])
                DropdownMenuItem(value: t, child: Text(t))
            ],
            onChanged: (v) => setState(() => _ctype = v ?? _ctype),
          ),
          const SizedBox(height: 14),
          TextField(controller: _mobile, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'Contributor mobile (for the receipt)')),
        ],
        const SizedBox(height: 14),
        if (kind == 'Pledge')
          TextField(controller: _pledge, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Pledged amount', prefixText: '₹ ')),
        if (kind == 'In-kind') ...[
          TextField(controller: _items, maxLines: 2, decoration: const InputDecoration(labelText: 'Items given (e.g. 40 food kits)')),
          const SizedBox(height: 14),
          TextField(controller: _value, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Estimated value', prefixText: '₹ ')),
        ],
        if (!self && kind != 'In-kind') ...[
          const SizedBox(height: 14),
          TextField(
            controller: _paid,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(labelText: kind == 'Payment' ? 'Amount received' : 'Amount received now (optional)', prefixText: '₹ '),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _mode,
            decoration: const InputDecoration(labelText: 'Payment mode'),
            items: [for (final m in const ['Cash', 'UPI', 'Bank Transfer', 'Cheque']) DropdownMenuItem(value: m, child: Text(m))],
            onChanged: (v) => setState(() => _mode = v ?? _mode),
          ),
          const SizedBox(height: 14),
          TextField(controller: _ref, decoration: const InputDecoration(labelText: 'Reference (UPI ID, cheque no.)')),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _save, child: Text(self ? 'Save my pledge' : 'Save entry')),
      ]),
    );
  }
}
