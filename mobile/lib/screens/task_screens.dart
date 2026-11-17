import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'event_detail_screen.dart';

/// Common responsibilities in an event team; any other text can be typed too.
const kResponsibilities = [
  'Coordinator',
  'Media',
  'Stage',
  'Food',
  'Volunteers',
  'Registration',
  'Transport',
  'Finance',
  'Guests',
];

Color taskColor(String? status) => switch (status) {
  'Done' => SioColors.green,
  'In Progress' => SioColors.blue,
  _ => SioColors.warning,
};

bool _late(Map t) {
  final d = parseDate(t['due_on']);
  return t['status'] != 'Done' && d != null && d.isBefore(DateTime.now());
}

/// Team and Tasks sections for the event page.
List<Widget> teamAndTaskSections(BuildContext context, Map<String, dynamic> e) {
  final boss = e['can_manage_tasks'] == true;
  final team = (e['team'] as List?) ?? [];
  final tasks = (e['tasks'] as List?) ?? [];
  final people = [for (final p in (e['people'] as List?) ?? []) Map<String, dynamic>.from(p)];
  if (!boss && team.isEmpty && tasks.isEmpty) return [];
  final done = tasks.where((t) => t['status'] == 'Done').length;
  return [
    SectionTitle(
      'Team',
      action: boss
          ? TextButton.icon(
              onPressed: () => push(context, TeamFormScreen(event: e['name'].toString(), team: team, people: people)),
              icon: const Icon(Icons.edit_outlined, size: 18),
              label: Text(team.isEmpty ? 'Add people' : 'Edit'),
            )
          : null,
    ),
    if (team.isEmpty)
      const EmptyNote('No team yet. Add a coordinator, media, stage and other people.')
    else
      PanelList(
        children: [
          for (final m in team)
            ListTile(
              leading: Avatar('${m['member_name'] ?? '?'}', radius: 18, light: true),
              title: Text('${m['member_name'] ?? m['member']}'),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (m['responsibility'] == 'Coordinator' ? SioColors.red : SioColors.blue).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${m['responsibility'] ?? ''}',
                  style: TextStyle(
                    color: m['responsibility'] == 'Coordinator' ? SioColors.red : SioColors.blue,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
            ),
        ],
      ),
    SectionTitle(
      tasks.isEmpty ? 'Tasks' : 'Tasks · $done of ${tasks.length} done',
      action: boss
          ? TextButton.icon(
              onPressed: () => push(context, TaskFormScreen(event: e['name'].toString(), people: people, team: team)),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Add task'),
            )
          : null,
    ),
    if (tasks.isNotEmpty) ...[ProgressBar(done / tasks.length), const SizedBox(height: 10)],
    if (tasks.isEmpty)
      EmptyNote(boss ? 'No tasks yet. Add tasks like stage setting, posters, sound.' : 'No tasks for you here.')
    else
      PanelList(
        children: [
          for (final t in tasks)
            TaskTile(
              t: Map<String, dynamic>.from(t),
              onTap: () => showTaskSheet(
                context,
                Map<String, dynamic>.from(t),
                boss: boss,
                event: e['name'].toString(),
                people: people,
                team: team,
              ),
            ),
        ],
      ),
  ];
}

class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.t, this.onTap, this.showEvent = false});
  final Map<String, dynamic> t;
  final VoidCallback? onTap;
  final bool showEvent;

  @override
  Widget build(BuildContext context) {
    final late = _late(t);
    final c = taskColor(t['status']?.toString());
    final due = parseDate(t['due_on']);
    return ListTile(
      onTap: onTap,
      leading: Icon(
        t['status'] == 'Done'
            ? Icons.check_circle
            : t['status'] == 'In Progress'
            ? Icons.timelapse
            : Icons.radio_button_unchecked,
        color: c,
      ),
      title: Text(
        '${t['title']}',
        style: TextStyle(
          fontWeight: FontWeight.w600,
          decoration: t['status'] == 'Done' ? TextDecoration.lineThrough : null,
          color: t['status'] == 'Done' ? SioColors.textSecondary : SioColors.ink,
        ),
      ),
      subtitle: Text(
        [
          if (showEvent) t['event_title'],
          if (!showEvent) t['assigned_name'] ?? 'Not assigned',
          t['responsibility'],
          if (due != null) '${late ? 'Late · was due' : 'Due'} ${DateFormat('d MMM, h:mm a').format(due)}',
        ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
        style: TextStyle(color: late ? SioColors.danger : SioColors.textSecondary, fontSize: 13),
      ),
      trailing: Text(
        '${t['status']}',
        style: TextStyle(color: c, fontWeight: FontWeight.w700, fontSize: 12.5),
      ),
    );
  }
}

