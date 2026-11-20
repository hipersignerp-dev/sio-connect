import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Accounts: money in (collections received), money out (expenses paid) and the balance,
/// for a period, a unit, a collection / fund or an event.
class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  State<AccountsScreen> createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  static const presets = ['This month', 'Last month', 'This year', 'All time', 'Custom'];
  String _preset = 'This month';
  DateTimeRange? _custom;
  String? _unit;
  String? _collection;
  String? _event;
  List<String> _units = [];
  List<String> _collections = [];
  List<(String, String)> _events = [];

  @override
  void initState() {
    super.initState();
    if (AppState.i.can('all_units')) {
      Api.myUnits()
          .then((v) {
            if (mounted) setState(() => _units = [for (final u in v) u['name'].toString()]);
          })
          .catchError((_) {});
    }
    Api.call('${Api.m}collection')
        .then((v) {
          final list = ((v as Map?)?['collections'] as List?) ?? [];
          if (mounted) setState(() => _collections = [for (final c in list) c['name'].toString()]);
        })
        .catchError((_) {});
    Api.call('${Api.m}events')
        .then((v) {
          final list = (v as List?) ?? [];
          if (mounted) setState(() => _events = [for (final e in list) (e['name'].toString(), e['title'].toString())]);
        })
        .catchError((_) {});
  }

  DateTimeRange get _range {
    final now = DateTime.now();
    return switch (_preset) {
      'Last month' => DateTimeRange(start: DateTime(now.year, now.month - 1, 1), end: DateTime(now.year, now.month, 0)),
      'This year' => DateTimeRange(start: DateTime(now.year, 1, 1), end: DateTime(now.year, 12, 31)),
      'All time' => DateTimeRange(start: DateTime(2000, 1, 1), end: DateTime(now.year + 1, 12, 31)),
      'Custom' => _custom ?? DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
      _ => DateTimeRange(start: DateTime(now.year, now.month, 1), end: DateTime(now.year, now.month + 1, 0)),
    };
  }

  Future<void> _pickPreset(String p) async {
    if (p == 'Custom') {
      final r = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2020),
        lastDate: DateTime.now().add(const Duration(days: 366)),
        initialDateRange: _range,
      );
      if (r == null) return;
      _custom = r;
    }
    setState(() => _preset = p);
  }

  Future<void> _pickFilter(String title, List<(String, String)> options, String? current, void Function(String?) set) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            ),
            ListTile(
              title: const Text('All'),
              trailing: current == null ? const Icon(Icons.check) : null,
              onTap: () => Navigator.pop(sheet, ''),
            ),
            for (final o in options)
              ListTile(
                title: Text(o.$2),
                trailing: current == o.$1 ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(sheet, o.$1),
              ),
          ],
        ),
      ),
    );
    if (v == null) return;
    setState(() => set(v.isEmpty ? null : v));
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final r = _range;
    final key = [r.start, r.end, _unit, _collection, _event].join('|');
    return Scaffold(
      appBar: AppBar(title: const Text('Accounts')),
      body: Loader<Map<String, dynamic>>(
        key: ValueKey(key),
        load: () async => Map<String, dynamic>.from(
          await Api.call('${Api.m}accounts', {
            'from_date': apiDate(r.start),
            'to_date': apiDate(r.end),
            'unit': _unit,
            'collection': _collection,
            'event': _event,
          }) as Map,
        ),
        builder: (context, a) {
          final rows = ((a['rows'] as List?) ?? []).reversed.toList();
          final ins = (a['in_by_collection'] as List?) ?? [];
          final outCat = (a['out_by_category'] as List?) ?? [];
          final outEv = (a['out_by_event'] as List?) ?? [];
          return [
            SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final p in presets)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(label: Text(p), selected: _preset == p, onSelected: (_) => _pickPreset(p)),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                if (s.can('all_units'))
                  _FilterChip(
                    label: _unit ?? 'All units',
                    on: _unit != null,
                    onTap: () => _pickFilter('Unit', [for (final u in _units) (u, u)], _unit, (v) => _unit = v),
                  ),
                _FilterChip(
                  label: _collection ?? 'All funds',
                  on: _collection != null,
                  onTap: () => _pickFilter('Collection / fund', [for (final c in _collections) (c, c)], _collection, (v) {
                    _collection = v;
                    if (v != null) _event = null;
                  }),
                ),
                _FilterChip(
                  label: _event == null
                      ? 'All events'
                      : _events.firstWhere((e) => e.$1 == _event, orElse: () => (_event!, _event!)).$2,
                  on: _event != null,
                  onTap: () => _pickFilter('Event', _events, _event, (v) {
                    _event = v;
                    if (v != null) _collection = null;
                  }),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SioPanel(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    [
                      _preset == 'All time'
                          ? 'All time'
                          : '${fmtDate(apiDate(r.start), 'd MMM')} – ${fmtDate(apiDate(r.end), 'd MMM yyyy')}',
                      a['unit'] ?? 'All units',
                    ].join(' · '),
                    style: TextStyle(color: SioColors.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Stat(inr(a['in']), 'Money in', color: SioColors.green),
                      Stat(inr(a['out']), 'Money out', color: SioColors.danger),
                      Stat(inr(a['closing']), 'Balance'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(),
                  const SizedBox(height: 6),
                  _Line('Opening balance', inr(a['opening'])),
                  _Line('+ Money in', inr(a['in'])),
                  _Line('− Money out', inr(a['out'])),
                  _Line('Closing balance', inr(a['closing']), bold: true),
                  if (numOf(a['to_pay']) > 0) ...[
                    const SizedBox(height: 8),
                    SioBanner(text: '${inr(a['to_pay'])} of approved expenses still to pay.'),
                  ],
                ],
              ),
            ),
            if (ins.isNotEmpty) ...[
              const SectionTitle('Money in, by collection'),
              PanelList(children: [for (final x in ins) _Sum(x['name'], x['amount'], SioColors.green)]),
            ],
            if (outCat.isNotEmpty) ...[
              const SectionTitle('Money out, by category'),
              PanelList(children: [for (final x in outCat) _Sum(x['name'], x['amount'], SioColors.danger)]),
            ],
            if (outEv.isNotEmpty && _event == null) ...[
              const SectionTitle('Money out, by event'),
              PanelList(children: [for (final x in outEv) _Sum(x['name'], x['amount'], SioColors.danger)]),
            ],
            const SectionTitle('Transactions'),
            if (rows.isEmpty) const EmptyNote('Nothing in this period.'),
            if (rows.isNotEmpty) PanelList(children: [for (final t in rows) _TxRow(t: Map<String, dynamic>.from(t))]),
          ];
        },
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({required this.label, required this.on, required this.onTap});
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => FilterChip(
    label: Text(label, overflow: TextOverflow.ellipsis),
    selected: on,
    showCheckmark: false,
    avatar: const Icon(Icons.filter_list, size: 18),
    onSelected: (_) => onTap(),
  );
}

class _Line extends StatelessWidget {
  const _Line(this.label, this.value, {this.bold = false});
  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w500, color: SioColors.ink);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _Sum extends StatelessWidget {
  const _Sum(this.name, this.amount, this.color);
  final dynamic name;
  final dynamic amount;
  final Color color;

  @override
  Widget build(BuildContext context) => ListTile(
    dense: true,
    title: Text('${name ?? 'Other'}', overflow: TextOverflow.ellipsis),
    trailing: Text(
      inr(amount),
      style: TextStyle(fontWeight: FontWeight.w700, color: color),
    ),
  );
}

class _TxRow extends StatelessWidget {
  const _TxRow({required this.t});
  final Map<String, dynamic> t;

  @override
  Widget build(BuildContext context) {
    final isIn = t['type'] == 'In';
    final sub = [
      fmtDate(t['date'], 'd MMM'),
      t['party'],
      t['unit'],
      if (!isIn) t['category'],
      t['collection'],
      t['mode'],
    ].where((x) => x != null && '$x'.isNotEmpty).join(' · ');
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: isIn ? SioColors.greenBg : SioColors.dangerBg,
        foregroundColor: isIn ? SioColors.green : SioColors.danger,
        child: Icon(isIn ? Icons.south_west : Icons.north_east, size: 20),
      ),
      title: Text(
        '${t['title'] ?? ''}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(
            '${isIn ? '+' : '−'}${inr(t['amount'])}',
            style: TextStyle(fontWeight: FontWeight.w700, color: isIn ? SioColors.green : SioColors.danger),
          ),
          const SizedBox(height: 2),
          Text('bal ${inr(t['balance'])}', style: TextStyle(color: SioColors.textSecondary, fontSize: 11.5)),
        ],
      ),
    );
  }
}
