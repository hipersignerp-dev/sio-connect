import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Members of the unit (or all units for district admins). New associates waiting for approval come first.
class MembersScreen extends StatefulWidget {
  const MembersScreen({super.key});

  @override
  State<MembersScreen> createState() => _MembersScreenState();
}

class _MembersScreenState extends State<MembersScreen> {
  final _q = TextEditingController();
  String _status = 'All';
  int _version = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students & members')),
      body: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: TextField(
            controller: _q,
            textInputAction: TextInputAction.search,
            onSubmitted: (_) => setState(() => _version++),
            decoration: InputDecoration(
              hintText: 'Search name, mobile or ID',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: IconButton(tooltip: 'Search', icon: const Icon(Icons.arrow_forward), onPressed: () => setState(() => _version++)),
            ),
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView(scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 16), children: [
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
          ]),
        ),
        Expanded(
          child: Loader<List<dynamic>>(
            key: ValueKey('$_version'),
            load: () async =>
                (await Api.call('${Api.m}members', {'q': _q.text.trim(), 'status': _status == 'All' ? null : _status}) as List?) ?? [],
            builder: (context, list) => [
              if (list.isEmpty) const EmptyNote('No one found.'),
              if (list.isNotEmpty)
                PanelList(children: [
                  for (final m in list)
                    ListTile(
                      onTap: () => _open(context, Map<String, dynamic>.from(m)),
                      leading: Avatar(m['full_name'].toString()),
                      title: Text(m['full_name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text([m['campus'], m['unit']].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: m['status'] == 'Active'
                          ? StatusChip(m['member_role'].toString(), tone: m['member_role'] == 'Associate' ? Tone.grey : Tone.blue)
                          : StatusChip(m['status'] == 'Pending Approval' ? 'Approve' : m['status'].toString(),
                              tone: StatusChip.toneFor(m['status'].toString())),
                    ),
                ]),
            ],
          ),
        ),
      ]),
    );
  }

  Future<void> _open(BuildContext context, Map<String, dynamic> m) async {
    final admin = AppState.i.role == 'District Admin';
    final roles = admin ? const ['Associate', 'Member', 'Unit Secretary', 'Unit President', 'Finance', 'District Admin'] : const ['Associate', 'Member'];
    var role = roles.contains(m['member_role']) ? m['member_role'].toString() : 'Associate';
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => StatefulBuilder(
        builder: (sheet, setSheet) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Avatar(m['full_name'].toString(), radius: 26),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m['full_name'].toString(), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('${m['name']} · ${m['status']}', style: const TextStyle(color: SioColors.textSecondary)),
                  ]),
                ),
              ]),
              const SizedBox(height: 16),
              for (final line in [
                ['Mobile', m['mobile']],
                ['Email', m['email']],
                ['Unit', m['unit']],
                ['Campus', m['campus']],
                ['Course', [m['course'], m['year_of_study']].where((x) => x != null && '$x'.isNotEmpty).join(', ')],
                ['Joined', fmtDate(m['joined_on'])],
              ])
                if (line[1] != null && '${line[1]}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      SizedBox(width: 80, child: Text(line[0].toString(), style: const TextStyle(color: SioColors.textSecondary))),
                      Expanded(child: Text(line[1].toString())),
                    ]),
                  ),
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
                  final ok = await run(sheet, () => Api.call('${Api.m}approve_member', {'name': m['name'], 'action': 'approve', 'member_role': role}),
                      done: m['status'] == 'Pending Approval' ? '${m['full_name']} approved as $role.' : 'Saved.');
                  if (ok && sheet.mounted) Navigator.pop(sheet);
                  if (ok) setState(() => _version++);
                },
                child: Text(m['status'] == 'Pending Approval' ? 'Approve' : 'Save role'),
              ),
              if (m['status'] == 'Pending Approval') ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(foregroundColor: SioColors.danger),
                  onPressed: () async {
                    final ok = await run(sheet, () => Api.call('${Api.m}approve_member', {'name': m['name'], 'action': 'reject'}), done: 'Registration rejected.');
                    if (ok && sheet.mounted) Navigator.pop(sheet);
                    if (ok) setState(() => _version++);
                  },
                  child: const Text('Reject'),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}
