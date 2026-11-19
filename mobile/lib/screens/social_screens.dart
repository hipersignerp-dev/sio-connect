import 'package:intl/intl.dart' hide TextDirection;
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../ayah_audio.dart';
import '../app_state.dart';
import '../fx.dart';
import '../links.dart';
import '../notify.dart';
import '../prayer.dart';
import '../theme.dart';
import '../update_service.dart';
import '../widgets.dart';
import 'album_screens.dart';
import 'board_screens.dart';
import 'card_screens.dart';
import 'event_detail_screen.dart';
import 'find_members_screen.dart';
import 'home_screen.dart';
import 'home_shell.dart';
import 'journey_screens.dart';
import 'meeting_screens.dart';
import 'more_screen.dart';
import 'notice_screens.dart';
import 'public_screens.dart';
import 'task_screens.dart';

// The associates' app: a friendly, Instagram-like app in SIO colours. Home feed with friends' rings,
// today's ayah and programmes; Explore; a + to create; My journey; and a profile page.

const sioGradient = LinearGradient(
  colors: [Color(0xFF1A62A8), Color(0xFF7C3AED), Color(0xFFC8202A)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _l(dynamic v) => [for (final x in (v as List? ?? [])) _m(x)];
int _i(dynamic v) => numOf(v).toInt();

class AssociateShell extends StatefulWidget {
  const AssociateShell({super.key});

  @override
  State<AssociateShell> createState() => _AssociateShellState();
}

class _AssociateShellState extends State<AssociateShell> with WidgetsBindingObserver {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) UpdateService.check(context);
      Links.openPending();
    });
    Notify.start('${AppState.i.me['user'] ?? ''}');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      UpdateService.check(context);
      Notify.check().catchError((_) {});
      AppState.i.refreshAll();
    }
  }

  void _go(int i) {
    if (i != _tab) HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      SocialHome(openTab: _go),
      const ExploreScreen(),
      const JourneyScreen(asTab: true),
      const PersonPage(asTab: true),
    ];
    Widget item(int i, IconData off, IconData on, String label) => Expanded(
      child: Semantics(
        button: true,
        selected: _tab == i,
        label: label,
        child: InkResponse(
          onTap: () => _go(i),
          child: SizedBox(
            height: 56,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Pop(
                  trigger: _tab == i,
                  scale: 1.25,
                  child: Icon(_tab == i ? on : off, size: 25, color: _tab == i ? SioColors.blue : SioColors.ink),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w500,
                    color: _tab == i ? SioColors.blue : SioColors.ink,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    return Scaffold(
      body: IndexedStack(index: _tab, children: pages),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          border: Border(top: BorderSide(color: SioColors.border, width: 0.6)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                item(0, Icons.home_outlined, Icons.home_rounded, 'Home'),
                item(1, Icons.explore_outlined, Icons.explore, 'Explore'),
                Expanded(
                  child: Center(
                    child: Squish(
                      onTap: () => showCreateSheet(context),
                      child: Container(
                        width: 46,
                        height: 34,
                        decoration: BoxDecoration(gradient: sioGradient, borderRadius: BorderRadius.circular(11)),
                        child: const Icon(Icons.add, color: Colors.white, size: 26),
                      ),
                    ),
                  ),
                ),
                item(2, Icons.local_fire_department_outlined, Icons.local_fire_department, 'Journey'),
                Expanded(
                  child: InkResponse(
                    onTap: () => _go(3),
                    child: SizedBox(
                      height: 56,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          ListenableBuilder(
                            listenable: AppState.i,
                            builder: (context, _) => Container(
                              padding: const EdgeInsets.all(1.5),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: _tab == 3 ? SioColors.ink : Colors.transparent, width: 1.6),
                              ),
                              child: Avatar(AppState.i.firstName, radius: 11, light: true, photo: AppState.i.me['photo']),
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Profile',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: _tab == 3 ? FontWeight.w800 : FontWeight.w500,
                              color: _tab == 3 ? SioColors.blue : SioColors.ink,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

Future<void> showCreateSheet(BuildContext context) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  builder: (ctx) {
    Widget row(IconData icon, List<Color> colors, String title, String sub, VoidCallback onTap) => ListTile(
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(icon, color: Colors.white),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(sub),
      onTap: () {
        Navigator.pop(ctx);
        onTap();
      },
    );
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Create', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            row(
              Icons.qr_code_scanner,
              const [Color(0xFF1E8E3E), Color(0xFF1A62A8)],
              'Check in at a programme',
              'Scan the QR the organisers show',
              () => scanToCheckIn(context),
            ),
            row(
              Icons.push_pin,
              const [Color(0xFF1E8E3E), Color(0xFF0E7490)],
              'Post on the student board',
              'Notes, study circle or a blood request',
              () => push(context, const PostBoardScreen(lead: false)),
            ),
            row(
              Icons.workspace_premium,
              const [Color(0xFFE0A100), Color(0xFFF26B1D)],
              'Share an achievement',
              'Send one of your badges to WhatsApp',
              () => push(context, const JourneyScreen()),
            ),

            row(
              Icons.person_add_alt_1,
              const [Color(0xFF7C3AED), Color(0xFF1A62A8)],
              'Invite a friend',
              'Send the app with your invite code',
              () async {
                final j = _m(await Api.call('${Api.m}journey'));
                await SharePlus.instance.share(ShareParams(text: '${j['invite_text']}'));
              },
            ),
          ],
        ),
      ),
    );
  },
);

// ---------------------------------------------------------------- home

class SocialHome extends StatelessWidget {
  const SocialHome({super.key, required this.openTab});
  final void Function(int) openTab;

  Future<Map<String, dynamic>> _load() async {
    final r = await Future.wait([
      Api.call('${Api.m}home'),
      Api.call('${Api.m}journey').catchError((_) => null),
      Api.call('${Api.m}friends').catchError((_) => null),
      Api.call('${Api.m}photo_feed').catchError((_) => []),
      Api.call('${Api.m}suggest_people').catchError((_) => []),
      Api.call('${Api.m}events').catchError((_) => []),
      Api.call('${Api.m}albums').catchError((_) => null),
      Api.call('${Api.m}opportunities').catchError((_) => null),
    ]);
    final h = _m(r[0]);
    AppState.i.me = _m(h['me']);
    return {
      'home': h,
      'journey': r[1],
      'friends': r[2],
      'feed': r[3],
      'suggest': r[4],
      'events': r[5],
      'albums': r[6],
      'board': r[7],
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.white,
    appBar: AppBar(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      titleSpacing: 16,
      title: Row(
        children: [
          Image.asset('assets/sio-logo.png', height: 30),
          const SizedBox(width: 8),
          Flexible(
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: ShaderMask(
                shaderCallback: (r) => sioGradient.createShader(r),
                child: const Text(
                  'SIO Connect',
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.white, letterSpacing: -0.5),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        if (AppState.i.isLeader)
          IconButton(
            tooltip: 'Admin dashboard',
            icon: const Icon(Icons.space_dashboard_outlined, size: 26),
            onPressed: () => openAdminDashboard(context),
          ),
        IconButton(
          tooltip: 'Find SIO members',
          icon: const Icon(Icons.search_rounded, size: 27),
          onPressed: () => push(context, const FindMembersScreen()),
        ),
        IconButton(
          tooltip: 'Updates',
          icon: const Icon(Icons.notifications_none_rounded, size: 27),
          onPressed: () => push(context, const NoticesScreen()),
        ),
        IconButton(
          tooltip: 'Friends',
          icon: const Icon(Icons.people_alt_outlined, size: 26),
          onPressed: () => push(context, const FriendsScreen()),
        ),
        const SizedBox(width: 4),
      ],
    ),
    body: Loader<Map<String, dynamic>>(
      padding: const EdgeInsets.only(bottom: 24),
      skeleton: const _HomeSkeleton(),
      load: _load,
      builder: (context, d) {
        final h = _m(d['home']);
        final j = d['journey'] == null ? null : _m(d['journey']);
        final friends = d['friends'] == null ? <Map<String, dynamic>>[] : _l(_m(d['friends'])['friends']);
        final requests = d['friends'] == null ? <Map<String, dynamic>>[] : _l(_m(d['friends'])['incoming']);
        final feed = _l(d['feed']);
        final suggest = _l(d['suggest']);
        final events = _l(d['events'])
            .where((e) => e['status'] != 'Completed' && (parseDate(e['starts_on'])?.isAfter(DateTime.now()) ?? false))
            .toList();
        final pending = AppState.i.pending;
        if (j != null) checkNewBadges(context, j);
        return [
          if (friends.length >= 3) ...[
            _Stories(me: AppState.i.me, journey: j, friends: friends, openJourney: () => openTab(2)),
            const Divider(height: 1, color: SioColors.border),
          ],
          if (pending)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SioBanner(
                text: 'Your unit will confirm you soon. Meanwhile, read today’s ayah, take the quiz and add friends.',
              ),
            ),
          if (requests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Pill(
                icon: Icons.person_add_alt_1,
                color: SioColors.purple,
                text:
                    '${requests.first['full_name']}${requests.length > 1 ? ' and ${requests.length - 1} more' : ''} '
                    'sent you a friend request',
                onTap: () => push(context, const FriendsScreen()),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
            child: Text(
              'Assalamu Alaikum, ${AppState.i.firstName} 👋',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SioColors.ink),
            ),
          ),
          if (AppState.i.isLeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Enter(child: _AdminCard(home: h)),
            ),
          if (j != null && j['reading'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _AyahHero(journey: j),
            ),
          const Padding(padding: EdgeInsets.fromLTRB(16, 12, 16, 0), child: PrayerCard()),
          if (j != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Pill(
                icon: Icons.emoji_events_outlined,
                color: SioColors.warning,
                text: friends.length < 3
                    ? 'This week’s readers in your unit. Add friends to race them 🏁'
                    : 'Weekly reading race with your friends 🏁',
                onTap: () => push(context, const ReadingBoardScreen()),
              ),
            ),
          if (friends.length < 3)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Pill(
                icon: Icons.group_add_outlined,
                color: SioColors.purple,
                text: 'Find friends from your unit. Reading together keeps the streak going',
                onTap: () => push(context, const FriendsScreen()),
              ),
            ),
          if (h['next_meeting'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MeetingCard(meeting: _m(h['next_meeting'])),
            ),
          if (events.isNotEmpty) ...[
            _Header('Programmes', action: 'See all', onAction: () => openTab(1)),
            SizedBox(
              height: 196,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: events.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => EventTile(e: events[i], width: 260),
              ),
            ),
          ],
          if (j != null && j['quiz'] != null && _m(j['quiz'])['my_score'] == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
              child: _Pill(
                icon: Icons.quiz,
                color: SioColors.purple,
                text: 'This week’s quiz: ${_m(j['quiz'])['title']}. ${_m(j['quiz'])['questions']} questions, tap to play',
                onTap: () => push(context, QuizScreen(name: '${_m(j['quiz'])['name']}')),
              ),
            ),
          if (_l(_m(d['albums'])['albums']).isNotEmpty) ...[
            _Header('Albums', action: 'See all', onAction: () => push(context, const AlbumsScreen())),
            AlbumStrip(albums: _l(_m(d['albums'])['albums']).take(8).toList()),
          ],
          if (_l(_m(d['board'])['items']).isNotEmpty) ...[
            _Header('Student board', action: 'See all', onAction: () => push(context, const BoardScreen())),
            for (final x in _l(_m(d['board'])['items']).take(3))
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Pill(
                  icon: kindLook('${x['kind']}').$1,
                  color: kindLook('${x['kind']}').$2,
                  text: x['kind'] == 'Blood Request'
                      ? '🩸 ${x['blood_group'] ?? ''} needed: ${x['title']}'
                      : '${kindLook('${x['kind']}').$3}: ${x['title']}',
                  onTap: () => push(context, const BoardScreen()),
                ),
              ),
          ],
          if (suggest.isNotEmpty) ...[
            _Header('Suggested for you', action: 'Find members', onAction: () => push(context, const FindMembersScreen())),
            SizedBox(
              height: 206,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suggest.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _SuggestCard(p: suggest[i]),
              ),
            ),
          ],
          _Header('Friends in photos', action: 'All albums', onAction: () => push(context, const AlbumsScreen())),
          if (feed.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    const Icon(Icons.photo_library_outlined, size: 40, color: SioColors.blue),
                    const SizedBox(height: 8),
                    const Text('No photos yet', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    const SizedBox(height: 4),
                    const Text(
                      'After a programme, find yourself in the album and tap “That’s me!”. Photos of you and your friends show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SioColors.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => push(context, const FriendsScreen()),
                      icon: const Icon(Icons.person_add_alt_1),
                      label: const Text('Find friends'),
                    ),
                  ],
                ),
              ),
            ),
          for (final (i, _) in feed.indexed)
            Enter(
              index: i,
              child: PhotoFeedCard(photos: feed, index: i),
            ),
        ];
      },
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header(this.text, {this.action, this.onAction});
  final String text;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 20, 8, 8),
    child: Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: SioColors.ink),
          ),
        ),
        if (action != null) TextButton(onPressed: onAction, child: Text(action!)),
      ],
    ),
  );
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.color, required this.text, required this.onTap});
  final IconData icon;
  final Color color;
  final String text;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: color.withValues(alpha: 0.08),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            CircleAvatar(radius: 18, backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon, size: 20)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    ),
  );
}

