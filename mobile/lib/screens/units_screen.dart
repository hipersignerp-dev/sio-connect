import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

/// Areas, and the units under each. Area admins add and change areas and units here.
class UnitsScreen extends StatelessWidget {
  const UnitsScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final pick = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheet) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
            leading: const Icon(Icons.map_outlined),
            title: const Text('New area'),
            subtitle: const Text('A group of units'),
            onTap: () => Navigator.pop(sheet, 'area'),
          ),
          ListTile(
            leading: const Icon(Icons.apartment_outlined),
            title: const Text('New unit'),
            subtitle: const Text('Inside an area'),
            onTap: () => Navigator.pop(sheet, 'unit'),
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
    if (!context.mounted || pick == null) return;
    push(context, pick == 'area' ? const AreaFormScreen() : const UnitFormScreen());
  }

  @override
  Widget build(BuildContext context) {
    final admin = AppState.i.can('manage_units');
    return Scaffold(
      appBar: AppBar(title: const Text('Areas & units')),
      floatingActionButton: admin ? AddFab(tooltip: 'New area or unit', onPressed: () => _add(context)) : null,
      body: Loader<Map<String, dynamic>>(
        load: () async {
          final d = Map<String, dynamic>.from(await Api.call('${Api.m}manage_areas') as Map);
          final units = (await Api.call('${Api.m}manage_units') as List?) ?? [];
          d['unit_rows'] = {for (final u in units) u['name'].toString(): Map<String, dynamic>.from(u)};
          return d;
        },
        builder: (context, d) {
          final areas = (d['areas'] as List?) ?? [];
          final noArea = (d['no_area'] as List?) ?? [];
          final rows = d['unit_rows'] as Map<String, Map<String, dynamic>>;
          Widget unitTile(dynamic u) {
            final r = rows[u['name'].toString()] ?? Map<String, dynamic>.from(u);
            return ListTile(
              onTap: admin ? () => push(context, UnitFormScreen(unit: r)) : null,
              leading: CircleAvatar(
                backgroundColor: SioColors.cardHigh,
                foregroundColor: SioColors.blue,
                child: Text('${numOf(r['members']).toInt()}', style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
              title: Text(r['name'].toString(), style: const TextStyle(fontWeight: FontWeight.w600)),
              subtitle: Text(
                [
                  if (r['president_name'] != null) 'President: ${r['president_name']}',
                  if (r['approver_name'] != null) 'Approver: ${r['approver_name']}',
                  '${numOf(r['members']).toInt()} members',
                  if (numOf(r['pending']) > 0) '${numOf(r['pending']).toInt()} waiting',
                ].join(' · '),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: r['active'] == 1 ? (admin ? const Icon(Icons.chevron_right) : null) : const StatusChip('Inactive'),
            );
          }

          return [
            if (areas.isEmpty && noArea.isEmpty) const EmptyNote('No areas or units yet.'),
            for (final a in areas) ...[
              SectionTitle(
                '${a['name']}',
                action: admin
                    ? TextButton.icon(
                        onPressed: () => push(context, AreaFormScreen(area: Map<String, dynamic>.from(a))),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Edit'),
                      )
                    : null,
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  [
                    '${a['unit_count']} units',
                    '${numOf(a['members']).toInt()} members',
                    if (a['president_name'] != null) 'President: ${a['president_name']}',
                    if (a['secretary_name'] != null) 'Secretary: ${a['secretary_name']}',
                    if (a['active'] != 1) 'inactive',
                  ].join(' · '),
                  style: const TextStyle(color: SioColors.textSecondary, fontSize: 13),
                ),
              ),
              if ((a['units'] as List).isEmpty)
                EmptyNote(admin ? 'No units yet. Tap Edit to pick units for this area.' : 'No units yet.')
              else
                PanelList(children: [for (final u in a['units']) unitTile(u)]),
            ],
            if (noArea.isNotEmpty) ...[
              const SectionTitle('Units without an area'),
              PanelList(children: [for (final u in noArea) unitTile(u)]),
            ],
          ];
        },
      ),
    );
  }
}

/// Add or change an area, its office bearers and which units are under it.
class AreaFormScreen extends StatefulWidget {
  const AreaFormScreen({super.key, this.area});
  final Map<String, dynamic>? area;

  @override
  State<AreaFormScreen> createState() => _AreaFormScreenState();
}

class _AreaFormScreenState extends State<AreaFormScreen> {
  final _name = TextEditingController();
  final _district = TextEditingController();
  bool _active = true;
  String? _president;
  String? _secretary;
  final Set<String> _units = {};
  List<(String, String?)> _allUnits = [];
  List<(String, String)> _members = [];
  bool _busy = false;

  Map<String, dynamic>? get _a => widget.area;

  @override
  void initState() {
    super.initState();
    final a = _a;
    if (a != null) {
      _name.text = '${a['name']}';
      _district.text = '${a['district'] ?? ''}';
      _active = a['active'] == 1;
      _president = a['president']?.toString();
      _secretary = a['secretary']?.toString();
      for (final u in (a['units'] as List? ?? [])) {
        _units.add(u['name'].toString());
      }
    }
    Api.call('${Api.m}manage_units').then((v) {
      final list = [for (final u in (v as List? ?? [])) if (u['active'] == 1) (u['name'].toString(), u['district']?.toString())];
      if (mounted) setState(() => _allUnits = list);
    }).catchError((_) {});
    Api.call('${Api.m}members', {'status': 'Active'}).then((v) {
      final list = [for (final m in (v as List? ?? [])) (m['name'].toString(), '${m['full_name']} · ${m['unit'] ?? ''}')];
      if (mounted) setState(() => _members = list);
    }).catchError((_) {});
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      var name = _a?['name']?.toString();
      final newName = _name.text.trim();
      if (name != null && newName.isNotEmpty && newName != name) {
        await Api.call('frappe.client.rename_doc', {'doctype': 'SIO Area', 'old_name': name, 'new_name': newName});
        name = newName;
      }
      await Api.call('${Api.m}save_area', {
        'name': name,
        'area_name': _name.text.trim(),
        'district': _district.text.trim(),
        'active': _active ? 1 : 0,
        'president': _president,
        'secretary': _secretary,
        'units': jsonEncode(_units.toList()),
      });
    }, done: _a == null ? 'Area added.' : 'Area saved.');
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
      appBar: AppBar(title: Text(_a == null ? 'New area' : 'Edit area')),
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 32), children: [
        TextField(
          controller: _name,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Area name',
            helperText: _a == null ? null : 'Changing the name updates it everywhere',
          ),
        ),
        const SizedBox(height: 14),
        TextField(controller: _district, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'District (optional)')),
        const SectionTitle('Office bearers'),
        _picker('Area president', _president, (v) => _president = v),
        const SizedBox(height: 14),
        _picker('Area secretary', _secretary, (v) => _secretary = v),
        const SectionTitle('Units in this area'),
        if (_allUnits.isEmpty) const Text('No units yet.', style: TextStyle(color: SioColors.textSecondary)),
        SioPanel(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(children: [
            for (final u in _allUnits)
              CheckboxListTile(
                value: _units.contains(u.$1),
                title: Text(u.$1),
                subtitle: u.$2 != null && u.$2 != _a?['name'] ? Text('now in ${u.$2}') : null,
                onChanged: (v) => setState(() => v == true ? _units.add(u.$1) : _units.remove(u.$1)),
              ),
          ]),
        ),
        if (_a != null)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
        const SizedBox(height: 20),
        FilledButton(onPressed: _busy ? null : _save, child: Text(_a == null ? 'Add area' : 'Save')),
      ]),
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
  String? _areaName;
  List<String> _areas = [];
  final _area = TextEditingController();
  bool _active = true;
  String? _president;
  String? _secretary;
  String? _approver;
  List<(String, String)> _members = [];
  bool _busy = false;

  Map<String, dynamic>? get _u => widget.unit;

  @override
  void initState() {
    super.initState();
    Api.call('${Api.m}manage_areas').then((v) {
      final list = [for (final a in ((v as Map?)?['areas'] as List? ?? [])) if (a['active'] == 1) a['name'].toString()];
      if (mounted) setState(() => _areas = list);
    }).catchError((_) {});
    final u = _u;
    if (u != null) {
      _name.text = u['name'].toString();
      _areaName = u['district']?.toString();
      _area.text = '${u['area'] ?? ''}';
      _active = u['active'] == 1;
      _president = u['president']?.toString();
      _secretary = u['secretary']?.toString();
      _approver = u['expense_approver']?.toString();
      Api.call('${Api.m}members', {'status': 'Active'}).then((v) {
        final list = [for (final m in (v as List? ?? [])) if (m['unit'] == u['name']) (m['name'].toString(), m['full_name'].toString())];
        if (mounted) setState(() => _members = list);
      }).catchError((_) {});
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      var name = _u?['name']?.toString();
      final newName = _name.text.trim();
      if (name != null && newName.isNotEmpty && newName != name) {
        await Api.call('frappe.client.rename_doc', {'doctype': 'SIO Unit', 'old_name': name, 'new_name': newName});
        name = newName;
      }
      await Api.call('${Api.m}save_unit', {
        'name': name,
        'unit_name': _name.text.trim(),
        'district': _areaName,
        'area': _area.text.trim(),
        'active': _active ? 1 : 0,
        'president': _president,
        'secretary': _secretary,
        'expense_approver': _approver,
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
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(
            labelText: 'Unit name',
            hintText: 'e.g. Mannur',
            helperText: _u == null ? null : 'Changing the name updates it everywhere (members, entries, targets)',
          ),
        ),
        const SizedBox(height: 14),
        DropdownButtonFormField<String?>(
          initialValue: _areas.contains(_areaName) ? _areaName : null,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Area'),
          items: [
            const DropdownMenuItem<String?>(value: null, child: Text('No area yet')),
            for (final a in _areas) DropdownMenuItem<String?>(value: a, child: Text(a)),
          ],
          onChanged: (v) => setState(() => _areaName = v),
        ),
        const SizedBox(height: 14),
        TextField(controller: _area, textCapitalization: TextCapitalization.words, decoration: const InputDecoration(labelText: 'Campus / zone (optional)')),
        if (_u != null) ...[
          const SectionTitle('Office bearers'),
          if (_members.isEmpty)
            const Text('Add members to this unit first, then pick its president and secretary.',
                style: TextStyle(color: SioColors.textSecondary))
          else ...[
            _picker('President', _president, (v) => _president = v),
            const SizedBox(height: 14),
            _picker('Secretary', _secretary, (v) => _secretary = v),
            const SizedBox(height: 14),
            _picker('Expense approver', _approver, (v) => _approver = v),
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text('Approves and pays this unit\'s expense claims. Finance and area admins can too.',
                  style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5)),
            ),
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
