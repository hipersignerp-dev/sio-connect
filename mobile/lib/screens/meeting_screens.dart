import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'meeting_summary_screen.dart';

class MeetingsScreen extends StatelessWidget {
  const MeetingsScreen({super.key, this.standalone = false});
  final bool standalone;

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    return Scaffold(
      appBar: AppBar(
        title: Text(standalone ? 'Pick a meeting' : 'Meetings'),
      ),
      floatingActionButton: standalone && s.can('schedule_meeting')
          ? AddFab(tooltip: 'Schedule meeting', onPressed: () => push(context, const ScheduleMeetingScreen()))
          : null,
      body: Loader<Map<String, dynamic>>(
        load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}meetings') as Map),
        builder: (context, d) {
          final list = (d['meetings'] as List?) ?? [];
          final sum = (d['summary'] as Map?) ?? {};
          return [
            SioPanel(
              padding: const EdgeInsets.all(18),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('This week', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink)),
                const SizedBox(height: 14),
                Row(children: [
                  Stat('${sum['this_week'] ?? 0}', 'Meetings'),
                  Stat('${sum['attendance_pct'] ?? 0}%', 'Attendance'),
                  if (s.can('mark_attendance'))
                    Stat('${sum['to_mark'] ?? 0}', 'To mark',
                        color: numOf(sum['to_mark']) > 0 ? SioColors.danger : SioColors.blue),
                ]),
              ]),
            ),
            const SectionTitle('Unit meetings'),
            if (list.isEmpty) const EmptyNote('No meetings yet.'),
            if (list.isNotEmpty)
              PanelList(children: [
                for (final m in list) _MeetingRow(m: Map<String, dynamic>.from(m)),
              ]),
          ];
        },
      ),
    );
  }
}

class _MeetingRow extends StatelessWidget {
  const _MeetingRow({required this.m});
  final Map<String, dynamic> m;

  @override
  Widget build(BuildContext context) {
    final d = parseDate(m['meeting_date']);
    final today = DateTime.now();
    final due = m['status'] == 'Scheduled' && d != null && !d.isAfter(DateTime(today.year, today.month, today.day));
    String label;
    if (m['status'] == 'Completed') {
      label = m['my_status'] != null && !AppState.i.can('mark_attendance') ? m['my_status'] : '${m['present_count']}/${m['total_count']}';
    } else if (due && AppState.i.can('mark_attendance')) {
      label = 'Mark now';
    } else {
      label = m['my_rsvp']?.toString().isNotEmpty == true ? m['my_rsvp'] : 'Upcoming';
    }
    final tone = label == 'Mark now'
        ? Tone.red
        : m['status'] == 'Completed'
            ? (label == 'Absent' ? Tone.red : Tone.green)
            : StatusChip.toneFor(label) == Tone.grey
                ? Tone.blue
                : StatusChip.toneFor(label);
    return ListTile(
      onTap: () => push(context, MeetingScreen(name: m['name'].toString())),
      leading: SizedBox(
        width: 40,
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(fmtDate(m['meeting_date'], 'EEE').toUpperCase(),
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: SioColors.red)),
          Text(fmtDate(m['meeting_date'], 'd'), style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: SioColors.ink)),
        ]),
      ),
      title: Text(m['unit'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text([m['topic'], fmtTime(m['meeting_time'])].where((e) => e != null && '$e'.isNotEmpty).join(' · ')),
      trailing: StatusChip(label, tone: tone),
    );
  }
}

/// Meeting details. Unit admins mark attendance and minutes here; others can RSVP.
class MeetingScreen extends StatefulWidget {
  const MeetingScreen({super.key, required this.name});
  final String name;

  @override
  State<MeetingScreen> createState() => _MeetingScreenState();
}

