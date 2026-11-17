import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'donors_screen.dart';
import 'manage_screens.dart';

IconData collectionIcon(String? type) => switch (type) {
  'Ramadan Collection' => Icons.nightlight_round,
  'Baithul Mal' => Icons.account_balance_outlined,
  'Zakat' => Icons.volunteer_activism_outlined,
  'Relief Fund' => Icons.health_and_safety_outlined,
  _ => Icons.savings_outlined,
};

/// Collections (Ramadan Collection, Baithul Mal, ...). Everyone sees the open collections and their own
/// offers; collectors see what they collected; unit admins their unit; finance and admins everything.
class CollectionScreen extends StatefulWidget {
  const CollectionScreen({super.key, this.title = 'Collection'});
  final String title;

  @override
  State<CollectionScreen> createState() => _CollectionScreenState();
}

class _CollectionScreenState extends State<CollectionScreen> {
  String? _selected;
  String _filter = 'All';
  static const filters = ['All', 'Offered', 'Part Paid', 'Paid', 'Items Received'];

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (s.can('manage_collections')) ...[
            IconButton(
              tooltip: 'All collections',
              icon: const Icon(Icons.list_alt),
              onPressed: () => push(context, const ManageCollectionsScreen()),
            ),
          ],
        ],
      ),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(_selected),
        load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}collection', {'collection': _selected}) as Map),
        builder: (context, d) {
          final collections = (d['collections'] as List?) ?? [];
          final sel = d['collection'] as Map?;
          if (sel == null) {
            return [
              const EmptyNote('No collection is open right now.'),
              if (s.can('manage_collections')) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => push(context, const CollectionFormScreen()),
                  icon: const Icon(Icons.add),
                  label: const Text('New collection'),
                ),
              ],
            ];
          }
          final totals = d['totals'] as Map?;
          final mine = (d['my_offers'] as List?) ?? [];
          final entries = ((d['entries'] as List?) ?? []).where((e) => _filter == 'All' || e['status'] == _filter).toList();
          final target = numOf(sel['target']);
          final units = ((d['units'] as List?) ?? []).where((u) => numOf(u['target']) > 0 || numOf(u['collected']) > 0).toList();
          return [
            if (collections.length > 1) ...[
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final c in collections)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          avatar: Icon(collectionIcon(c['collection_type']?.toString()), size: 18),
                          label: Text(
                            c['phase'] == 'Ended'
                                ? '${c['name']} · ended'
                                : c['phase'] == 'Upcoming'
                                ? '${c['name']} · from ${fmtDate(c['starts_on'], 'd MMM')}'
                                : c['name'].toString(),
                          ),
                          selected: c['name'] == sel['name'],
                          onSelected: (_) => setState(() {
                            _selected = c['name'].toString();
                            _filter = 'All';
                          }),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],
            SioPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(collectionIcon(sel['collection_type']?.toString()), color: SioColors.blue),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          sel['name'].toString(),
                          style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink),
                        ),
                      ),
                      if (target > 0)
                        Text('Target ${inr(target)}', style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
                    ],
                  ),
                  if (sel['starts_on'] != null || sel['unit'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        [
                          if (sel['starts_on'] != null)
                            '${fmtDate(sel['starts_on'], 'd MMM')} – ${fmtDate(sel['ends_on'], 'd MMM yyyy')}',
                          if (sel['unit'] != null) '${sel['unit']} unit',
                        ].join(' · '),
                        style: const TextStyle(color: SioColors.textSecondary, fontSize: 13),
                      ),
                    ),
                  if (s.can('manage_collections'))
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: () => push(context, CollectionFormScreen(name: sel['name'].toString())),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit, set unit targets'),
                      ),
                    ),
                  if ((sel['description'] ?? '').toString().isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text(sel['description'].toString()),
                  ],
                  if (totals != null) ...[
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Stat(inr(totals['collected']), 'Received'),
                        Stat(inr(totals['offered']), 'Offered', color: SioColors.ink),
                        Stat(inr(totals['balance']), 'To receive', color: SioColors.danger),
                      ],
                    ),
                    if (target > 0 && totals['scope'] == null) ...[
                      const SizedBox(height: 12),
                      ProgressBar(numOf(totals['collected']) / target),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      [
                        totals['scope'] == 'collected_by_me'
                            ? 'What you collected'
                            : s.can('all_units')
                            ? 'All units'
                            : '${s.me['unit'] ?? 'Your unit'}',
                        if (numOf(totals['items']) > 0) 'items worth ${inr(totals['items'])}',
                      ].join(' · '),
                      style: const TextStyle(color: SioColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ],
              ),
            ),
            if (sel['my_pledge'] != null) ...[
              const SizedBox(height: 12),
              _PledgeCard(
                p: Map<String, dynamic>.from(sel['my_pledge'] as Map),
                change: () =>
                    push(context, NewEntryScreen(forSelf: true, collection: sel['name'].toString(), collections: collections)),
              ),
            ],
            if (sel['phase'] != null && sel['phase'] != 'Running') ...[
              const SizedBox(height: 12),
              SioBanner(
                text: sel['phase'] == 'Upcoming'
                    ? 'This collection starts on ${fmtDate(sel['starts_on'], 'd MMM yyyy')}. Offers open then.'
                    : 'This collection ended on ${fmtDate(sel['ends_on'], 'd MMM yyyy')}. No new offers; '
                          'payments of earlier offers can still be recorded.',
              ),
            ],
            const SizedBox(height: 12),
            if (sel['phase'] == null || sel['phase'] == 'Running')
              Row(
                children: [
                  if (s.can('offer') && sel['my_pledge'] == null)
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => push(
                          context,
                          NewEntryScreen(forSelf: true, collection: sel['name'].toString(), collections: collections),
                        ),
                        icon: const Icon(Icons.favorite_outline),
                        label: Text(sel['collection_type'] == 'Baithul Mal' ? 'Set my Baithul Mal' : 'Give an offer'),
                      ),
                    ),
                  if (s.can('offer') && sel['my_pledge'] == null && s.can('collect')) const SizedBox(width: 12),
                  if (s.can('collect'))
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: () =>
                            push(context, NewEntryScreen(collection: sel['name'].toString(), collections: collections)),
                        icon: const Icon(Icons.add),
                        label: const Text('New entry'),
                      ),
                    ),
                ],
              ),
            if (s.can('view_donors')) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () => push(context, DonorsScreen(collection: sel['name'].toString())),
                icon: const Icon(Icons.contacts_outlined),
                label: const Text('Donor list: ask again'),
              ),
            ],
            if (units.isNotEmpty) ...[
              SectionTitle(units.length > 1 ? 'Units' : 'My unit\'s target'),
              PanelList(children: [for (final u in units) UnitProgressRow(u: Map<String, dynamic>.from(u))]),
            ],
            if (mine.isNotEmpty) ...[
              const SectionTitle('My offers'),
              PanelList(children: [for (final e in mine) _EntryRow(e: Map<String, dynamic>.from(e), canPay: false)]),
            ],
            if (d['entries'] != null) ...[
              SectionTitle(s.can('view_collection_totals') ? 'Entries' : 'Collected by me'),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final f in filters)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(f == 'Items Received' ? 'Items' : f),
                          selected: _filter == f,
                          onSelected: (_) => setState(() => _filter = f),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (entries.isEmpty) const EmptyNote('Nothing here yet.'),
              if (entries.isNotEmpty)
                PanelList(
                  children: [for (final e in entries) _EntryRow(e: Map<String, dynamic>.from(e), canPay: s.can('collect'))],
                ),
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
    final amount = type == 'Items'
        ? (numOf(e['items_value']) > 0 ? inr(e['items_value']) : 'Items')
        : type == 'Payment'
        ? inr(e['paid_amount'])
        : numOf(e['paid_amount']) > 0
        ? '${inr(e['paid_amount'])} of ${inr(e['offered_amount'])}'
        : inr(e['offered_amount']);
    final sub = [
      if (AppState.i.can('all_units')) e['unit'],
      if ((e['payment_ref'] ?? '').toString().isNotEmpty && e['status'] == 'Offered')
        'UPI ref ${e['payment_ref']}: check & confirm',
      e['contributor_place'] ?? e['contributor_type'],
      if (type == 'Items') e['items_given'] else if (type == 'Payment') 'Paid now' else 'Offer',
    ].where((x) => x != null && '$x'.isNotEmpty).join(' · ');
    return ListTile(
      onTap: canPay && numOf(e['balance_amount']) > 0 ? () => _paymentSheet(context) : null,
      leading: Avatar(e['contributor_name'].toString()),
      title: Text(
        e['contributor_name'].toString(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(amount, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          StatusChip(status == 'Items Received' ? 'Items' : status, tone: StatusChip.toneFor(status)),
        ],
      ),
    );
  }

  /// Collector marks money received against an offer.
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Received from ${e['contributor_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(
                'Still to receive ${inr(e['balance_amount'])} of ${inr(e['offered_amount'])} offered',
                style: const TextStyle(color: SioColors.textSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Amount received', prefixText: '₹ '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: mode,
                decoration: const InputDecoration(labelText: 'Paid by'),
                items: [
                  for (final m in const ['Cash', 'UPI', 'Bank Transfer', 'Cheque']) DropdownMenuItem(value: m, child: Text(m)),
                ],
                onChanged: (v) => setSheet(() => mode = v ?? mode),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ref,
                decoration: const InputDecoration(labelText: 'Reference (UPI ID, cheque no.)'),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  final ok = await run(
                    sheet,
                    () => Api.call('${Api.m}add_payment', {
                      'entry': e['name'],
                      'amount': amount.text,
                      'mode': mode,
                      'reference_no': ref.text,
                    }),
                    done: 'Saved.',
                  );
                  if (ok && sheet.mounted) Navigator.pop(sheet);
                },
                child: const Text('Save'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// New entry in a collection (by a collector), or the signed-in person's own offer ([forSelf]).
class NewEntryScreen extends StatefulWidget {
  const NewEntryScreen({super.key, this.forSelf = false, this.collection, this.collections, this.contributor});
  final bool forSelf;
  final Map<String, dynamic>? contributor;
  final String? collection;
  final List<dynamic>? collections;

  @override
  State<NewEntryScreen> createState() => _NewEntryScreenState();
}

class _NewEntryScreenState extends State<NewEntryScreen> {
  String _kind = 'Offer';
  String _ctype = 'Well-wisher';
  String _mode = 'Cash';
  String? _collection;
  List<dynamic> _collections = [];
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _place = TextEditingController();
  String? _unit;
  List<String> _units = [];
  List<Map<String, dynamic>> _donors = [];
  bool _hooked = false;
  // Baithul Mal monthly pledge
  String _basis = 'Pocket money (10%)';
  final _base = TextEditingController();
  final _fixed = TextEditingController();

  Map<String, dynamic>? get _sel {
    for (final c in _collections) {
      if (c['name'] == _collection) return Map<String, dynamic>.from(c as Map);
    }
    return null;
  }

  bool get _pledge => widget.forSelf && _sel?['collection_type'] == 'Baithul Mal';

  num get _monthly {
    final base = num.tryParse(_base.text.trim()) ?? 0;
    return switch (_basis) {
      'Pocket money (10%)' => (base * 0.10).round(),
      'Salary (1%)' => (base * 0.01).round(),
      _ => (num.tryParse(_fixed.text.trim()) ?? 0).round(),
    };
  }

  final _offered = TextEditingController();
  final _paid = TextEditingController();
  final _value = TextEditingController();
  final _items = TextEditingController();
  final _ref = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    // new offers and entries only go into collections running now
    _collections = [
      for (final c in widget.collections ?? [])
        if (c['phase'] == null || c['phase'] == 'Running') c,
    ];
    final c = widget.contributor;
    if (c != null) {
      _name.text = '${c['name'] ?? ''}';
      _mobile.text = '${c['mobile'] ?? ''}';
      _place.text = '${c['place'] ?? ''}';
      const types = ['Well-wisher', 'Member', 'Associate', 'Alumni', 'Business', 'Unit'];
      if (types.contains(c['type'])) _ctype = c['type'].toString();
    }
    final s = AppState.i;
    if (s.can('all_units') && !widget.forSelf) {
      _unit = (c?['unit'] ?? s.me['unit'])?.toString();
      Api.myUnits()
          .then((v) {
            if (mounted) setState(() => _units = [for (final u in v) u['name'].toString()]);
          })
          .catchError((_) {});
    }
    if (!widget.forSelf && s.can('view_donors')) {
      Api.call('${Api.m}donors')
          .then((v) {
            final list = ((v as Map?)?['donors'] as List?) ?? [];
            if (mounted) setState(() => _donors = [for (final d in list) Map<String, dynamic>.from(d)]);
          })
          .catchError((_) {});
    }
    if (_collections.isEmpty) {
      Api.call('${Api.m}collection')
          .then((v) {
            final list = ((v as Map)['collections'] as List?) ?? [];
            if (mounted) {
              setState(() {
                _collections = [
                  for (final c in list)
                    if (c['phase'] == null || c['phase'] == 'Running') c,
                ];
                _collection ??= _collections.isNotEmpty ? _collections.first['name'].toString() : null;
              });
            }
          })
          .catchError((_) {});
    }
  }

  Future<void> _save() async {
    if (_collection == null) {
      toast(context, 'No collection is open right now.');
      return;
    }
    if (_pledge && _monthly <= 0) {
      toast(
        context,
        _basis == 'Fixed amount'
            ? 'Enter the monthly amount.'
            : 'Enter your monthly ${_basis.startsWith('Salary') ? 'salary' : 'pocket money'}.',
      );
      return;
    }
    if (!widget.forSelf && AppState.i.can('all_units') && _unit == null) {
      toast(context, 'Pick the unit this collection is for.');
      return;
    }
    setState(() => _busy = true);
    final self = widget.forSelf;
    final ok = await run(
      context,
      () => Api.call('${Api.m}add_collection_entry', {
        'collection': _collection,
        'entry_type': self ? 'Offer' : _kind,
        'for_self': self,
        'contributor_name': _name.text.trim(),
        'contributor_type': _ctype,
        'contributor_mobile': _mobile.text.trim(),
        'contributor_place': _place.text.trim(),
        'unit': _unit,
        'offered_amount': _offered.text,
        'paid_amount': _paid.text,
        'payment_mode': _mode,
        'reference_no': _ref.text.trim(),
        'items_given': _items.text.trim(),
        'items_value': _value.text,
        if (_pledge) ...{'pledge_basis': _basis, 'pledge_base': _base.text.trim(), 'monthly_amount': _fixed.text.trim()},
      }),
      done: _pledge
          ? 'Jazakallah khair! Your Baithul Mal is ${inr(_monthly)} a month.'
          : self
          ? 'Jazakallah khair! Your offer is saved.'
          : 'Saved.',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final self = widget.forSelf;
    final kind = self ? 'Offer' : _kind;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _pledge
              ? 'Baithul Mal'
              : self
              ? 'Give an offer'
              : 'New collection entry',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_collections.length > 1 || _collection == null) ...[
            DropdownButtonFormField<String>(
              initialValue: _collections.any((c) => c['name'] == _collection) ? _collection : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Collection'),
              items: [
                for (final c in _collections)
                  DropdownMenuItem(
                    value: c['name'].toString(),
                    child: Row(
                      children: [
                        Icon(collectionIcon(c['collection_type']?.toString()), size: 18, color: SioColors.blue),
                        const SizedBox(width: 8),
                        Expanded(child: Text(c['name'].toString(), overflow: TextOverflow.ellipsis)),
                      ],
                    ),
                  ),
              ],
              onChanged: (v) => setState(() => _collection = v),
            ),
            const SizedBox(height: 14),
          ] else if (AppState.i.role != 'Associate')
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                _collection!,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: SioColors.ink),
              ),
            ),
          if (_pledge) ...[
            const SioBanner(
              text: 'Baithul Mal is given every month: 10% of your pocket money, 1% of your salary, or a fixed amount.',
            ),
            const SizedBox(height: 14),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Pocket money (10%)', label: Text('Pocket money')),
                ButtonSegment(value: 'Salary (1%)', label: Text('Salary')),
                ButtonSegment(value: 'Fixed amount', label: Text('Fixed')),
              ],
              selected: {_basis},
              onSelectionChanged: (v) => setState(() => _basis = v.first),
            ),
            const SizedBox(height: 14),
            if (_basis == 'Fixed amount')
              TextField(
                controller: _fixed,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(labelText: 'Amount every month', prefixText: '₹ '),
              )
            else
              TextField(
                controller: _base,
                keyboardType: TextInputType.number,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: _basis.startsWith('Salary') ? 'Your monthly salary' : 'Your monthly pocket money',
                  prefixText: '₹ ',
                ),
              ),
            const SizedBox(height: 16),
            SioPanel(
              child: Row(
                children: [
                  const Expanded(
                    child: Text('You give every month', style: TextStyle(fontWeight: FontWeight.w600)),
                  ),
                  Text(
                    inr(_monthly),
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SioColors.green),
                  ),
                ],
              ),
            ),
          ] else if (self)
            SioBanner(
              text:
                  'How much would you like to give, ${AppState.i.firstName}? Pay it to your unit collector any time; they mark it as received.',
            )
          else ...[
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'Offer', label: Text('Offered')),
                ButtonSegment(value: 'Payment', label: Text('Paid now')),
                ButtonSegment(value: 'Items', label: Text('Items')),
              ],
              selected: {_kind},
              onSelectionChanged: (v) => setState(() => _kind = v.first),
            ),
            const SizedBox(height: 16),
            if (AppState.i.can('all_units'))
              DropdownButtonFormField<String?>(
                initialValue: _units.contains(_unit) ? _unit : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'For which unit'),
                items: [for (final u in _units) DropdownMenuItem<String?>(value: u, child: Text(u))],
                onChanged: (v) => setState(() => _unit = v),
              )
            else
              SioBanner(text: 'This counts for ${AppState.i.me['unit'] ?? 'your'} unit.'),
            const SizedBox(height: 14),
            Autocomplete<Map<String, dynamic>>(
              initialValue: TextEditingValue(text: _name.text),
              displayStringForOption: (d) => '${d['name']}',
              optionsBuilder: (v) {
                final q = v.text.trim().toLowerCase();
                if (q.length < 2) return const Iterable.empty();
                return _donors
                    .where((d) => '${d['name']}'.toLowerCase().contains(q) || '${d['mobile'] ?? ''}'.contains(q))
                    .take(6);
              },
              onSelected: (d) => setState(() {
                _name.text = '${d['name']}';
                _mobile.text = '${d['mobile'] ?? ''}';
                _place.text = '${d['place'] ?? ''}';
                const types = ['Well-wisher', 'Member', 'Associate', 'Alumni', 'Business', 'Unit'];
                if (types.contains(d['type'])) _ctype = d['type'].toString();
              }),
              optionsViewBuilder: (context, onSelected, options) => Align(
                alignment: Alignment.topLeft,
                child: Material(
                  elevation: 4,
                  borderRadius: BorderRadius.circular(12),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280, maxWidth: 360),
                    child: ListView(
                      padding: EdgeInsets.zero,
                      shrinkWrap: true,
                      children: [
                        for (final d in options)
                          ListTile(
                            dense: true,
                            title: Text('${d['name']}'),
                            subtitle: Text(
                              [
                                d['mobile'],
                                d['place'],
                                'gave ${inr(d['given'])}',
                              ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                            ),
                            onTap: () => onSelected(d),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              fieldViewBuilder: (context, ctrl, focus, onSubmit) {
                if (!_hooked) {
                  _hooked = true;
                  ctrl.addListener(() => _name.text = ctrl.text);
                }
                return TextField(
                  controller: ctrl,
                  focusNode: focus,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Given by',
                    helperText: 'Type a name or mobile to pick someone who gave before',
                  ),
                );
              },
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _ctype,
              decoration: const InputDecoration(labelText: 'Who is giving'),
              items: [
                for (final t in const ['Well-wisher', 'Member', 'Associate', 'Alumni', 'Business', 'Unit'])
                  DropdownMenuItem(value: t, child: Text(t)),
              ],
              onChanged: (v) => setState(() => _ctype = v ?? _ctype),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _mobile,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Mobile (to ask again next time)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _place,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Place / address'),
            ),
          ],
          const SizedBox(height: 14),
          if (kind == 'Offer' && !_pledge)
            TextField(
              controller: _offered,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Amount offered', prefixText: '₹ '),
            ),
          if (kind == 'Items') ...[
            TextField(
              controller: _items,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Items given (e.g. 40 food kits)'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _value,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Value of items (approx.)', prefixText: '₹ '),
            ),
          ],
          if (!self && kind != 'Items') ...[
            const SizedBox(height: 14),
            TextField(
              controller: _paid,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: kind == 'Payment' ? 'Amount received' : 'Received now (if any)',
                prefixText: '₹ ',
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              initialValue: _mode,
              decoration: const InputDecoration(labelText: 'Paid by'),
              items: [
                for (final m in const ['Cash', 'UPI', 'Bank Transfer', 'Cheque']) DropdownMenuItem(value: m, child: Text(m)),
              ],
              onChanged: (v) => setState(() => _mode = v ?? _mode),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _ref,
              decoration: const InputDecoration(labelText: 'Reference (UPI ID, cheque no.)'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(
              _pledge
                  ? 'Save my Baithul Mal'
                  : self
                  ? 'Save my offer'
                  : 'Save',
            ),
          ),
        ],
      ),
    );
  }
}

