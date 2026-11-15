import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// All units with their president, secretary and members. District admins add and change units here.
class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AppState.i.can('manage_units');
    return Scaffold(
      appBar: AppBar(title: const Text('Units'), actions: [
        if (admin)
          IconButton(tooltip: 'New unit', icon: const Icon(Icons.add), onPressed: () => push(context, const UnitFormScreen())),
      ]),
      body: Loader<List<dynamic>>(
        load: () async => (await Api.call('${Api.m}manage_units') as List?) ?? [],
        builder: (context, list) => [
          if (list.isEmpty) const EmptyNote('No units yet.'),
          if (list.isNotEmpty)
            PanelList(children: [
              for (final u in list)
                ListTile(
                  onTap: admin ? () => push(context, UnitFormScreen(unit: Map<String, dynamic>.from(u))) : null,
                  leading: CircleAvatar(
                    backgroundColor: SioColors.cardHigh,
                    foregroundColor: SioColors.blue,
                    child: Text('${numOf(u['members']).toInt()}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  ),
                  title: Text(u['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(
                    [
                      u['district'],
                      if (u['president_name'] != null) 'President: ${u['president_name']}',
                      '${numOf(u['members']).toInt()} members',
                      if (numOf(u['pending']) > 0) '${numOf(u['pending']).toInt()} waiting',
                    ].where((x) => x != null && '$x'.isNotEmpty).join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: u['active'] == 1 ? (admin ? const Icon(Icons.chevron_right) : null) : const StatusChip('Inactive'),
                ),
            ]),
        ],
      ),
    );
  }
}

class UnitFormScreen extends StatefulWidget {
  const UnitFormScreen({super.key, this.unit});
  final Map<String, dynamic>? unit;

  @override
  State<UnitFormScreen> createState() => _UnitFormScreenState();
}

class _UnitFormScreenState extends State<UnitFormScreen> {
  final _name = TextEditingController();
  final _district = TextEditingController();
  final _area = TextEditingController();
  bool _active = true;
  String? _president;
  String? _secretary;
  List<(String, String)> _members = [];
  bool _busy = false;

  Map<String, dynamic>? get _u => widget.unit;

  @override
  void initState() {
    super.initState();
    final u = _u;
    if (u != null) {
      _name.text = u['name'].toString();
      _district.text = '${u['district'] ?? ''}';
      _area.text = '${u['area'] ?? ''}';
      _active = u['active'] == 1;
      _president = u['president']?.toString();
      _secretary = u['secretary']?.toString();
      Api.call('${Api.m}members', {'status': 'Active'}).then((v) {
        final list = [for (final m in (v as List? ?? [])) if (m['unit'] == u['name']) (m['name'].toString(), m['full_name'].toString())];
        if (mounted) setState(() => _members = list);
      }).catchError((_) {});
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      await Api.call('${Api.m}save_unit', {
        'name': _u?['name'],
        'unit_name': _name.text.trim(),
        'district': _district.text.trim(),
        'area': _area.text.trim(),
        'active': _active ? 1 : 0,
        'president': _president,
        'secretary': _secretary,
      });
    }, done: _u == null ? 'Unit added.' : 'Unit saved.');
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.pop(context);
  }

  Widget _picker(String label, String? value, void Function(String?) set) => DropdownButtonFormField<String?>(
        initialValue: _members.any((m) => m.$1 == value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          const DropdownMenuItem<String?>(value: null, child: Text('—')),
          for (final m in _members) DropdownMenuItem<String?>(value: m.$1, child: Text(m.$2, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: (v) => setState(() => set(v)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_u == null ? 'New unit' : 'Edit unit')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        TextField(
          controller: _name,
          enabled: _u == null,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Unit name', hintText: 'e.g. Feroke'),
        ),
        const SizedBox(height: 14),
        TextField(controller: _district, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'District')),
        const SizedBox(height: 14),
        TextField(controller: _area, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Area / campus zone (optional)')),
        if (_u != null) ...[
          const SectionTitle('Office bearers'),
          if (_members.isEmpty)
            const Text('Add members to this unit first, then pick its president and secretary.',
                style: TextStyle(color: SioColors.textSecondary))
          else ...[
            _picker('President', _president, (v) => _president = v),
            const SizedBox(height: 14),
            _picker('Secretary', _secretary, (v) => _secretary = v),
          ],
          const SizedBox(height: 6),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            subtitle: const Text('Inactive units are hidden from sign-up and pickers'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        ],
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_u == null ? 'Add unit' : 'Save')),
      ]),
    );
  }
}
