import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../photo.dart';
import '../widgets.dart';
import '../location.dart';
import 'collection_screens.dart';

Future<bool> confirm(BuildContext context, String title, String body, {String yes = 'Delete'}) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Keep')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: SioColors.danger),
            onPressed: () => Navigator.pop(d, true),
            child: Text(yes),
          ),
        ],
      ),
    ) ==
    true;

/// Every collection, open and closed. Finance and area admins add, change, close and delete them here.
class ManageCollectionsScreen extends StatelessWidget {
  const ManageCollectionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Collections & targets')),
      floatingActionButton: AddFab(tooltip: 'New collection', onPressed: () => push(context, const CollectionFormScreen())),
      body: Loader<List<dynamic>>(
        load: () async => (await Api.call('${Api.m}manage_collections') as List?) ?? [],
        builder: (context, list) => [
          if (list.isEmpty) const EmptyNote('No collections yet. Tap New collection.'),
          if (list.isNotEmpty)
            PanelList(
              children: [
                for (final c in list)
                  ListTile(
                    onTap: () => push(context, CollectionFormScreen(name: c['name'].toString())),
                    leading: CircleAvatar(
                      backgroundColor: SioColors.cardHigh,
                      foregroundColor: SioColors.blue,
                      child: Icon(collectionIcon(c['collection_type']?.toString())),
                    ),
                    title: Text(c['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                      [
                        c['collection_type'],
                        if (numOf(c['target_amount']) > 0) 'target ${inr(c['target_amount'])}',
                        '${inr(c['collected'])} received',
                      ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: StatusChip(
                      c['is_active'] == 1 ? 'Open' : 'Closed',
                      tone: c['is_active'] == 1 ? Tone.green : Tone.grey,
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Add or change a collection, its area target and how it is split among units.
class CollectionFormScreen extends StatefulWidget {
  const CollectionFormScreen({super.key, this.name});
  final String? name;

  @override
  State<CollectionFormScreen> createState() => _CollectionFormScreenState();
}

class _CollectionFormScreenState extends State<CollectionFormScreen> {
  static const types = ['Ramadan Collection', 'Baithul Mal', 'Zakat', 'Relief Fund', 'Other'];
  final _name = TextEditingController();
  final _target = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'Ramadan Collection';
  bool _open = true;
  DateTime? _from;
  DateTime? _to;
  int _entries = 0;
  List<Map<String, dynamic>> _units = [];
  final Map<String, TextEditingController> _unitTargets = {};
  bool _loading = true;
  bool _busy = false;
  String? _error;

  bool get _editing => widget.name != null;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = Map<String, dynamic>.from(await Api.call('${Api.m}collection_form', {'name': widget.name}) as Map);
      _units = [for (final u in (d['units'] as List? ?? [])) Map<String, dynamic>.from(u)];
      for (final u in _units) {
        _unitTargets[u['unit'].toString()] = TextEditingController();
      }
      final c = d['collection'] as Map?;
      if (c != null) {
        _name.text = c['collection_name'].toString();
        _type = types.contains(c['collection_type']) ? c['collection_type'].toString() : 'Other';
        _open = c['is_active'] == 1;
        _target.text = numOf(c['target_amount']) > 0 ? numOf(c['target_amount']).toStringAsFixed(0) : '';
        _desc.text = (c['description'] ?? '').toString();
        _from = parseDate(c['starts_on']);
        _to = parseDate(c['ends_on']);
        for (final t in (c['unit_targets'] as List? ?? [])) {
          _unitTargets.putIfAbsent(t['unit'].toString(), () => TextEditingController()).text = numOf(t['target'])
              .toStringAsFixed(0);
        }
      }
      _entries = (d['entries'] as num?)?.toInt() ?? 0;
    } catch (e) {
      _error = e.toString();
    }
    if (mounted) setState(() => _loading = false);
  }

  num get _target$ => num.tryParse(_target.text.trim()) ?? 0;
  num get _split => _unitTargets.values.fold<num>(0, (a, c) => a + (num.tryParse(c.text.trim()) ?? 0));

  /// Splits the area target among units; rounds to ₹100 and gives the remainder to the last unit.
  void _distribute({required bool byMembers}) {
    final total = _target$;
    if (total <= 0) {
      toast(context, 'Enter the total target first.');
      return;
    }
    final units = _units.map((u) => u['unit'].toString()).toList();
    if (units.isEmpty) return;
    final weights = [for (final u in _units) byMembers ? numOf(u['members']) : 1];
    final sumW = weights.fold<num>(0, (a, b) => a + b);
    if (sumW <= 0) {
      toast(context, 'No active members in any unit yet. Use Split equally.');
      return;
    }
    num given = 0;
    setState(() {
      for (var i = 0; i < units.length; i++) {
        num v;
        if (i == units.length - 1) {
          v = total - given;
        } else {
          v = (total * weights[i] / sumW / 100).floor() * 100;
          given += v;
        }
        _unitTargets[units[i]]!.text = v.toStringAsFixed(0);
      }
    });
  }

  Future<void> _save() async {
    if (!_editing && _name.text.trim().length < 3) {
      toast(context, 'Enter a name, e.g. Ramadan Collection 1448.');
      return;
    }
    if (_target$ > 0 && _split > 0 && _split != _target$) {
      final go = await confirm(
        context,
        'Unit targets don\'t add up',
        'Units add up to ${inr(_split)} but the total target is ${inr(_target$)}. Save anyway?',
        yes: 'Save',
      );
      if (!go || !mounted) return;
    }
    setState(() => _busy = true);
    final ok = await run(context, () async {
      await Api.call('${Api.m}save_collection', {
        'name': widget.name,
        'collection_name': _name.text.trim(),
        'collection_type': _type,
        'is_active': _open ? 1 : 0,
        'target_amount': _target.text.trim(),
        'starts_on': _from == null ? null : apiDate(_from!),
        'ends_on': _to == null ? null : apiDate(_to!),
        'description': _desc.text.trim(),
        'unit_targets': jsonEncode([
          for (final e in _unitTargets.entries)
            if ((num.tryParse(e.value.text.trim()) ?? 0) > 0) {'unit': e.key, 'target': e.value.text.trim()},
        ]),
      });
    }, done: _editing ? 'Collection saved.' : 'Collection added.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Future<void> _delete() async {
    if (_entries > 0) {
      final close = await confirm(
        context,
        'Close instead?',
        'This collection has $_entries entries, so it can\'t be deleted. Close it? It will stop showing in the app, and its records stay in the accounts.',
        yes: 'Close it',
      );
      if (!close || !mounted) return;
      setState(() => _open = false);
      await _save();
      return;
    }
    if (!await confirm(context, 'Delete ${widget.name}?', 'This removes the collection and its unit targets.')) return;
    if (!mounted) return;
    final ok = await run(
      context,
      () => Api.call('${Api.m}delete_collection', {'name': widget.name}),
      done: 'Collection deleted.',
    );
    if (ok && mounted) Navigator.pop(context);
  }

  Future<void> _pickDate(bool from) async {
    final d = await showDatePicker(
      context: context,
      initialDate: (from ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (d != null) setState(() => from ? _from = d : _to = d);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? 'Edit collection' : 'New collection'),
        actions: [
          if (_editing && !_loading)
            IconButton(tooltip: 'Delete or close', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (_error != null) SioBanner(text: _error!, error: true),
                TextField(
                  controller: _name,
                  enabled: !_editing,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'Ramadan Collection 1448'),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Type'),
                  items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calendar_today, size: 18),
                        label: Text(_from == null ? 'Starts' : fmtDate(apiDate(_from!), 'd MMM yy')),
                        onPressed: () => _pickDate(true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.event, size: 18),
                        label: Text(_to == null ? 'Ends' : fmtDate(apiDate(_to!), 'd MMM yy')),
                        onPressed: () => _pickDate(false),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _desc,
                  maxLines: 2,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(labelText: 'Note for members (optional)'),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Open'),
                  subtitle: const Text('Open collections show in the app'),
                  value: _open,
                  onChanged: (v) => setState(() => _open = v),
                ),
                const SectionTitle('Target'),
                TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(labelText: 'Total target for the area', prefixText: '₹ '),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(onPressed: () => _distribute(byMembers: false), child: const Text('Split equally')),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(onPressed: () => _distribute(byMembers: true), child: const Text('Split by members')),
                    ),
                  ],
                ),
                const SectionTitle('Each unit\'s target'),
                SioPanel(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: Column(
                    children: [
                      for (final u in _units)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 6),
                          child: Row(
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(u['unit'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                                    Text(
                                      '${numOf(u['members']).toInt()} active members',
                                      style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              SizedBox(
                                width: 140,
                                child: TextField(
                                  controller: _unitTargets[u['unit'].toString()],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.end,
                                  onChanged: (_) => setState(() {}),
                                  decoration: const InputDecoration(prefixText: '₹ ', isDense: true, hintText: '0'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const Divider(),
                      Row(
                        children: [
                          const Expanded(
                            child: Text('Units add up to', style: TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          Text(
                            inr(_split),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _target$ > 0 && _split != _target$ ? SioColors.danger : SioColors.green,
                            ),
                          ),
                        ],
                      ),
                      if (_target$ > 0 && _split != _target$)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            _split < _target$
                                ? '${inr(_target$ - _split)} not given to any unit yet'
                                : '${inr(_split - _target$)} more than the total',
                            style: TextStyle(color: SioColors.danger, fontSize: 12.5),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FilledButton(onPressed: _busy ? null : _save, child: Text(_editing ? 'Save' : 'Add collection')),
              ],
            ),
    );
  }
}

/// Add or change an event. Unit admins: their unit's events. Area admins: any unit or all units.
class EventFormScreen extends StatefulWidget {
  const EventFormScreen({super.key, this.event});
  final Map<String, dynamic>? event;

  @override
  State<EventFormScreen> createState() => _EventFormScreenState();
}

class _EventFormScreenState extends State<EventFormScreen> {
  static const types = ['Campus Programme', 'Camp', 'Workshop', 'Conference', 'Iftar', 'Other'];
  static const statuses = ['Planning', 'Registrations Open', 'Registrations Closed', 'Completed', 'Cancelled'];
  final _title = TextEditingController();
  final _venue = TextEditingController();
  final _capacity = TextEditingController();
  final _budget = TextEditingController();
  final _desc = TextEditingController();
  String _type = 'Campus Programme';
  String _status = 'Registrations Open';
  String _openTo = 'Everyone';
  String? _unit;
  DateTime _start = DateTime.now().add(const Duration(days: 7));
  List<String> _units = [];
  bool _busy = false;

  Map<String, dynamic>? get _e => widget.event;

  @override
  void initState() {
    super.initState();
    final e = _e;
    if (e != null) {
      _title.text = '${e['title'] ?? ''}';
      _venue.text = '${e['venue'] ?? ''}';
      _capacity.text = numOf(e['capacity']) > 0 ? '${numOf(e['capacity']).toInt()}' : '';
      _budget.text = numOf(e['budget']) > 0 ? numOf(e['budget']).toStringAsFixed(0) : '';
      _desc.text = '${e['description'] ?? ''}'.replaceAll(RegExp(r'<[^>]*>'), '');
      _type = types.contains(e['event_type']) ? e['event_type'].toString() : 'Campus Programme';
      _status = statuses.contains(e['status']) ? e['status'].toString() : 'Planning';
      _openTo = e['open_to'] == 'Members Only' ? 'Members Only' : 'Everyone';
      _unit = e['unit']?.toString();
      _start = parseDate(e['starts_on']) ?? _start;
    } else {
      _start = DateTime(_start.year, _start.month, _start.day, 17);
      if (!AppState.i.can('all_units')) _unit = AppState.i.me['unit']?.toString();
    }
    if (AppState.i.can('all_units')) {
      Api.myUnits()
          .then((v) {
            if (mounted) setState(() => _units = [for (final u in v) u['name'].toString()]);
          })
          .catchError((_) {});
    }
  }

  Future<void> _pickStart() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _start,
      firstDate: DateTime(2020),
      lastDate: DateTime(DateTime.now().year + 3),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_start));
    setState(() => _start = DateTime(d.year, d.month, d.day, t?.hour ?? _start.hour, t?.minute ?? _start.minute));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'Enter the event title.');
      return;
    }
    setState(() => _busy = true);
    final ok = await run(context, () async {
      await Api.call('${Api.m}save_event', {
        'name': _e?['name'],
        'title': _title.text.trim(),
        'event_type': _type,
        'starts_on':
            '${apiDate(_start)} ${_start.hour.toString().padLeft(2, '0')}:${_start.minute.toString().padLeft(2, '0')}:00',
        'venue': _venue.text.trim(),
        'status': _status,
        'open_to': _openTo,
        'unit': _unit,
        'capacity': _capacity.text.trim(),
        'budget': _budget.text.trim(),
        'description': _desc.text.trim(),
      });
    }, done: _e == null ? 'Event added.' : 'Event saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  Future<void> _delete() async {
    if (!await confirm(
      context,
      'Delete this event?',
      'Events with registrations or expenses can\'t be deleted: set the status to Cancelled instead.',
    )) {
      return;
    }
    if (!mounted) return;
    final ok = await run(context, () => Api.call('${Api.m}delete_event', {'name': _e!['name']}), done: 'Event deleted.');
    if (ok && mounted) Navigator.pop(context, 'deleted');
  }

  @override
  Widget build(BuildContext context) {
    final all = AppState.i.can('all_units');
    return Scaffold(
      appBar: AppBar(
        title: Text(_e == null ? 'New event' : 'Edit event'),
        actions: [
          if (_e != null)
            IconButton(tooltip: 'Delete', icon: const Icon(Icons.delete_outline), onPressed: _busy ? null : _delete),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: 'Type'),
            items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _type = v ?? _type),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            icon: const Icon(Icons.schedule),
            label: Text('Starts ${fmtDate(_start.toIso8601String(), 'EEE d MMM yyyy, h:mm a')}'),
            onPressed: _pickStart,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _venue,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Venue'),
          ),
          const SizedBox(height: 14),
          if (all)
            DropdownButtonFormField<String?>(
              initialValue: _units.contains(_unit) ? _unit : null,
              decoration: const InputDecoration(labelText: 'Unit'),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('All units')),
                for (final u in _units) DropdownMenuItem<String?>(value: u, child: Text(u)),
              ],
              onChanged: (v) => setState(() => _unit = v),
            )
          else
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Unit'),
              child: Text(_unit ?? 'My unit'),
            ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [for (final t in statuses) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _openTo,
            decoration: const InputDecoration(labelText: 'Who can register'),
            items: const [
              DropdownMenuItem(value: 'Everyone', child: Text('Everyone (students and members)')),
              DropdownMenuItem(value: 'Members Only', child: Text('Members only')),
            ],
            onChanged: (v) => setState(() => _openTo = v ?? _openTo),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _capacity,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Seats (optional)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _budget,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Budget', prefixText: '₹ '),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _desc,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Details (optional)'),
          ),
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_e == null ? 'Add event' : 'Save')),
        ],
      ),
    );
  }
}

/// Add a student / member directly, or change their details.
class MemberFormScreen extends StatefulWidget {
  const MemberFormScreen({super.key, this.member});
  final Map<String, dynamic>? member;