/// The row of rings at the top: me, then friends; the ring is lit when they've read today.
class _Stories extends StatelessWidget {
  const _Stories({required this.me, required this.journey, required this.friends, required this.openJourney});
  final Map<String, dynamic> me;
  final Map<String, dynamic>? journey;
  final List<Map<String, dynamic>> friends;
  final VoidCallback openJourney;

  @override
  Widget build(BuildContext context) {
    final rs = journey == null ? <String, dynamic>{} : _m(journey!['reading_streak']);
    final sorted = [...friends]
      ..sort((a, b) => (_m(b['reading'])['today'] == true ? 1 : 0) - (_m(a['reading'])['today'] == true ? 1 : 0));
    Widget story({
      required Widget avatar,
      required bool lit,
      required String label,
      int? flame,
      VoidCallback? onTap,
      bool plus = false,
    }) => Squish(
      onTap: onTap,
      child: SizedBox(
        width: 78,
        child: Column(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                StoryRing(spin: true, active: lit, size: 70, child: avatar),
                if (plus)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      decoration: BoxDecoration(
                        color: _flameC,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                      child: const Icon(Icons.local_fire_department, color: Colors.white, size: 16),
                    ),
                  ),
                if (flame != null && flame > 0)
                  Positioned(
                    bottom: -6,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                        decoration: BoxDecoration(
                          color: lit ? _flameC : SioColors.grey,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.white, width: 1.5),
                        ),
                        child: Text(
                          '🔥$flame',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w800),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    );
    final readCount = friends.where((f) => _m(f['reading'])['today'] == true).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Text(
            'Read today · $readCount of ${friends.length} friends   (tap a grey ring to nudge)',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SioColors.textSecondary),
          ),
        ),
        SizedBox(
          height: 118,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(10, 10, 10, 4),
            children: [
              story(
                avatar: Avatar('${me['full_name'] ?? ''}', radius: 30, light: true, photo: me['photo']),
                lit: rs['today'] == true,
                plus: rs['today'] != true,
                flame: rs['today'] == true ? _i(rs['current']) : null,
                label: 'Your streak',
                onTap: openJourney,
              ),
              for (final f in sorted)
                story(
                  avatar: Avatar('${f['full_name'] ?? ''}', radius: 30, light: true, photo: f['photo']),
                  lit: _m(f['reading'])['today'] == true,
                  flame: _i(_m(f['together'])['current']) > 0
                      ? _i(_m(f['together'])['current'])
                      : _i(_m(f['reading'])['current']),
                  label: '${f['username'] ?? AppState.callName('${f['full_name']}')}',
                  onTap: () => _friendSheet(context, f),
                ),
              story(
                avatar: const CircleAvatar(
                  radius: 30,
                  backgroundColor: SioColors.card,
                  child: Icon(Icons.person_add_alt_1, color: SioColors.blue),
                ),
                lit: false,
                label: 'Add friends',
                onTap: () => push(context, const FriendsScreen()),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

const _flameC = Color(0xFFF26B1D);

/// Tap a friend's ring: see their streak, nudge them if they haven't read, or open their page.
void _friendSheet(BuildContext context, Map<String, dynamic> f) {
  final read = _m(f['reading'])['today'] == true;
  final together = _i(_m(f['together'])['current']);
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            StoryRing(
              spin: true,
              active: read,
              size: 96,
              child: Avatar('${f['full_name']}', radius: 40, photo: f['photo']),
            ),
            const SizedBox(height: 10),
            Text('${f['full_name']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            if ('${f['username'] ?? ''}'.isNotEmpty)
              Text('@${f['username']}', style: const TextStyle(color: SioColors.textSecondary)),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _MiniStat('🔥 ${_i(_m(f['reading'])['current'])}', 'their streak'),
                const SizedBox(width: 12),
                _MiniStat('🤝 $together', 'together'),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              read ? '${AppState.callName('${f['full_name']}')} has read today ✅' : 'Hasn’t read today yet',
              style: TextStyle(color: read ? SioColors.green : SioColors.warning, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                if (!read) ...[
                  Expanded(
                    child: Builder(
                      builder: (bctx) => FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _flameC,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        onPressed: () async {
                          HapticFeedback.mediumImpact();
                          burst(bctx, emojis: const ['👋', '🔥', '✨'], count: 14, power: 0.8);
                          try {
                            final r = _m(await Api.call('${Api.m}nudge', {'member': f['member']}));
                            if (ctx.mounted) {
                              toast(ctx, r['already'] == 1 ? 'You already nudged them today' : 'Nudge sent 👋');
                            }
                          } on ApiException catch (e) {
                            if (ctx.mounted) toast(ctx, e.message);
                          }
                        },
                        icon: const Text('👋', style: TextStyle(fontSize: 18)),
                        label: const Text('Nudge', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 12)),
                    onPressed: () {
                      Navigator.pop(ctx);
                      push(context, PersonPage(member: '${f['member']}'));
                    },
                    child: const Text('View profile'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}

class _MiniStat extends StatelessWidget {
  const _MiniStat(this.value, this.label);
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
    decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(14)),
    child: Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: const TextStyle(fontSize: 12, color: SioColors.textSecondary)),
      ],
    ),
  );
}

class _AyahHero extends StatefulWidget {
  const _AyahHero({required this.journey});
  final Map<String, dynamic> journey;

  @override
  State<_AyahHero> createState() => _AyahHeroState();
}

class _AyahHeroState extends State<_AyahHero> with SingleTickerProviderStateMixin {
  bool _busy = false;
  bool _readNow = false; // marked read in this session
  int? _streakNow;
  bool _open = false; // re-opened after reading
  final _btn = GlobalKey();
  late final AnimationController _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  bool get _done => _readNow || _m(widget.journey['reading_streak'])['today'] == true;

  /// Listening to the whole recitation (or the Malayalam reading) counts as reading today.
  void _finishedListening() {
    if (!_done && !_busy) _read();
  }

  @override
  Widget build(BuildContext context) {
    final r = _m(widget.journey['reading']);
    final rs = _m(widget.journey['reading_streak']);
    final streak = _streakNow ?? _i(rs['current']);
    final audio = [for (final u in (r['audio'] as List? ?? [])) '$u'];
    final ml = '${r['text_ml'] ?? ''}';
    final ar = '${r['text_ar'] ?? ''}';
    if (_done && !_open) {
      // read today: a slim strip, so programmes and photos move up
      return Squish(
        onTap: () => setState(() => _open = true),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF0E3F70), Color(0xFF1A62A8)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF7CE0A0)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['kind'] == 'Hadith' ? 'Today’s hadith read' : 'Today’s ayah read',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${r['reference'] ?? ''} · tap to read again',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '🔥 $streak',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0E3F70), Color(0xFF1A62A8)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [BoxShadow(color: Color(0x331A62A8), blurRadius: 18, offset: Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                r['kind'] == 'Hadith' ? 'HADITH OF THE DAY' : 'AYAH OF THE DAY',
                style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (_done)
                InkWell(
                  onTap: () => setState(() => _open = false),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.expand_less, color: Colors.white70),
                  ),
                ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '🔥 $streak',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (ar.isNotEmpty) ...[
            SizedBox(
              width: double.infinity,
              child: Text(
                ar,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: const TextStyle(color: Colors.white, fontSize: 22, height: 1.9),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Malayalam meaning first; the English line under it, smaller
          if (ml.isNotEmpty) ...[
            Text(
              ml,
              style: const TextStyle(color: Colors.white, fontSize: 17, height: 1.6, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('“${r['text_en']}”', style: const TextStyle(color: Colors.white70, fontSize: 14, height: 1.4)),
          ] else
            Text(
              '“${r['text_en']}”',
              style: const TextStyle(color: Colors.white, fontSize: 18, height: 1.4, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 6),
          Text('— ${r['reference'] ?? ''}', style: const TextStyle(color: Colors.white70)),
          if (audio.isNotEmpty || malayalamToRead(r).isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                if (audio.isNotEmpty) AyahAudioButton(urls: audio, onComplete: _finishedListening),
                if (malayalamToRead(r).isNotEmpty) MalayalamSpeakButton(text: malayalamToRead(r), onComplete: _finishedListening),
              ],
            ),
            if (!_done)
              const Padding(
                padding: EdgeInsets.only(top: 6),
                child: Text(
                  'Listen till the end and it counts as read today.',
                  style: TextStyle(color: Colors.white60, fontSize: 12),
                ),
              ),
          ],
          if ('${r['lesson_en'] ?? ''}'.isNotEmpty || '${r['lesson_ml'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 ഇന്നത്തെ പാഠം · TODAY’S LESSON',
                    style: TextStyle(color: Color(0xFFFFD2B3), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  if ('${r['lesson_ml'] ?? ''}'.isNotEmpty)
                    Text('${r['lesson_ml']}', style: const TextStyle(color: Colors.white, fontSize: 15, height: 1.5)),
                  if ('${r['lesson_en'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('${r['lesson_en']}', style: const TextStyle(color: Colors.white70, fontSize: 13.5, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
          if (!_done && streak > 0 && DateTime.now().hour >= 17) ...[
            const SizedBox(height: 10),
            FadeTransition(
              opacity: Tween(begin: 0.6, end: 1.0).animate(_pulse),
              child: Text(
                '⏳ ${24 - DateTime.now().hour}h left to keep your $streak-day streak',
                style: const TextStyle(color: Color(0xFFFFD2B3), fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _done
                    ? Container(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(30),
                        ),
                        child: const Text(
                          '✓  Read today. See you tomorrow',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                      )
                    : ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                        child: FilledButton.icon(
                          key: _btn,
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: SioColors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _busy ? null : _read,
                          icon: const Icon(Icons.local_fire_department, color: _flameC),
                          label: Text(_busy ? 'Saving…' : 'I read it', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.16)),
                tooltip: 'Share',
                icon: const Icon(Icons.send_outlined, color: Colors.white),
                onPressed: () => SharePlus.instance.share(
                  ShareParams(
                    text: [
                      if (ar.isNotEmpty) ar,
                      if (ml.isNotEmpty) ml,
                      '“${r['text_en']}”',
                      '— ${r['reference'] ?? ''}',
                      if ('${r['lesson_ml'] ?? ''}'.isNotEmpty) '\n💡 ${r['lesson_ml']}',
                      '\nvia SIO Connect ${Links.share({'q': 'ayah'})}',
                    ].join('\n'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _read() async {
    setState(() => _busy = true);
    try {
      HapticFeedback.mediumImpact();
      final r = _m(await Api.call('${Api.m}read_today'));
      if (!mounted) return;
      setState(() {
        _streakNow = _i(r['current']);
      });
      final b = _btn.currentContext;
      if (b != null && b.mounted) burst(b, emojis: const ['🔥', '✨', '⭐', '💙'], count: 20);
      await Future.delayed(const Duration(milliseconds: 350));
      if (!mounted) return;
      await celebrateRead(context, r);
      if (mounted) {
        setState(() {
          _readNow = true;
          _open = false;
        });
      }
      AppState.i.refreshAll();
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _SuggestCard extends StatefulWidget {
  const _SuggestCard({required this.p});
  final Map<String, dynamic> p;

  @override
  State<_SuggestCard> createState() => _SuggestCardState();
}

class _SuggestCardState extends State<_SuggestCard> {
  bool _sent = false;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    return Container(
      width: 150,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: SioColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => push(context, PersonPage(member: '${p['member']}')),
            child: Avatar('${p['full_name'] ?? ''}', radius: 36, light: true, photo: p['photo']),
          ),
          const SizedBox(height: 8),
          Text(
            '${p['full_name'] ?? ''}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          Text(
            p['same_unit'] == true ? 'In your unit' : 'SIO ${p['unit'] ?? ''}',
            maxLines: 1,
            style: const TextStyle(color: SioColors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            child: _sent
                ? OutlinedButton(onPressed: null, child: const Text('Requested'))
                : FilledButton(
                    onPressed: () async {
                      final ok = await run(context, () => Api.call('${Api.m}friend_request', {'member': p['member']}));
                      if (ok && mounted) setState(() => _sent = true);
                    },
                    child: const Text('Add friend'),
                  ),
          ),
        ],
      ),
    );
  }
}

/// A programme as a colourful card (gradient by type, date badge, register state).
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.e, this.width});
  final Map<String, dynamic> e;
  final double? width;

  static List<Color> colorsFor(String? type) => switch ((type ?? '').toLowerCase()) {
    final t when t.contains('camp') || t.contains('tour') => const [Color(0xFF1E8E3E), Color(0xFF1A62A8)],
    final t when t.contains('class') || t.contains('study') => const [Color(0xFF7C3AED), Color(0xFF1A62A8)],
    final t when t.contains('relief') || t.contains('service') => const [Color(0xFFC8202A), Color(0xFFF26B1D)],
    _ => const [Color(0xFF1A62A8), Color(0xFFC8202A)],
  };

  @override
  Widget build(BuildContext context) {
    final d = parseDate(e['starts_on']);
    final registered = (e['my_registration'] ?? '').toString().isNotEmpty;
    return SizedBox(
      width: width,
      child: Material(
        borderRadius: BorderRadius.circular(20),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => push(context, EventDetailScreen(name: '${e['name']}', title: '${e['title']}')),
          child: Ink(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: colorsFor('${e['event_type'] ?? ''}'),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Stack(
              children: [
                const Positioned(right: -20, top: -20, child: Icon(Icons.celebration, size: 130, color: Color(0x1FFFFFFF))),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          if (d != null)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                              child: Column(
                                children: [
                                  Text(
                                    DateFormat('d').format(d),
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: SioColors.ink,
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM').format(d).toUpperCase(),
                                    style: const TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: SioColors.red),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          if (registered)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: const Text(
                                '✓ Going',
                                style: TextStyle(color: SioColors.green, fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const Spacer(),
                      Text(
                        '${e['title']}',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.2),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        [
                          if (d != null) DateFormat('EEE, h:mm a').format(d),
                          if ('${e['venue'] ?? ''}'.isNotEmpty) '${e['venue']}',
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      if (_i(e['registered_count']) > 0) ...[
                        const SizedBox(height: 4),
                        Text(
                          '${e['registered_count']} going',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- explore

class ExploreScreen extends StatelessWidget {
  const ExploreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = AppState.i;
    final tiles = <(IconData, List<Color>, String, Widget)>[
      (Icons.photo_library, const [Color(0xFFF26B1D), Color(0xFFC8202A)], 'Albums', const AlbumsScreen()),
      (Icons.push_pin, const [Color(0xFF1E8E3E), Color(0xFF0E7490)], 'Student board', const BoardScreen()),
      (Icons.badge, const [Color(0xFF0E3F70), Color(0xFF1A62A8)], 'My SIO card', const MemberCardScreen()),
      (Icons.travel_explore, const [Color(0xFF1A62A8), Color(0xFFC8202A)], 'Find members', const FindMembersScreen()),
      (Icons.people_alt, const [Color(0xFF7C3AED), Color(0xFF1A62A8)], 'Friends', const FriendsScreen()),
      (Icons.quiz, const [Color(0xFF7C3AED), Color(0xFFC8202A)], 'Weekly quiz', const JourneyScreen()),

      if (s.can('rsvp'))
        (Icons.event_note, const [Color(0xFF1A62A8), Color(0xFF0E3F70)], 'Meetings', const MeetingsScreen(standalone: true)),

      (Icons.campaign, const [Color(0xFF1E8E3E), Color(0xFF1A62A8)], 'Updates', const NoticesScreen()),
      if (s.me['member'] != null)
        (Icons.task_alt, const [Color(0xFF1A62A8), Color(0xFF1E8E3E)], 'My tasks', const MyTasksScreen()),
      (Icons.info_outline, const [Color(0xFF0E3F70), Color(0xFF7C3AED)], 'About SIO', const PublicScreen()),
    ];
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 22)),
      ),
      body: Loader<List<Map<String, dynamic>>>(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        load: () async => _l(await Api.call('${Api.m}events')),
        builder: (context, events) => [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => push(context, const FindMembersScreen()),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(14)),
              child: const Row(
                children: [
                  Icon(Icons.search, color: SioColors.textSecondary),
                  SizedBox(width: 10),
                  Text('Find SIO members anywhere', style: TextStyle(color: SioColors.textSecondary)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          GridView.count(
            crossAxisCount: 4,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 12,
            crossAxisSpacing: 8,
            childAspectRatio: 0.82,
            children: [
              for (final t in tiles)
                InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => push(context, t.$4),
                  child: Column(
                    children: [
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: t.$2, begin: Alignment.topLeft, end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Icon(t.$1, color: Colors.white, size: 28),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        t.$3,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Programmes',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: SioColors.ink),
          ),
          const SizedBox(height: 10),
          if (events.isEmpty) const EmptyNote('No programmes right now. You’ll get a notification when one is announced.'),
          for (final e in events)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SizedBox(height: 180, child: EventTile(e: e)),
            ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- settings

/// The ≡ menu on my profile: everything from the More screen (profile, offers, updates, sign out…).
class SettingsMenu extends StatelessWidget {
  const SettingsMenu({super.key});

  @override
  Widget build(BuildContext context) => const MoreScreen();
}

/// Opens the management app (meetings, collections, members…) on top, sliding up.
Future<void> openAdminDashboard(BuildContext context) {
  HapticFeedback.mediumImpact();
  return Navigator.of(context).push(
    PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const HomeShell(dashboard: true),
      transitionsBuilder: (_, a, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 1),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: a, curve: Curves.easeOutCubic)),
        child: child,
      ),
    ),
  );
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.home});
  final Map<String, dynamic> home;

  @override
  Widget build(BuildContext context) {
    final members = home['members'] as Map?;
    final exp = home['pending_expenses'] as Map?;
    final todo = <String>[
      if (members != null && numOf(members['pending']) > 0) '${members['pending']} to approve',
      if (exp != null && numOf(exp['count']) > 0) '${exp['count']} expenses waiting',
      if (numOf(home['my_tasks']) > 0) '${home['my_tasks']} tasks',
    ];
    return Squish(
      onTap: () => openAdminDashboard(context),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1F1F23), Color(0xFF0E3F70)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(gradient: sioGradient, borderRadius: BorderRadius.circular(14)),
              child: const Icon(Icons.space_dashboard, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Open admin dashboard',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    todo.isEmpty ? 'Meetings, collections, members and more' : todo.join(' · '),
                    style: const TextStyle(color: Colors.white70),
                  ),
                ],
              ),
            ),
            if (todo.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(color: SioColors.red, borderRadius: BorderRadius.circular(12)),
                child: Text(
                  '${todo.length}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                ),
              ),
            const Icon(Icons.arrow_forward_ios, color: Colors.white70, size: 16),
          ],
        ),
      ),
    );
  }
}

/// Shimmering outline of the home while it loads (rings, ayah card, programmes).
class _HomeSkeleton extends StatelessWidget {
  const _HomeSkeleton();

  @override
  Widget build(BuildContext context) => Shimmer(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              for (var i = 0; i < 4; i++) ...[
                const Column(children: [Bone(height: 66, circle: true), SizedBox(height: 8), Bone(width: 50, height: 10)]),
                const SizedBox(width: 16),
              ],
            ],
          ),
          const SizedBox(height: 24),
          const Bone(width: 220, height: 20),
          const SizedBox(height: 14),
          const Bone(width: double.infinity, height: 210, radius: 22),
          const SizedBox(height: 24),
          const Bone(width: 140, height: 18),
          const SizedBox(height: 12),
          const Row(
            children: [
              Expanded(child: Bone(height: 170, radius: 20)),
              SizedBox(width: 10),
              Expanded(child: Bone(height: 170, radius: 20)),
            ],
          ),
        ],
      ),
    ),
  );
}

/// When a new badge is earned, celebrate it once (remembered on this phone) and offer to share it.
final _badgeCheck = <String>{};
void checkNewBadges(BuildContext context, Map<String, dynamic> j) {
  final earned = [
    for (final b in _l(j['badges']))
      if (b['earned'] == true) b,
  ];
  final key = 'seen_badges_${AppState.i.me['member']}';
  final seen = Api.prefs.getStringList(key);
  final codes = [for (final b in earned) '${b['code']}'];
  if (seen == null) {
    Api.prefs.setStringList(key, codes); // first time: don't celebrate old badges
    return;
  }
  final fresh = earned.where((b) => !seen.contains(b['code']) && !_badgeCheck.contains(b['code'])).toList();
  if (fresh.isEmpty) return;
  final b = fresh.first;
  _badgeCheck.add('${b['code']}');
  Api.prefs.setStringList(key, {...seen, ...codes}.toList());
  WidgetsBinding.instance.addPostFrameCallback((_) async {
    await Future.delayed(const Duration(milliseconds: 600));
    if (!context.mounted) return;
    celebrate(
      context,
      number: earned.length,
      emoji: '🏅',
      colors: const [Color(0xFFE0A100), Color(0xFFF26B1D)],
      title: 'New badge: ${b['title']}',
      subtitle: '${b['how']}. That’s badge number ${earned.length}!',
      onShare: () => showShareCard(
        context,
        kind: 'Badge',
        badge: '${b['code']}',
        icon: badgeIcon('${b['icon']}'),
        color: const Color(0xFFE0A100),
        title: '${b['title']}',
        line: '${b['how']}',
        person: AppState.i.me,
      ),
    );
  });
}
