import 'package:url_launcher/url_launcher.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../location.dart';
import '../photo.dart';
import '../widgets.dart';
import 'manage_screens.dart';

/// Members of the unit (or all units for area admins). New associates waiting for approval come first.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _q = TextEditingController();
  String _status = 'All';
  String? _unit;
  String? _area;
  String? _role;
  int _version = 0;

  void _set(VoidCallback f) => setState(() {
    f();
    _version++;
  });

  /// A filter chip that opens a list of choices with how many people each has.
  Widget _filter(String label, String? value, List<Map<String, dynamic>> options, void Function(String?) pick) {
    final on = value != null;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: PopupMenuButton<String>(
        tooltip: label,
        onSelected: (v) => _set(() => pick(v == '__all__' ? null : v)),
        itemBuilder: (_) => [
          PopupMenuItem(value: '__all__', child: Text('All ${label.toLowerCase()}s')),
          for (final o in options)
            PopupMenuItem(
              value: '${o['value']}',
              child: Row(
                children: [
                  Expanded(child: Text('${o['value']}')),
                  const SizedBox(width: 16),
                  Text('${o['count']}', style: const TextStyle(color: SioColors.textSecondary)),
                ],
              ),
            ),
        ],
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: on ? SioColors.blue : SioColors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: on ? SioColors.blue : SioColors.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                value ?? label,
                style: TextStyle(color: on ? Colors.white : SioColors.ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, size: 20, color: on ? Colors.white : SioColors.ink),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students & members')),
      floatingActionButton: AppState.i.can('add_members')
          ? AddFab(
              tooltip: 'Add student',
              onPressed: () async {
                final ok = await push(context, const MemberFormScreen());
                if (ok == true) setState(() => _version++);
              },
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _q,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => setState(() => _version++),
              decoration: InputDecoration(
                hintText: 'Search name, mobile or ID',
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
                for (final s in const ['All', 'Pending Approval', 'Active', 'Inactive'])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(s == 'Pending Approval' ? 'Waiting approval' : s),
                      selected: _status == s,
                      onSelected: (_) => setState(() {
                        _status = s;
                        _version++;
                      }),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: Loader<Map<String, dynamic>>(
              key: ValueKey('$_version'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 96),
              load: () async => Map<String, dynamic>.from(
                await Api.call('${Api.m}members', {
                  'q': _q.text.trim(),
                  'status': _status == 'All' ? null : _status,
                  'unit': _unit,
                  'area': _area,
                  'role': _role,
                  'with_facets': 1,
                }) as Map,
              ),
              builder: (context, data) {
                final list = (data['people'] as List?) ?? [];
                List<Map<String, dynamic>> opts(String k) => [
                  for (final x in (data[k] as List? ?? [])) Map<String, dynamic>.from(x as Map),
                ];
                final areas = opts('areas');
                final filtered = _unit != null || _area != null || _role != null || _q.text.trim().isNotEmpty;
                return [
                  SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: [
                        if (areas.length > 1 || _area != null) _filter('Area', _area, areas, (v) => _area = v),
                        _filter('Unit', _unit, opts('units'), (v) => _unit = v),
                        _filter('Role', _role, opts('roles'), (v) => _role = v),
                        if (filtered)
                          TextButton.icon(
                            onPressed: () => _set(() {
                              _unit = null;
                              _area = null;
                              _role = null;
                              _q.clear();
                            }),
                            icon: const Icon(Icons.close, size: 18),
                            label: const Text('Clear'),
                          ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
                    child: Row(
                      children: [
                        Text(
                          '${data['total']} ${data['total'] == 1 ? 'person' : 'people'}',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: SioColors.ink),
                        ),
                        if (filtered) ...[
                          const SizedBox(width: 6),
                          Text('of ${data['all']}', style: const TextStyle(color: SioColors.textSecondary)),
                        ],
                      ],
                    ),
                  ),
                  if (list.isEmpty) const EmptyNote('No one found.'),
                  if (list.isNotEmpty)
                    PanelList(
                      children: [
                        for (final m in list)
                          ListTile(
                            onTap: () => _open(context, Map<String, dynamic>.from(m)),
                            leading: Avatar(m['full_name'].toString(), photo: m['photo']),
                            title: Text(m['full_name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                            subtitle: Text(
                              [m['unit'], m['campus']].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                m['status'] == 'Active'
                                    ? StatusChip(
                                        m['member_role'].toString(),
                                        tone: m['member_role'] == 'Associate' ? Tone.grey : Tone.blue,
                                      )
                                    : StatusChip(
                                        m['status'] == 'Pending Approval' ? 'Approve' : m['status'].toString(),
                                        tone: StatusChip.toneFor(m['status'].toString()),
                                      ),
                                if ('${m['mobile'] ?? ''}'.isNotEmpty)
                                  IconButton(
                                    tooltip: 'Call ${m['full_name']}',
                                    icon: const Icon(Icons.call, color: SioColors.green),
                                    onPressed: () => launchUrl(Uri.parse('tel:${m['mobile']}')),
                                  )
                                else
                                  const SizedBox(width: 48),
                              ],
                            ),
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

  Future<void> _open(BuildContext context, Map<String, dynamic> m) async {
    final roles = <String>{...AppState.i.givableRoles, '${m['member_role'] ?? 'Associate'}'}.toList();
    var role = roles.contains(m['member_role']) ? m['member_role'].toString() : 'Associate';
    final onPath = m['status'] == 'Active' && (m['member_role'] == 'Worker' || m['member_role'] == 'Associate');
    final books = '${m['books_read'] ?? ''}'.split('\n').where((b) => b.trim().isNotEmpty).toList();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    if (AppState.i.can('add_members'))
                      PhotoPicker(
                        name: m['full_name'].toString(),
                        photo: m['photo']?.toString(),
                        memberId: m['name'].toString(),
                        radius: 30,
                        onChanged: (u) {
                          m['photo'] = u;
                          setState(() => _version++);
                        },
                      )
                    else
                      Avatar(m['full_name'].toString(), radius: 26, photo: m['photo']),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(m['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                          Text('${m['name']} · ${m['status']}', style: const TextStyle(color: SioColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                for (final line in [
                  ['Mobile', m['mobile']],
                  ['Email', m['email']],
                  ['Unit', m['unit']],
                  ['Campus', m['campus']],
                  [
                    'Course',
                    [m['course'], m['year_of_study']].where((x) => x != null && '$x'.isNotEmpty).join(', '),
                  ],
                  ['Joined', fmtDate(m['joined_on'])],
                  ['House', m['location_note']],
                ])
                  if (line[1] != null && '${line[1]}'.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(line[0].toString(), style: const TextStyle(color: SioColors.textSecondary)),
                          ),
                          Expanded(child: Text(line[1].toString())),
                        ],
                      ),
                    ),
                if (onPath) ...[
                  const SizedBox(height: 12),
                  SioPanel(
                    color: SioColors.cardHigh,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'Path to membership',
                          style: TextStyle(fontWeight: FontWeight.w700, color: SioColors.ink),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              m['mulakath_done'] == 1 ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 20,
                              color: m['mulakath_done'] == 1 ? SioColors.green : SioColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                m['mulakath_done'] == 1 ? 'Mulakath done ${fmtDate(m['mulakath_on'])}' : 'Mulakath not done yet',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              books.isNotEmpty ? Icons.menu_book : Icons.menu_book_outlined,
                              size: 20,
                              color: books.isNotEmpty ? SioColors.green : SioColors.textSecondary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(books.isEmpty ? 'No books recorded yet' : '${books.length} books: ${books.join(', ')}'),
                            ),
                          ],
                        ),
                        if ('${m['membership_note'] ?? ''}'.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          Text('${m['membership_note']}', style: const TextStyle(color: SioColors.textSecondary, fontSize: 13)),
                        ],
                        if (!AppState.i.givableRoles.contains('Member') && m['member_role'] == 'Worker')
                          const Padding(
                            padding: EdgeInsets.only(top: 8),
                            child: Text(
                              'When it is complete, the area leaders make them an official Member.',
                              style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: [for (final r in roles) DropdownMenuItem(value: r, child: Text(r))],
                  onChanged: (v) => setSheet(() => role = v ?? role),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: SioColors.green),
                  onPressed: () async {
                    final ok = await run(
                      sheet,
                      () => Api.call('${Api.m}approve_member', {'name': m['name'], 'action': 'approve', 'member_role': role}),
                      done: m['status'] == 'Pending Approval' ? '${m['full_name']} approved as $role.' : 'Saved.',
                    );
                    if (ok && sheet.mounted) Navigator.pop(sheet);
                    if (ok) setState(() => _version++);
                  },
                  child: Text(m['status'] == 'Pending Approval' ? 'Approve' : 'Save role'),
                ),
                if (GeoPoint.from(m['latitude'], m['longitude']) != null) ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => openInMaps(context, GeoPoint.from(m['latitude'], m['longitude'])!),
                    icon: const Icon(Icons.directions),
                    label: const Text('Directions to their house'),
                  ),
                ],
                if (AppState.i.can('add_members') && m['status'] != 'Pending Approval') ...[
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.pop(sheet);
                      final ok = await push(context, MemberFormScreen(member: m));
                      if (ok == true) setState(() => _version++);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit details'),
                  ),
                ],
                if (m['status'] == 'Pending Approval') ...[
                  const SizedBox(height: 8),
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(foregroundColor: SioColors.danger),
                    onPressed: () async {
                      final ok = await run(
                        sheet,
                        () => Api.call('${Api.m}approve_member', {'name': m['name'], 'action': 'reject'}),
                        done: 'Registration rejected.',
                      );
                      if (ok && sheet.mounted) Navigator.pop(sheet);
                      if (ok) setState(() => _version++);
                    },
                    child: const Text('Reject'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