  @override
  State<MemberFormScreen> createState() => _MemberFormScreenState();
}

class _MemberFormScreenState extends State<MemberFormScreen> {
  static const years = [
    '',
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'PG 1st Year',
    'PG 2nd Year',
    'Research',
    'Other',
  ];
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _campus = TextEditingController();
  final _course = TextEditingController();
  final _town = TextEditingController();
  final _landmark = TextEditingController();
  GeoPoint? _loc;
  final _books = TextEditingController();
  final _note = TextEditingController();
  bool _mulakath = false;
  String? _newPhoto; // picked before the student is saved
  String _year = '';
  String _role = 'Associate';
  String _status = 'Active';
  String? _unit;
  String? _area;
  List<dynamic> _unitRows = []; // units with their area (district) this person may pick
  bool _busy = false;

  Map<String, dynamic>? get _m => widget.member;

  @override
  void initState() {
    super.initState();
    final m = _m;
    if (m != null) {
      _name.text = '${m['full_name'] ?? ''}';
      _mobile.text = '${m['mobile'] ?? ''}';
      _email.text = '${m['email'] ?? ''}';
      _campus.text = '${m['campus'] ?? ''}';
      _course.text = '${m['course'] ?? ''}';
      _town.text = '${m['home_town'] ?? ''}';
      _landmark.text = '${m['location_note'] ?? ''}';
      _loc = GeoPoint.from(m['latitude'], m['longitude']);
      _year = years.contains(m['year_of_study']) ? '${m['year_of_study']}' : '';
      _role = '${m['member_role'] ?? 'Associate'}';
      _status = m['status'] == 'Inactive' ? 'Inactive' : 'Active';
      _mulakath = m['mulakath_done'] == 1;
      _books.text = '${m['books_read'] ?? ''}';
      _note.text = '${m['membership_note'] ?? ''}';
      _unit = m['unit']?.toString();
      _area = m['area']?.toString();
    } else {
      _unit = AppState.i.level == 'unit' ? AppState.i.me['unit']?.toString() : null;
    }
    _area ??= AppState.i.area;
    if (AppState.i.can('all_units')) {
      Api.myUnits()
          .then((v) {
            if (mounted) setState(() => _unitRows = v);
          })
          .catchError((_) {});
    }
  }