class _MeetingScreenState extends State<MeetingScreen> {
  Map<String, dynamic>? _m;
  String? _error;
  final Set<String> _present = {};
  final _minutes = TextEditingController();
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final m = Map<String, dynamic>.from(await Api.call('${Api.m}meeting', {'name': widget.name}) as Map);
      _present
        ..clear()
        ..addAll([for (final r in (m['roster'] as List? ?? [])) if (r['status'] == 'Present') r['member'].toString()]);
      final sum = '${m['summary'] ?? ''}'.trim();
      _minutes.text = sum.isNotEmpty ? sum : (m['minutes'] ?? '').toString().replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (mounted) setState(() => _m = m);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}save_attendance', {'name': widget.name, 'present': _present.toList()}),
      done: 'Attendance saved: ${_present.length} present.',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = _m;
    final roster = (m?['roster'] as List?) ?? [];
    final canMark = AppState.i.can('mark_attendance') && m != null && m.containsKey('roster');
    return Scaffold(
      appBar: AppBar(
        title: Text(canMark ? 'Meeting & attendance' : 'Meeting'),
        actions: [
          if (m != null && m['can_edit'] == true)
            IconButton(
              tooltip: 'Edit meeting',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final changed = await push<bool>(context, ScheduleMeetingScreen(meeting: m));
                if (changed == true) _load();
              },
            ),
        ],
      ),
      body: m == null
          ? Center(child: _error == null ? const CircularProgressIndicator() : Padding(padding: const EdgeInsets.all(24), child: SioBanner(text: _error!, error: true)))
          : ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
              SioPanel(
                child: Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(m['topic'].toString(), style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: SioColors.ink)),
                      const SizedBox(height: 2),
                      Text(
                          [m['unit'], fmtDate(m['meeting_date'], 'EEE d MMM'), fmtTime(m['meeting_time']), m['venue']]
                              .where((e) => e != null && '$e'.isNotEmpty)
                              .join(' · '),
                          style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
                    ]),
                  ),
                  if (canMark)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: SioColors.greenBg, borderRadius: BorderRadius.circular(20)),
                      child: Text('${_present.length} / ${roster.length}',
                          style: const TextStyle(color: SioColors.green, fontWeight: FontWeight.w700)),
                    )
                  else
                    StatusChip(m['status'].toString(), tone: StatusChip.toneFor(m['status'].toString())),
                ]),
              ),
              if ((m['agenda'] ?? '').toString().isNotEmpty) ...[
                const SectionTitle('Agenda'),
                SioPanel(child: Text(m['agenda'].toString())),
              ],
              if (canMark) ...[
                SectionTitle('Who came', action: TextButton(
                  onPressed: () => setState(() {
                    if (_present.length == roster.length) {
                      _present.clear();
                    } else {
                      _present.addAll(roster.map((r) => r['member'].toString()));
                    }
                  }),
                  child: Text(_present.length == roster.length ? 'Clear all' : 'All present'),
                )),
                if (roster.isEmpty) const EmptyNote('No active members in this unit yet.'),
                if (roster.isNotEmpty)
                  PanelList(children: [
                    for (final r in roster)
                      Builder(builder: (context) {
                        final id = r['member'].toString();
                        final on = _present.contains(id);
                        return ListTile(
                          leading: Avatar(r['full_name'].toString(), radius: 18, light: true, photo: r['photo']),
                          title: Text(r['full_name'].toString()),
                          subtitle: (r['rsvp'] ?? '').toString().isEmpty ? null : Text('RSVP: ${r['rsvp']}'),
                          trailing: FilledButton(
                            style: FilledButton.styleFrom(
                              minimumSize: const Size(92, 38),
                              backgroundColor: on ? SioColors.green : SioColors.dangerBg,
                              foregroundColor: on ? Colors.white : SioColors.danger,
                              textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                            ),
                            onPressed: () => setState(() => on ? _present.remove(id) : _present.add(id)),
                            child: Text(on ? 'Present' : 'Absent'),
                          ),
                          onTap: () => setState(() => on ? _present.remove(id) : _present.add(id)),
                        );
                      }),
                  ]),
                const SizedBox(height: 16),
                FilledButton(onPressed: _busy ? null : _save, child: const Text('Save attendance')),
              const SectionTitle('Summary'),
              if (_minutes.text.isNotEmpty)
                SioPanel(child: SelectableText(_minutes.text, style: const TextStyle(height: 1.45)))
              else if (m['can_edit'] != true)
                const EmptyNote('No summary yet.'),
              if (m['can_edit'] == true) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final saved = await push<bool>(context, MeetingSummaryScreen(meeting: m));
                    if (saved == true) _load();
                  },
                  icon: const Icon(Icons.mic_none),
                  label: Text(_minutes.text.isEmpty ? 'Add summary (speak or type)' : 'Edit summary'),
                ),
              ],
              ] else ...[
              const SectionTitle('Summary'),
              if (_minutes.text.isNotEmpty)
                SioPanel(child: SelectableText(_minutes.text, style: const TextStyle(height: 1.45)))
              else if (m['can_edit'] != true)
                const EmptyNote('No summary yet.'),
              if (m['can_edit'] == true) ...[
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final saved = await push<bool>(context, MeetingSummaryScreen(meeting: m));
                    if (saved == true) _load();
                  },
                  icon: const Icon(Icons.mic_none),
                  label: Text(_minutes.text.isEmpty ? 'Add summary (speak or type)' : 'Edit summary'),
                ),
              ],
                if (m['status'] == 'Scheduled' && AppState.i.can('rsvp')) ...[
                  const SizedBox(height: 16),
                  Row(children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(backgroundColor: SioColors.green),
                        onPressed: () async {
                          await run(context, () => Api.call('${Api.m}rsvp', {'name': widget.name, 'attending': 1}), done: 'Marked as attending.');
                          _load();
                        },
                        child: const Text('I’ll attend'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () async {
                          await run(context, () => Api.call('${Api.m}rsvp', {'name': widget.name, 'attending': 0}), done: 'Marked as not attending.');
                          _load();
                        },
                        child: const Text('Can’t make it'),
                      ),
                    ),
                  ]),
                  if (m['my_rsvp'] != null && '${m['my_rsvp']}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text('Your reply: ${m['my_rsvp']}', textAlign: TextAlign.center, style: const TextStyle(color: SioColors.textSecondary)),
                    ),
                ],
              ],
            ]),
    );
  }
}