/// Task details: the person updates status and notes; organisers can also edit, remind or delete.
Future<void> showTaskSheet(
  BuildContext context,
  Map<String, dynamic> t, {
  required bool boss,
  String? event,
  List<Map<String, dynamic>> people = const [],
  List team = const [],
}) async {
  final notes = TextEditingController(text: '${t['notes'] ?? ''}');
  final mine = t['assigned_to'] != null && t['assigned_to'] == AppState.i.me['member'];
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (s) => Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(s).bottom),
      child: StatefulBuilder(
        builder: (s, setS) {
          Future<void> setStatus(String st) async {
            final ok = await run(
              s,
              () => Api.call('${Api.m}save_task', {'name': t['name'], 'status': st, 'notes': notes.text.trim()}),
              done: st == 'Done' ? 'Marked done. Thank you!' : 'Updated.',
            );
            if (ok && s.mounted) {
              Navigator.pop(s);
              AppState.i.refreshAll();
            }
          }

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                '${t['title']}',
                style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
              const SizedBox(height: 4),
              Text(
                [
                  t['event_title'],
                  t['assigned_name'] ?? 'Not assigned',
                  t['responsibility'],
                  if (parseDate(t['due_on']) != null) 'Due ${DateFormat('EEE d MMM, h:mm a').format(parseDate(t['due_on'])!)}',
                ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                style: const TextStyle(color: SioColors.textSecondary),
              ),
              const SizedBox(height: 14),
              if (mine || boss) ...[
                TextField(
                  controller: notes,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: 'Notes / progress', alignLabelWithHint: true),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    for (final st in const ['Open', 'In Progress', 'Done']) ...[
                      Expanded(
                        child: t['status'] == st
                            ? FilledButton(
                                style: FilledButton.styleFrom(backgroundColor: taskColor(st)),
                                onPressed: () => setStatus(st),
                                child: Text(st, maxLines: 1),
                              )
                            : OutlinedButton(onPressed: () => setStatus(st), child: Text(st, maxLines: 1)),
                      ),
                      if (st != 'Done') const SizedBox(width: 8),
                    ],
                  ],
                ),
              ] else if ('${t['notes'] ?? ''}'.isNotEmpty)
                Text('${t['notes']}'),
              if (boss) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextButton.icon(
                        onPressed: t['assigned_to'] == null || t['status'] == 'Done'
                            ? null
                            : () async {
                                final ok = await run(
                                  s,
                                  () => Api.call('${Api.m}remind_task', {'name': t['name']}),
                                  done: 'Reminder sent to ${t['assigned_name']}.',
                                );
                                if (ok && s.mounted) Navigator.pop(s);
                              },
                        icon: const Icon(Icons.notifications_active_outlined),
                        label: const Text('Remind'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        onPressed: () {
                          Navigator.pop(s);
                          push(context, TaskFormScreen(event: event ?? '${t['event']}', task: t, people: people, team: team));
                        },
                        icon: const Icon(Icons.edit_outlined),
                        label: const Text('Edit'),
                      ),
                    ),
                    Expanded(
                      child: TextButton.icon(
                        style: TextButton.styleFrom(foregroundColor: SioColors.danger),
                        onPressed: () async {
                          if (!await confirmAction(s, 'Delete this task?')) return;
                          if (!s.mounted) return;
                          final ok = await run(
                            s,
                            () => Api.call('${Api.m}delete_task', {'name': t['name']}),
                            done: 'Task deleted.',
                          );
                          if (ok && s.mounted) {
                            Navigator.pop(s);
                            AppState.i.refreshAll();
                          }
                        },
                        icon: const Icon(Icons.delete_outline),
                        label: const Text('Delete'),
                      ),
                    ),
                  ],
                ),
              ],
              if (t['event'] != null && event == null) ...[
                const SizedBox(height: 6),
                TextButton(
                  onPressed: () {
                    Navigator.pop(s);
                    push(context, EventDetailScreen(name: '${t['event']}', title: '${t['event_title'] ?? 'Event'}'));
                  },
                  child: const Text('Open the event'),
                ),
              ],
            ],
          );
        },
      ),
    ),
  );
}

