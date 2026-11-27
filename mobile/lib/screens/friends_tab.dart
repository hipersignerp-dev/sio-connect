import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../noor.dart';
import '../theme.dart';
import '../widgets.dart';
import 'journey_screens.dart' show ReadingBoardScreen;
import 'me_screen.dart';

// The Friends tab: everyone's sprout today (watered, thirsty or dried up), a 👋 nudge for the thirsty ones,
// friend requests, finding people, inviting, and the reading leaderboard.

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _l(dynamic v) => [for (final x in (v as List? ?? [])) _m(x)];
int _i(dynamic v) => numOf(v).toInt();

class FriendsTab extends StatelessWidget {
  const FriendsTab({super.key});

  @override
  Widget build(BuildContext context) => DefaultTabController(
    length: 2,
    child: Scaffold(
      appBar: AppBar(
        title: const Text('Friends', style: TextStyle(fontWeight: FontWeight.w800)),
        actions: [
          IconButton(tooltip: 'Invite friends', icon: const Icon(Icons.person_add_alt_1_outlined), onPressed: () => _invite()),
        ],
        bottom: const TabBar(
          tabs: [
            Tab(text: 'Friends'),
            Tab(text: 'Leaderboard'),
          ],
        ),
      ),
      body: const TabBarView(children: [_FriendsList(), ReadingBoardScreen(embedded: true)]),
    ),
  );
}

Future<void> _invite() async {
  final u = '${AppState.i.me['username'] ?? ''}';
  final link = '${Api.baseUrl}/go${u.isEmpty ? '' : '?i=$u'}';
  await SharePlus.instance.share(
    ShareParams(
      text:
          'Grow a little sprout with me on SIO Connect 🌱 One ayah a day keeps it alive. Let’s keep our streaks '
          'together! $link',
    ),
  );
}

class _FriendsList extends StatefulWidget {
  const _FriendsList();

  @override
  State<_FriendsList> createState() => _FriendsListState();
}

class _FriendsListState extends State<_FriendsList> {
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _found;
  int _seq = 0;

  Future<void> _find(String q) async {
    final mine = ++_seq;
    setState(() {});
    if (q.trim().length < 2) {
      setState(() => _found = null);
      return;
    }
    try {
      final r = _l(await Api.call('${Api.m}find_people', {'q': q.trim()}));
      if (mounted && mine == _seq) setState(() => _found = r);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Loader<Map<String, dynamic>>(
    cacheKey: 'friends',
    load: () async => _m(await Api.call('${Api.m}friends')),
    builder: (context, f) {
      final incoming = _l(f['incoming']);
      final friends = _l(f['friends']);
      final watered = friends.where((p) => _m(p['reading'])['today'] == true).length;
      return [
        TextField(
          controller: _search,
          onChanged: _find,
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search),
            hintText: 'Find friends by name or @username',
            suffixIcon: _search.text.isEmpty
                ? null
                : IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _search.clear();
                      _find('');
                    },
                  ),
          ),
        ),
        if (_found != null) ...[
          const SectionTitle('People'),
          if (_found!.isEmpty) const EmptyNote('No one found.'),
          for (final p in _found!)
            _Row(
              p: p,
              trailing: FriendAction(member: '${p['member']}', state: '${p['friend']}', compact: true),
            ),
        ],
        if (incoming.isNotEmpty) ...[
          const SectionTitle('Friend requests'),
          for (final p in incoming)
            _Row(
              p: p,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Decline',
                    icon: Icon(Icons.close, color: SioColors.danger),
                    onPressed: () async {
                      await run(context, () => Api.call('${Api.m}friend_request', {'request': p['request'], 'accept': 0}));
                      AppState.i.refreshAll();
                    },
                  ),
                  IconButton.filled(
                    tooltip: 'Accept',
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      await run(
                        context,
                        () => Api.call('${Api.m}friend_request', {'request': p['request'], 'accept': 1}),
                        done: 'You are now friends',
                      );
                      AppState.i.refreshAll();
                    },
                  ),
                ],
              ),
            ),
        ],
        if (friends.isEmpty && _found == null) ...[
          const SizedBox(height: 24),
          const Center(child: Noor(mood: NoorMood.waiting, size: 120, stage: 1)),
          const SizedBox(height: 8),
          Text(
            'Sprouts grow better together',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: SioColors.ink),
          ),
          const SizedBox(height: 4),
          Text(
            'Add friends and you’ll see each other’s sprout every day. Nudge them when theirs is thirsty.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SioColors.textSecondary, height: 1.4),
          ),
          const SizedBox(height: 14),
          Center(
            child: FilledButton.icon(
              onPressed: _invite,
              icon: const Icon(Icons.send_outlined),
              label: const Text('Invite friends'),
            ),
          ),
        ],
        if (friends.isNotEmpty) ...[
          SectionTitle('Today: $watered of ${friends.length} watered their sprout'),
          for (final p in friends) _FriendSprout(p: p),
        ],
      ];
    },
  );
}

class _Row extends StatelessWidget {
  const _Row({required this.p, this.trailing});
  final Map<String, dynamic> p;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Avatar('${p['full_name'] ?? ''}', photo: p['photo'], light: true),
    title: Text('${p['full_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
    subtitle: Text('${p['unit'] ?? ''}', style: TextStyle(color: SioColors.textSecondary)),
    trailing: trailing,
    onTap: () => push(context, PersonView(member: '${p['member']}')),
  );
}

/// A friend and their sprout today.
class _FriendSprout extends StatelessWidget {
  const _FriendSprout({required this.p});
  final Map<String, dynamic> p;

  @override
  Widget build(BuildContext context) {
    final r = _m(p['reading']);
    final cur = _i(r['current']);
    final today = r['today'] == true;
    final mood = moodOf(r);
    final together = _i(_m(p['together'])['current']);
    final first = '${p['full_name'] ?? ''}'.split(' ').first;
    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => push(context, PersonView(member: '${p['member']}')),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        decoration: BoxDecoration(
          color: today ? const Color(0xFFE6F2FD) : SioColors.card,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          children: [
            Noor(mood: mood, size: 64, stage: sproutStage(cur), animate: false),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${p['full_name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, color: today ? const Color(0xFF0E3F70) : SioColors.ink),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    today
                        ? '💧 Watered today · 🔥 $cur'
                        : cur == 0
                        ? '🥀 $first’s sprout dried up'
                        : '🥺 Thirsty · 🔥 $cur',
                    style: TextStyle(
                      color: today ? const Color(0xFF2F7BC4) : SioColors.textSecondary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (together > 1)
                    Text(
                      '🤝 $together days together',
                      style: TextStyle(color: today ? const Color(0xFF2F7BC4) : SioColors.textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
            if (!today) NudgeButton(member: '${p['member']}'),
          ],
        ),
      ),
    );
  }
}