class ScheduleMeetingScreen extends StatefulWidget {
  const ScheduleMeetingScreen({super.key, this.meeting});
  final Map<String, dynamic>? meeting; // set when editing

  @override
  State<ScheduleMeetingScreen> createState() => _ScheduleMeetingScreenState();
}

class _ScheduleMeetingScreenState extends State<ScheduleMeetingScreen> {
  final _topic = TextEditingController();
  final _venue = TextEditingController();
  final _agenda = TextEditingController();
  String _type = 'Weekly Meeting';
  DateTime _date = DateTime.now();
  TimeOfDay _time = const TimeOfDay(hour: 19, minute: 30);
  bool _busy = false;
  String _status = 'Scheduled';
  late String? _unit = widget.meeting?['unit']?.toString() ?? AppState.i.me['unit']?.toString();
  Map<String, dynamic>? get _m => widget.meeting;
  List<String> _units = [];

  static const types = ['Weekly Meeting', 'Study Circle', 'Executive Meeting', 'Special Meeting'];

  /// Area admins and finance work across units (and may have no unit of their own), so they pick one.
  bool get _pickUnit => AppState.i.can('all_units') || _unit == null;

  @override
  void initState() {
    super.initState();
    final m = _m;
    if (m != null) {
      _topic.text = '${m['topic'] ?? ''}';
      _venue.text = '${m['venue'] ?? ''}';
      _agenda.text = '${m['agenda'] ?? ''}';
      if (types.contains(m['meeting_type'])) _type = '${m['meeting_type']}';
      _date = parseDate(m['meeting_date']) ?? _date;
      final t = '${m['meeting_time'] ?? ''}'.split(':');
      if (t.length >= 2) _time = TimeOfDay(hour: int.tryParse(t[0]) ?? 19, minute: int.tryParse(t[1]) ?? 30);
      if (const ['Scheduled', 'Completed', 'Cancelled'].contains(m['status'])) _status = '${m['status']}';
    }
    if (_pickUnit) {
      Api.units().then((v) {
        if (mounted) setState(() => _units = [for (final u in v) u['name'].toString()]);
      }).catchError((_) {});
    }
  }