Future<bool> confirmAction(BuildContext context, String q) async =>
    await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        content: Text(q),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(d, true), child: const Text('Yes')),
        ],
      ),
    ) ??
    false;

/// Picks one person from the event's people, with search.
Future<Map<String, dynamic>?> pickPerson(BuildContext context, List<Map<String, dynamic>> people) =>
    showModalBottomSheet<Map<String, dynamic>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (s) {
        var q = '';
        return StatefulBuilder(
          builder: (s, setS) {
            final list = people.where((p) => q.isEmpty || '${p['full_name']}'.toLowerCase().contains(q.toLowerCase())).toList();
            return SizedBox(
              height: MediaQuery.sizeOf(s).height * 0.75,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                    child: TextField(
                      autofocus: true,
                      decoration: const InputDecoration(prefixIcon: Icon(Icons.search), hintText: 'Search name'),
                      onChanged: (v) => setS(() => q = v),
                    ),
                  ),
                  Expanded(
                    child: list.isEmpty
                        ? const Center(child: Text('No one found.'))
                        : ListView(
                            children: [
                              for (final p in list)
                                ListTile(
                                  leading: Avatar('${p['full_name']}', radius: 18, light: true),
                                  title: Text('${p['full_name']}'),
                                  subtitle: Text(
                                    [p['member_role'], p['unit']].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                                  ),
                                  onTap: () => Navigator.pop(s, p),
                                ),
                            ],
                          ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );

/// Who does what in the event.
class TeamFormScreen extends StatefulWidget {
  const TeamFormScreen({super.key, required this.event, required this.team, required this.people});
  final String event;
  final List team;
  final List<Map<String, dynamic>> people;

  @override
  State<TeamFormScreen> createState() => _TeamFormScreenState();
}

class _TeamFormScreenState extends State<TeamFormScreen> {
  late final List<Map<String, dynamic>> _rows = [
    for (final t in widget.team)
      {'member': t['member'], 'member_name': t['member_name'], 'responsibility': t['responsibility'] ?? 'Volunteers'},
  ];
  bool _busy = false;

  Future<void> _add() async {
    final p = await pickPerson(context, widget.people);
    if (p == null || !mounted) return;
    final r = await _pickResponsibility(_rows.isEmpty ? 'Coordinator' : null);
    if (r == null) return;
    setState(() => _rows.add({'member': p['name'], 'member_name': p['full_name'], 'responsibility': r}));
  }

  Future<String?> _pickResponsibility(String? current) async {
    final other = TextEditingController();
    return showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (s) => Padding(
        padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(s).bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text('Responsibility', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final r in kResponsibilities)
                  ChoiceChip(label: Text(r), selected: r == current, onSelected: (_) => Navigator.pop(s, r)),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: other,
              decoration: InputDecoration(
                labelText: 'Or type another',
                suffixIcon: IconButton(
                  icon: const Icon(Icons.check),
                  onPressed: () => Navigator.pop(s, other.text.trim().isEmpty ? null : other.text.trim()),
                ),
              ),
              onSubmitted: (v) => Navigator.pop(s, v.trim().isEmpty ? null : v.trim()),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}save_event_team', {
        'event': widget.event,
        'team': [
          for (final r in _rows) {'member': r['member'], 'responsibility': r['responsibility']},
        ],
      }),
      done: 'Team saved. New people have been told.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppState.i.refreshAll();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Event team')),
    floatingActionButton: AddFab(tooltip: 'Add person', onPressed: _add),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const SioBanner(text: 'Add the coordinator, media person and others. The coordinator can also add tasks.'),
        const SizedBox(height: 12),
        if (_rows.isEmpty) const EmptyNote('Tap + to add people.'),
        if (_rows.isNotEmpty)
          PanelList(
            children: [
              for (var i = 0; i < _rows.length; i++)
                ListTile(
                  leading: Avatar('${_rows[i]['member_name']}', radius: 18, light: true),
                  title: Text('${_rows[i]['member_name']}'),
                  subtitle: Text('${_rows[i]['responsibility']}'),
                  onTap: () async {
                    final r = await _pickResponsibility('${_rows[i]['responsibility']}');
                    if (r != null) setState(() => _rows[i]['responsibility'] = r);
                  },
                  trailing: IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _rows.removeAt(i))),
                ),
            ],
          ),
        const SizedBox(height: 18),
        FilledButton(onPressed: _busy ? null : _save, child: const Text('Save team')),
        const SizedBox(height: 70),
      ],
    ),
  );
}