/// One unit's collection against its target.
class UnitProgressRow extends StatelessWidget {
  const UnitProgressRow({super.key, required this.u});
  final Map<String, dynamic> u;

  @override
  Widget build(BuildContext context) {
    final target = numOf(u['target']);
    final got = numOf(u['collected']);
    final left = numOf(u['to_target']);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(u['unit'].toString(), style: const TextStyle(fontWeight: FontWeight.w700)),
              ),
              Text(
                target > 0 ? '${inr(got)} of ${inr(target)}' : inr(got),
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
          if (target > 0) ...[const SizedBox(height: 8), ProgressBar(got / target)],
          const SizedBox(height: 6),
          Text(
            [
              if (target > 0) '${numOf(u['pct']).toInt()}%',
              if (target > 0) left > 0 ? '${inr(left)} still to target' : 'Target reached',
              if (numOf(u['balance']) > 0) '${inr(u['balance'])} offered, not yet paid',
            ].join(' · '),
            style: const TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}

/// The signed-in person's monthly Baithul Mal: amount, paid so far and what is due now.
class _PledgeCard extends StatelessWidget {
  const _PledgeCard({required this.p, required this.change});
  final Map<String, dynamic> p;
  final VoidCallback change;

  @override
  Widget build(BuildContext context) {
    final due = numOf(p['due_now']);
    return SioPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'My Baithul Mal',
                  style: TextStyle(fontWeight: FontWeight.w700, color: SioColors.ink),
                ),
              ),
              TextButton(onPressed: change, child: const Text('Change')),
            ],
          ),
          Row(
            children: [
              Stat(inr(p['monthly']), 'Every month', color: SioColors.ink),
              Stat(inr(p['paid']), 'Paid', color: SioColors.green),
              Stat(inr(due), 'Due now', color: due > 0 ? SioColors.danger : SioColors.green),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            [
              '${p['basis']}${numOf(p['base']) > 0 ? ' of ${inr(p['base'])}' : ''}',
              'month ${p['months_so_far']} of ${p['months']}',
              if (due > 0) 'pay your unit collector' else 'all paid up, Jazakallah khair',
            ].join(' · '),
            style: const TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
          ),
        ],
      ),
    );
  }
}
