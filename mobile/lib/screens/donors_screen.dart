import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import '../location.dart';
import 'collection_screens.dart';

Future<void> callNumber(BuildContext context, String? mobile) async {
  final m = (mobile ?? '').replaceAll(RegExp(r'[^0-9+]'), '');
  if (m.isEmpty) return;
  if (!await launchUrl(Uri(scheme: 'tel', path: m)) && context.mounted) toast(context, 'Could not open the dialler.');
}

Future<void> whatsApp(BuildContext context, String? mobile, String text) async {
  var m = (mobile ?? '').replaceAll(RegExp(r'[^0-9]'), '');
  if (m.length == 10) m = '91$m';
  if (m.isEmpty) return;
  final uri = Uri.parse('https://wa.me/$m?text=${Uri.encodeComponent(text)}');
  if (!await launchUrl(uri, mode: LaunchMode.externalApplication) && context.mounted) toast(context, 'Could not open WhatsApp.');
}

/// Everyone who has given, with phone and place, so the unit can ask them again next time.
class DonorsScreen extends StatefulWidget {
  const DonorsScreen({super.key, this.collection});
  final String? collection;

  @override
  State<DonorsScreen> createState() => _DonorsScreenState();
}

class _DonorsScreenState extends State<DonorsScreen> {
  final _q = TextEditingController();
  String _show = 'all';
  String? _collection;
  String? _unit;
  List<String> _collections = [];
  List<String> _units = [];
  int _version = 0;