/// Add or change a task.
class TaskFormScreen extends StatefulWidget {
  const TaskFormScreen({super.key, required this.event, this.task, required this.people, this.team = const []});
  final String event;
  final Map<String, dynamic>? task;
  final List<Map<String, dynamic>> people;
  final List team;

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  late final _title = TextEditingController(text: '${widget.task?['title'] ?? ''}');
  late final _notes = TextEditingController(text: '${widget.task?['notes'] ?? ''}');
  late String? _resp = widget.task?['responsibility']?.toString();
  late String? _who = widget.task?['assigned_to']?.toString();
  late String? _whoName = widget.task?['assigned_name']?.toString();
  late DateTime? _due = parseDate(widget.task?['due_on']);
  bool _busy = false;

  Future<void> _pickDue() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: now.subtract(const Duration(days: 30)),
      lastDate: now.add(const Duration(days: 365)),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due ?? DateTime(0, 1, 1, 18)));
    setState(() => _due = DateTime(d.year, d.month, d.day, t?.hour ?? 18, t?.minute ?? 0));
  }

  Future<void> _save() async {
    if (_title.text.trim().isEmpty) {
      toast(context, 'Enter the task.');
      return;
    }
    setState(() => _busy = true);
    final ok = await run(
      context,
      () => Api.call('${Api.m}save_task', {
        'name': widget.task?['name'],
        'event': widget.event,
        'title': _title.text.trim(),
        'responsibility': _resp,
        'assigned_to': _who,
        'due_on': _due == null ? null : DateFormat('yyyy-MM-dd HH:mm:ss').format(_due!),
        'notes': _notes.text.trim(),
      }),
      done: _who == null ? 'Task saved.' : 'Task saved. $_whoName has been told.',
    );
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) {
      AppState.i.refreshAll();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final teamPeople = [for (final t in widget.team) '${t['member']}'];
    // team members first in the picker
    final people = [
      ...widget.people.where((p) => teamPeople.contains(p['name'])),
      ...widget.people.where((p) => !teamPeople.contains(p['name'])),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(widget.task == null ? 'New task' : 'Edit task')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _title,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Task', hintText: 'e.g. Stage setting, posters, sound system'),
          ),
          const SizedBox(height: 14),
          const Text('Team / responsibility', style: TextStyle(fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final r in kResponsibilities.where((r) => r != 'Coordinator'))
                ChoiceChip(label: Text(r), selected: _resp == r, onSelected: (v) => setState(() => _resp = v ? r : null)),
            ],
          ),
          const SizedBox(height: 14),
          InkWell(
            onTap: () async {
              final p = await pickPerson(context, people);
              if (p != null) {
                setState(() {
                  _who = p['name'].toString();
                  _whoName = p['full_name'].toString();
                  // use the person's team responsibility if they have one
                  for (final t in widget.team) {
                    if (t['member'] == _who && _resp == null && t['responsibility'] != 'Coordinator') {
                      _resp = t['responsibility']?.toString();
                    }
                  }
                });
              }
            },
            child: InputDecorator(
              decoration: InputDecoration(
                labelText: 'Assigned to',
                prefixIcon: const Icon(Icons.person_outline),
                suffixIcon: _who == null
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _who = null;
                          _whoName = null;
                        }),
                      ),
              ),
              child: Text(_whoName ?? 'Pick a person'),
            ),
          ),
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: _pickDue,
            icon: const Icon(Icons.schedule),
            label: Text(_due == null ? 'Set due date & time' : 'Due ${DateFormat('EEE d MMM, h:mm a').format(_due!)}'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notes,
            maxLines: 3,
            decoration: const InputDecoration(labelText: 'Notes (optional)', alignLabelWithHint: true),
          ),
          const SizedBox(height: 8),
          const Text(
            'The person gets a notification now, and a reminder every morning when the task is due within 2 days or late.',
            style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
          ),
          const SizedBox(height: 18),
          FilledButton(onPressed: _busy ? null : _save, child: const Text('Save task')),
        ],
      ),
    );
  }
}