  Future<void> _save() async {
    if (_topic.text.trim().isEmpty) {
      toast(context, 'Enter the topic.');
      return;
    }
    if (_unit == null || _unit!.isEmpty) {
      toast(context, 'Pick the unit this meeting is for.');
      return;
    }
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}schedule_meeting', {
        'name': _m?['name'],
        'status': _m == null ? null : _status,
        'topic': _topic.text.trim(),
        'unit': _unit,
        'meeting_type': _type,
        'meeting_date': apiDate(_date),
        'meeting_time': '${_time.hour.toString().padLeft(2, '0')}:${_time.minute.toString().padLeft(2, '0')}:00',
        'venue': _venue.text.trim(),
        'agenda': _agenda.text.trim(),
      }),
      done: _m == null ? 'Meeting scheduled. $_unit unit can see it now.' : 'Meeting updated.',
    );
    if (mounted) {
      setState(() => _busy = false);
      if (ok) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_m == null ? 'Schedule meeting' : 'Edit meeting')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        if (_pickUnit) ...[
          DropdownButtonFormField<String>(
            initialValue: _units.contains(_unit) ? _unit : null,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Unit', prefixIcon: Icon(Icons.apartment_outlined)),
            hint: Text(_units.isEmpty ? 'Loading units…' : 'Pick a unit'),
            items: [for (final u in _units) DropdownMenuItem(value: u, child: Text(u))],
            onChanged: (v) => setState(() => _unit = v),
          ),
          const SizedBox(height: 14),
        ],
        TextField(controller: _topic, textCapitalization: TextCapitalization.sentences, decoration: const InputDecoration(labelText: 'Topic')),
        const SizedBox(height: 14),
        DropdownButtonFormField<String>(
          initialValue: _type,
          decoration: const InputDecoration(labelText: 'Type'),
          items: [for (final t in types) DropdownMenuItem(value: t, child: Text(t))],
          onChanged: (v) => setState(() => _type = v ?? _type),
        ),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.calendar_today),
              label: Text(fmtDate(_date.toIso8601String(), 'EEE d MMM')),
              onPressed: () async {
                final d = await showDatePicker(
                    context: context, initialDate: _date, firstDate: DateTime.now().subtract(const Duration(days: 400)), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _date = d);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: OutlinedButton.icon(
              icon: const Icon(Icons.schedule),
              label: Text(_time.format(context)),
              onPressed: () async {
                final t = await showTimePicker(context: context, initialTime: _time);
                if (t != null) setState(() => _time = t);
              },
            ),
          ),
        ]),
        const SizedBox(height: 14),
        TextField(controller: _venue, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Venue')),
        const SizedBox(height: 14),
        TextField(controller: _agenda, maxLines: 4, decoration: const InputDecoration(labelText: 'Agenda')),
        const SizedBox(height: 20),
        if (_m != null) ...[
          DropdownButtonFormField<String>(
            initialValue: _status,
            decoration: const InputDecoration(labelText: 'Status'),
            items: [for (final t in const ['Scheduled', 'Completed', 'Cancelled']) DropdownMenuItem(value: t, child: Text(t))],
            onChanged: (v) => setState(() => _status = v ?? _status),
          ),
          const SizedBox(height: 16),
        ],
        FilledButton(onPressed: _busy ? null : _save, child: Text(_m == null ? 'Schedule' : 'Save changes')),
      ]),
    );
  }
}