  @override
  void initState() {
    super.initState();
    _collection = widget.collection;
    Api.call('${Api.m}collection')
        .then((v) {
          final list = ((v as Map?)?['collections'] as List?) ?? [];
          if (mounted) {
            setState(() {
              _collections = [for (final c in list) c['name'].toString()];
              _collection ??= _collections.isNotEmpty ? _collections.first : null;
            });
          }
        })
        .catchError((_) {});
    if (AppState.i.can('all_units')) {
      Api.myUnits()
          .then((v) {
            if (mounted) setState(() => _units = [for (final u in v) u['name'].toString()]);
          })
          .catchError((_) {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    return Scaffold(
      appBar: AppBar(title: const Text('Donors')),
      floatingActionButton: AddFab(
        tooltip: 'Add donor',
        onPressed: () async {
          final ok = await push(context, const DonorFormScreen());
          if (ok == true) setState(() => _version++);
        },
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() => _version++),
              decoration: InputDecoration(
                hintText: 'Search name, mobile or place',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  tooltip: 'Search',
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => setState(() => _version++),
                ),
              ),
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                for (final f in const [('all', 'Everyone'), ('not_yet', 'Not given yet'), ('to_pay', 'Still to pay')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(f.$2),
                      selected: _show == f.$1,
                      onSelected: (_) => setState(() {
                        _show = f.$1;
                        _version++;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          if (_show == 'not_yet' || _units.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: Row(
                children: [
                  if (_show == 'not_yet')
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: _collections.contains(_collection) ? _collection : null,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Not given in', isDense: true),
                        items: [
                          for (final c in _collections)
                            DropdownMenuItem(
                              value: c,
                              child: Text(c, overflow: TextOverflow.ellipsis),
                            ),
                        ],
                        onChanged: (v) => setState(() {
                          _collection = v;
                          _version++;
                        }),
                      ),
                    ),
                  if (_show == 'not_yet' && _units.isNotEmpty) const SizedBox(width: 10),
                  if (_units.isNotEmpty)
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: const InputDecoration(labelText: 'Unit', isDense: true),
                        items: [
                          const DropdownMenuItem<String?>(value: null, child: Text('All units')),
                          for (final u in _units) DropdownMenuItem<String?>(value: u, child: Text(u)),
                        ],
                        onChanged: (v) => setState(() {
                          _unit = v;
                          _version++;
                        }),
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: Loader<Map<String, dynamic>>(
              key: ValueKey('$_version|$_collection'),
              load: () async => Map<String, dynamic>.from(
                await Api.call('${Api.m}donors', {'q': _q.text.trim(), 'show': _show, 'collection': _collection, 'unit': _unit})
                    as Map,
              ),
              builder: (context, d) {
                final list = (d['donors'] as List?) ?? [];
                return [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                    child: Text(
                      '${d['count']} people · ${d['with_mobile']} with mobile'
                      '${s.can('view_collection_totals') ? '' : ' · people you collected from'}',
                      style: TextStyle(color: SioColors.textSecondary, fontSize: 13),
                    ),
                  ),
                  if (list.isEmpty)
                    EmptyNote(_show == 'not_yet' ? 'Everyone has given this time. Alhamdulillah!' : 'No one yet.'),
                  if (list.isNotEmpty)
                    PanelList(
                      children: [
                        for (final x in list)
                          _DonorRow(
                            d: Map<String, dynamic>.from(x),
                            collection: _collection,
                            changed: () => setState(() => _version++),
                          ),
                      ],
                    ),
                ];
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DonorRow extends StatelessWidget {
  const _DonorRow({required this.d, required this.collection, required this.changed});
  final Map<String, dynamic> d;
  final String? collection;
  final VoidCallback changed;

  @override
  Widget build(BuildContext context) {
    final sub = [d['mobile'], d['place'], d['unit']].where((x) => x != null && '$x'.isNotEmpty).join(' · ');
    return ListTile(
      onTap: () => _sheet(context),
      leading: Avatar('${d['name']}'),
      title: Text(
        '${d['name']}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(sub.isEmpty ? 'No mobile saved' : sub, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Text(inr(d['given']), style: const TextStyle(fontWeight: FontWeight.w700)),
          if (numOf(d['balance']) > 0)
            Text('${inr(d['balance'])} to pay', style: TextStyle(color: SioColors.danger, fontSize: 11.5))
          else
            Text(
              numOf(d['times']) > 0 ? '${d['times']}× given' : 'Not given yet',
              style: TextStyle(color: SioColors.textSecondary, fontSize: 11.5),
            ),
        ],
      ),
    );
  }

  Future<void> _sheet(BuildContext context) async {
    final hasMobile = (d['mobile'] ?? '').toString().isNotEmpty;
    final first = '${d['name']}'.split(' ').first;
    final ask = collection == null
        ? 'Assalamu alaikum $first, '
        : 'Assalamu alaikum $first, SIO ${AppState.i.me['unit'] ?? ''} unit is collecting for $collection. Jazakallah khair for your support last time. ';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('${d['name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
              Text(
                [d['type'], d['mobile'], d['place'], d['unit']].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                style: TextStyle(color: SioColors.textSecondary),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Stat(inr(d['given']), 'Given in all'),
                  Stat(inr(d['balance']), 'Still to pay', color: SioColors.danger),
                  Stat('${d['times']}', 'Times', color: SioColors.ink),
                ],
              ),
              const SizedBox(height: 12),
              for (final c in (d['collections'] as List? ?? []))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(child: Text('${c['collection']}')),
                      Text(inr(c['amount']), style: const TextStyle(fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
              if (d['last_date'] != null)
                Text('Last: ${fmtDate(d['last_date'])}', style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5)),
              if ((d['notes'] ?? '').toString().isNotEmpty) ...[const SizedBox(height: 8), SioBanner(text: '${d['notes']}')],
              const SizedBox(height: 16),
              if (hasMobile)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => callNumber(context, '${d['mobile']}'),
                        icon: const Icon(Icons.call),
                        label: const Text('Call'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => whatsApp(context, '${d['mobile']}', ask),
                        icon: const Icon(Icons.chat_outlined),
                        label: const Text('WhatsApp'),
                      ),
                    ),
                  ],
                ),
              if (GeoPoint.from(d['latitude'], d['longitude']) != null) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () => openInMaps(context, GeoPoint.from(d['latitude'], d['longitude'])!),
                  icon: const Icon(Icons.directions),
                  label: const Text('Directions to their place'),
                ),
              ],
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () async {
                  Navigator.pop(sheet);
                  final ok = await push(context, DonorFormScreen(donor: d));
                  if (ok == true) changed();
                },
                icon: const Icon(Icons.edit_outlined),
                label: const Text('Edit details'),
              ),
              if (AppState.i.can('collect')) ...[
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(sheet);
                    push(
                      context,
                      NewEntryScreen(
                        collection: collection,
                        contributor: {
                          'name': d['name'],
                          'mobile': d['mobile'],
                          'place': d['place'],
                          'type': d['type'],
                          'unit': d['unit'],
                        },
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Record what they give now'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Add someone to the donor list (before they give), or change their details.
class DonorFormScreen extends StatefulWidget {
  const DonorFormScreen({super.key, this.donor});
  final Map<String, dynamic>? donor;

  @override
  State<DonorFormScreen> createState() => _DonorFormScreenState();
}

class _DonorFormScreenState extends State<DonorFormScreen> {
  static const types = ['Well-wisher', 'Member', 'Associate', 'Alumni', 'Business', 'Unit'];
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  GeoPoint? _loc;
  final _place = TextEditingController();
  final _notes = TextEditingController();
  String _type = 'Well-wisher';
  String? _unit;
  List<String> _units = [];
  bool _busy = false;

  Map<String, dynamic>? get _d => widget.donor;

  @override
  void initState() {
    super.initState();
    final d = _d;
    if (d != null) {
      _name.text = '${d['name'] ?? ''}';
      _mobile.text = '${d['mobile'] ?? ''}';
      _place.text = '${d['place'] ?? ''}';
      _loc = GeoPoint.from(d['latitude'], d['longitude']);
      _notes.text = '${d['notes'] ?? ''}';
      if (types.contains(d['type'])) _type = d['type'].toString();
      _unit = d['unit']?.toString();
    }
    final s = AppState.i;
    _unit ??= s.me['unit']?.toString();
    if (s.can('all_units')) {
      Api.myUnits()
          .then((v) {
            if (mounted) setState(() => _units = [for (final u in v) u['name'].toString()]);
          })
          .catchError((_) {});
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      await Api.call('${Api.m}save_donor', {
        'name': _d?['donor'],
        'donor_name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'place': _place.text.trim(),
        'latitude': _loc?.lat,
        'longitude': _loc?.lng,
        'clear_location': _loc == null ? 1 : null,
        'donor_type': _type,
        'unit': _unit,
        'notes': _notes.text.trim(),
      });
    }, done: _d == null ? '${_name.text.trim()} added to the donor list.' : 'Saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_d == null ? 'New donor' : 'Edit donor')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _place,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Place / address'),
          ),
          const SizedBox(height: 14),
          LocationField(
            value: _loc,
            hint: 'Use this when you are at their house or shop',
            onChanged: (g) => setState(() => _loc = g),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 14),
          if (AppState.i.can('all_units'))
            DropdownButtonFormField<String?>(
              initialValue: _units.contains(_unit) ? _unit : null,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: [for (final u in _units) DropdownMenuItem<String?>(value: u, child: Text(u))],
              onChanged: (v) => setState(() => _unit = v),
            )
          else
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Unit'),
              child: Text(_unit ?? 'My unit'),
            ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 2,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Notes (optional)',
              hintText: 'e.g. gives every Ramadan, call after Asr',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_d == null ? 'Add donor' : 'Save')),
        ],
      ),
    );
  }
}
