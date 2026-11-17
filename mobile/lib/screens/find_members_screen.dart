import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../fx.dart';
import '../location.dart';
import '../theme.dart';
import '../widgets.dart';
import 'journey_screens.dart';
import 'social_screens.dart';

/// Find SIO members anywhere: search by name, @username or place; browse by unit, area, college or
/// home town; or see who is near you. Only public details are shown (no phone numbers, distances rounded).
class FindMembersScreen extends StatefulWidget {
  const FindMembersScreen({super.key, this.initial});
  final String? initial;

  @override
  State<FindMembersScreen> createState() => _FindMembersScreenState();
}

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _l(dynamic v) => [for (final x in (v as List? ?? [])) _m(x)];

class _FindMembersScreenState extends State<FindMembersScreen> {
  late final _q = TextEditingController(text: widget.initial ?? '');
  Map<String, dynamic>? _places;
  List<Map<String, dynamic>>? _people;
  String? _title; // what the list shows: "Near you", "Pathiripala"…
  bool _busy = false;
  Timer? _debounce;
  int _seq = 0;
  String _placeKind = 'Unit';
  double _km = 10;
  GeoPoint? _here;

  @override
  void initState() {
    super.initState();
    _loadPlaces();
    if ((widget.initial ?? '').isNotEmpty) _search(widget.initial!);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _loadPlaces() async {
    try {
      final r = _m(await Api.call('${Api.m}find_members'));
      if (mounted) setState(() => _places = r);
    } catch (_) {}
  }

  Future<void> _run(String title, Map<String, dynamic> args) async {
    final mine = ++_seq;
    setState(() {
      _busy = true;
      _title = title;
    });
    try {
      final r = _m(await Api.call('${Api.m}find_members', args));
      if (mounted && mine == _seq) setState(() => _people = _l(r['people']));
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted && mine == _seq) setState(() => _busy = false);
    }
  }