/// Everything given to me: my tasks and the event teams I'm on.
class MyTasksScreen extends StatelessWidget {
  const MyTasksScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('My tasks')),
    body: Loader<Map<String, dynamic>>(
      load: () async => Map<String, dynamic>.from(await Api.call('${Api.m}my_tasks') as Map),
      builder: (context, d) {
        final tasks = (d['tasks'] as List?) ?? [];
        final teams = (d['teams'] as List?) ?? [];
        final open = tasks.where((t) => t['status'] != 'Done').toList();
        final done = tasks.where((t) => t['status'] == 'Done').toList();
        return [
          if (teams.isNotEmpty) ...[
            const SectionTitle('My event teams'),
            PanelList(
              children: [
                for (final t in teams)
                  ListTile(
                    leading: const Icon(Icons.groups_2_outlined, color: SioColors.blue),
                    title: Text('${t['event_title']}'),
                    subtitle: Text(
                      [t['responsibility'], fmtDate(t['event_starts'], 'EEE d MMM')].where((x) => x != null).join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => push(context, EventDetailScreen(name: '${t['event']}', title: '${t['event_title']}')),
                  ),
              ],
            ),
          ],
          SectionTitle(open.isEmpty ? 'To do' : 'To do · ${open.length}'),
          if (open.isEmpty)
            const EmptyNote('Nothing to do right now.')
          else
            PanelList(
              children: [
                for (final t in open)
                  TaskTile(
                    t: Map<String, dynamic>.from(t),
                    showEvent: true,
                    onTap: () => showTaskSheet(context, Map<String, dynamic>.from(t), boss: false),
                  ),
              ],
            ),
          if (done.isNotEmpty) ...[
            const SectionTitle('Done recently'),
            PanelList(
              children: [
                for (final t in done)
                  TaskTile(
                    t: Map<String, dynamic>.from(t),
                    showEvent: true,
                    onTap: () => showTaskSheet(context, Map<String, dynamic>.from(t), boss: false),
                  ),
              ],
            ),
          ],
        ];
      },
    ),
  );
}