  bool get _areaRole => AppState.areaRoles.contains(_role) || _role == 'Area Admin';
  List<String> get _areas => {
    for (final u in _unitRows)
      if ('${u['district'] ?? ''}'.isNotEmpty) '${u['district']}',
  }.toList()..sort();
  List<String> get _unitsInArea => [
    for (final u in _unitRows)
      if (_area == null || u['district'] == _area) u['name'].toString(),
  ];

  Future<void> _save() async {
    if (!_areaRole && (_unit == null || _unit!.isEmpty)) {
      toast(context, 'Pick the unit.');
      return;
    }
    if (AppState.areaRoles.contains(_role) && (_area == null || _area!.isEmpty)) {
      toast(context, 'Pick the area.');
      return;
    }
    setState(() => _busy = true);
    final ok = await run(context, () async {
      final r = await Api.call('${Api.m}save_member', {
        'name': _m?['name'],
        'full_name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim(),
        'unit': _areaRole ? null : _unit,
        'area': _area,
        'member_role': _role,
        'status': _m == null ? null : _status,
        'campus': _campus.text.trim(),
        'course': _course.text.trim(),
        'year_of_study': _year,
        'home_town': _town.text.trim(),
        'latitude': _loc?.lat,
        'longitude': _loc?.lng,
        'clear_location': _loc == null ? 1 : null,
        'location_note': _landmark.text.trim(),
        if (_m != null) ...{
          'mulakath_done': _mulakath ? 1 : 0,
          'books_read': _books.text.trim(),
          'membership_note': _note.text.trim(),
        },
      });
      if (_m == null && _newPhoto != null) {
        await Api.call('${Api.m}set_member_photo', {'member': (r as Map)['name'], 'photo_data': _newPhoto});
      }
    }, done: _m == null ? '${_name.text.trim()} added.' : 'Saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final roles = <String>{...AppState.i.givableRoles, _role}.toList();
    final areas = <String>{..._areas, ?_area}.toList();
    final unitsHere = _unitsInArea;
    return Scaffold(
      appBar: AppBar(title: Text(_m == null ? 'Add student' : 'Edit details')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          if (_m == null)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: SioBanner(text: 'They can sign up in the app later with this mobile number to get their own login.'),
            ),
          PhotoPicker(
            name: _name.text.isEmpty ? '?' : _name.text,
            photo: _m?['photo']?.toString(),
            memberId: _m?['name']?.toString(),
            onChanged: (u) => _m?['photo'] = u,
            onPicked: (b) => _newPhoto = b,
          ),
          const SizedBox(height: 6),
          Text(
            _m == null ? 'Add a photo (optional)' : 'Tap to change the photo',
            textAlign: TextAlign.center,
            style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Full name'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _mobile,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Mobile'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(labelText: 'Email (optional)'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: roles.contains(_role) ? _role : roles.first,
            decoration: const InputDecoration(labelText: 'Role'),
            items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r))],
            onChanged: (v) => setState(() => _role = v ?? _role),
          ),
          const SizedBox(height: 14),
          // area first, then a unit of that area (area roles have no unit)
          if (AppState.i.level == 'all' && areas.isNotEmpty)
            DropdownButtonFormField<String>(
              initialValue: areas.contains(_area) ? _area : null,
              decoration: const InputDecoration(labelText: 'Area', prefixIcon: Icon(Icons.hub_outlined)),
              items: [for (final a in areas) DropdownMenuItem(value: a, child: Text(a))],
              onChanged: (v) => setState(() {
                _area = v;
                if (_unit != null && !_unitsInArea.contains(_unit)) _unit = null;
              }),
            )
          else if (_area != null)
            InputDecorator(
              decoration: const InputDecoration(labelText: 'Area', prefixIcon: Icon(Icons.hub_outlined)),
              child: Text(_area!),
            ),
          if (!_areaRole) ...[
            const SizedBox(height: 14),
            if (AppState.i.can('all_units'))
              DropdownButtonFormField<String?>(
                initialValue: unitsHere.contains(_unit) ? _unit : null,
                decoration: const InputDecoration(labelText: 'Unit', prefixIcon: Icon(Icons.apartment_outlined)),
                hint: Text(unitsHere.isEmpty ? 'No units in this area' : 'Pick the unit'),
                items: [for (final u in unitsHere) DropdownMenuItem<String?>(value: u, child: Text(u))],
                onChanged: (v) => setState(() => _unit = v),
              )
            else
              InputDecorator(
                decoration: const InputDecoration(labelText: 'Unit', prefixIcon: Icon(Icons.apartment_outlined)),
                child: Text(_unit ?? 'My unit'),
              ),
          ],
          if (_m != null) ...[
            const SizedBox(height: 6),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive members drop off rosters and lists'),
              value: _status == 'Active',
              onChanged: (v) => setState(() => _status = v ? 'Active' : 'Inactive'),
            ),
          ],
          const SectionTitle('Study'),
          TextField(
            controller: _campus,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Campus / college'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _course,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Course'),
          ),
          const SizedBox(height: 14),
          DropdownButtonFormField<String>(
            initialValue: _year,
            decoration: const InputDecoration(labelText: 'Year'),
            items: [for (final y in years) DropdownMenuItem(value: y, child: Text(y.isEmpty ? '—' : y))],
            onChanged: (v) => setState(() => _year = v ?? ''),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _town,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Home town'),
          ),
          const SizedBox(height: 14),
          LocationField(value: _loc, hint: 'Use this when you are at their house', onChanged: (g) => setState(() => _loc = g)),
          const SizedBox(height: 10),
          TextField(
            controller: _landmark,
            decoration: const InputDecoration(labelText: 'House name / landmark (optional)'),
          ),
          if (_m != null && (_role == 'Associate' || _role == 'Worker' || _mulakath || _books.text.isNotEmpty)) ...[
            const SectionTitle('Path to membership'),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Mulakath done'),
              value: _mulakath,
              onChanged: (v) => setState(() => _mulakath = v),
            ),
            TextField(
              controller: _books,
              maxLines: 4,
              minLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Books read', helperText: 'One book per line'),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _note,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note (optional)'),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(onPressed: _busy ? null : _save, child: Text(_m == null ? 'Add student' : 'Save')),
        ],
      ),
    );
  }
}