  void _search(String v) {
    _debounce?.cancel();
    if (v.trim().length < 2) {
      setState(() {
        _people = null;
        _title = null;
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 350), () => _run('Results for “${v.trim()}”', {'q': v.trim()}));
  }

  Future<void> _nearMe() async {
    HapticFeedback.selectionClick();
    final g = _here ?? await currentLocation(context);
    if (g == null || !mounted) return;
    _here = g;
    _q.clear();
    await _run('Within ${_km.round()} km of you', {'lat': g.lat, 'lng': g.lng, 'km': _km});
  }

  void _place(String kind, String place) {
    HapticFeedback.selectionClick();
    _q.clear();
    _run(place, {'kind': kind, 'place': place});
  }

  void _clear() {
    _q.clear();
    setState(() {
      _people = null;
      _title = null;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      title: const Text('Find SIO members', style: TextStyle(fontWeight: FontWeight.w800)),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        TextField(
          controller: _q,
          autofocus: widget.initial == null,
          textInputAction: TextInputAction.search,
          onChanged: _search,
          decoration: InputDecoration(
            filled: true,
            fillColor: SioColors.card,
            prefixIcon: const Icon(Icons.search),
            hintText: 'Name, @username, unit, college or place',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
            suffixIcon: _q.text.isEmpty && _title == null ? null : IconButton(icon: const Icon(Icons.close), onPressed: _clear),
          ),
        ),
        const SizedBox(height: 12),
        Squish(
          onTap: _nearMe,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(gradient: sioGradient, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const CircleAvatar(backgroundColor: Colors.white24, foregroundColor: Colors.white, child: Icon(Icons.near_me)),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'SIO members near me',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                      ),
                      Text('Wherever you are: college, a new town, travelling', style: TextStyle(color: Colors.white70)),
                    ],
                  ),
                ),
                PopupMenuButton<double>(
                  tooltip: 'Distance',
                  initialValue: _km,
                  onSelected: (v) {
                    setState(() => _km = v);
                    _nearMe();
                  },
                  itemBuilder: (_) => [
                    for (final k in [2.0, 5.0, 10.0, 25.0, 50.0, 100.0]) PopupMenuItem(value: k, child: Text('${k.round()} km')),
                  ],
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: Text(
                      '${_km.round()} km ▾',
                      style: const TextStyle(color: SioColors.blue, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_title != null) ..._results() else ..._browse(),
      ],
    ),
  );

  List<Widget> _results() => [
    Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              _title!,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: SioColors.ink),
            ),
          ),
          if (_people != null && !_busy) Text('${_people!.length} found', style: const TextStyle(color: SioColors.textSecondary)),
        ],
      ),
    ),
    if (_busy && _people == null)
      const Padding(
        padding: EdgeInsets.all(32),
        child: Center(child: CircularProgressIndicator()),
      )
    else if (_people != null && _people!.isEmpty)
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(18)),
        child: Column(
          children: [
            const Text('🔍', style: TextStyle(fontSize: 40)),
            const SizedBox(height: 8),
            Text(
              _title!.startsWith('Within')
                  ? 'No members with a saved location this close. Try a bigger distance.'
                  : 'No SIO members found. Try another name or place.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SioColors.textSecondary),
            ),
          ],
        ),
      )
    else
      for (final (i, p) in (_people ?? <Map<String, dynamic>>[]).indexed)
        Enter(
          index: i,
          child: _MemberCard(p: p),
        ),
  ];

  List<Widget> _browse() {
    final places = _m(_places?['places']);
    final list = _l(places[_placeKind]);
    const icons = {'Unit': Icons.groups, 'Area': Icons.map, 'College': Icons.school, 'Home town': Icons.home};
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 22, 4, 4),
        child: Row(
          children: [
            const Expanded(
              child: Text(
                'Browse by place',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
            ),
            if (_places != null) Text('${_places!['total']} members', style: const TextStyle(color: SioColors.textSecondary)),
          ],
        ),
      ),
      SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            for (final k in icons.keys)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: Icon(icons[k], size: 18, color: _placeKind == k ? Colors.white : SioColors.blue),
                  label: Text(
                    k == 'College'
                        ? 'Colleges'
                        : k == 'Home town'
                        ? 'Home towns'
                        : '${k}s',
                  ),
                  selected: _placeKind == k,
                  showCheckmark: false,
                  selectedColor: SioColors.blue,
                  labelStyle: TextStyle(color: _placeKind == k ? Colors.white : SioColors.ink, fontWeight: FontWeight.w600),
                  onSelected: (_) {
                    HapticFeedback.selectionClick();
                    setState(() => _placeKind = k);
                  },
                ),
              ),
          ],
        ),
      ),
      if (_places == null)
        Shimmer(
          child: Column(
            children: [
              for (var i = 0; i < 4; i++) const Padding(padding: EdgeInsets.only(bottom: 8), child: Bone(height: 56, radius: 14)),
            ],
          ),
        )
      else if (list.isEmpty)
        const EmptyNote('Nothing here yet.')
      else
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 250),
          child: SizedBox(
            key: ValueKey(_placeKind),
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in list)
                  Squish(
                    onTap: () => _place(_placeKind, '${p['place']}'),
                    child: Container(
                      padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
                      decoration: BoxDecoration(
                        color: SioColors.card,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: SioColors.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(icons[_placeKind], size: 18, color: SioColors.blue),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text('${p['place']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(color: SioColors.blue, borderRadius: BorderRadius.circular(10)),
                            child: Text(
                              '${p['members']}',
                              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      const SizedBox(height: 18),
      Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(color: SioColors.warningBg, borderRadius: BorderRadius.circular(14)),
        child: const Text(
          'Others find you by your unit, college and home town. “Near me” shows only people who chose to add a location '
          'in My profile. Phone numbers and exact locations are never shown.',
          style: TextStyle(color: SioColors.text, fontSize: 13),
        ),
      ),
    ];
  }
}

class _MemberCard extends StatefulWidget {
  const _MemberCard({required this.p});
  final Map<String, dynamic> p;

  @override
  State<_MemberCard> createState() => _MemberCardState();
}

class _MemberCardState extends State<_MemberCard> {
  late String _state = '${widget.p['friend'] ?? 'none'}';
  final _key = GlobalKey();

  Future<void> _add() async {
    HapticFeedback.mediumImpact();
    final ctx = _key.currentContext;
    try {
      final r = _m(await Api.call('${Api.m}friend_request', {'member': widget.p['member']}));
      if (ctx != null && ctx.mounted) burst(ctx, emojis: const ['🤝', '✨', '💙'], count: 12, power: 0.6);
      if (mounted) setState(() => _state = '${r['state']}');
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final where = [
      if ('${p['unit'] ?? ''}'.isNotEmpty) 'SIO ${p['unit']}',
      if ('${p['campus'] ?? ''}'.isNotEmpty) '${p['campus']}',
      if ('${p['home_town'] ?? ''}'.isNotEmpty && p['home_town'] != p['unit']) '${p['home_town']}',
    ];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Squish(
        onTap: () => push(context, PersonPage(member: '${p['member']}')),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SioColors.border),
            boxShadow: const [BoxShadow(color: Color(0x0D000000), blurRadius: 10, offset: Offset(0, 3))],
          ),
          child: Row(
            children: [
              Avatar('${p['full_name'] ?? ''}', radius: 28, light: true, photo: p['photo']),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${p['full_name'] ?? ''}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: SioColors.ink),
                    ),
                    Text(
                      [
                        if ('${p['username'] ?? ''}'.isNotEmpty) '@${p['username']}',
                        if (friendlyRole(p['member_role']) != null) friendlyRole(p['member_role'])!,
                      ].join(' · '),
                      style: const TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
                    ),
                    if (where.isNotEmpty)
                      Text(
                        where.join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: SioColors.text, fontSize: 13),
                      ),
                    if (p['distance'] != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: SioColors.greenBg, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                            numOf(p['distance']) < 1 ? '📍 under 1 km away' : '📍 about ${p['distance']} km away',
                            style: const TextStyle(color: SioColors.green, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              KeyedSubtree(
                key: _key,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 220),
                  transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                  child: switch (_state) {
                    'friends' => const Icon(Icons.how_to_reg, color: SioColors.green, key: ValueKey('f')),
                    'sent' => const Text(
                      'Requested',
                      key: ValueKey('s'),
                      style: TextStyle(color: SioColors.textSecondary),
                    ),
                    'received' => FilledButton(key: const ValueKey('r'), onPressed: _add, child: const Text('Accept')),
                    _ => FilledButton(
                      key: const ValueKey('n'),
                      style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 14)),
                      onPressed: _add,
                      child: const Text('Add'),
                    ),
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
