import 'dart:convert';

import 'package:http/http.dart' as http;
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
import 'qibla_screen.dart';
import 'programmes_screen.dart';
import 'recap_screen.dart';
import '../noor.dart';
import '../ayah_share.dart';
import '../home_widget_sync.dart';
import '../bug_report.dart';
import '../push.dart';
import 'onboarding_screen.dart';
import 'today_screen.dart';
import 'friends_tab.dart';
import 'prayer_tab.dart';
import '../prayer_alarms.dart';
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
      BugReport.startShake();
      Push.start();
      PrayerAlarms.schedule();
      if (mounted) Onboarding.maybeShow(context);
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
      PrayerAlarms.schedule();
      AppState.i.refreshAll();
    }
  }

  void _go(int i) {
    if (i != _tab) HapticFeedback.selectionClick();
    setState(() => _tab = i);
  }

  @override
  Widget build(BuildContext context) {
    const pages = [TodayScreen(), ProgrammesScreen(), FriendsTab(), PrayerTab()];
    Widget item(int i, IconData off, IconData on, String label) => Expanded(
      child: Semantics(
        button: true,
        selected: _tab == i,
        label: label,
        child: InkResponse(
          onTap: () => _go(i),
          child: SizedBox(
            height: 60,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Pop(
                  trigger: _tab == i,
                  scale: 1.25,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                    decoration: BoxDecoration(
                      color: _tab == i ? SioColors.blue.withValues(alpha: 0.12) : Colors.transparent,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(_tab == i ? on : off, size: 26, color: _tab == i ? SioColors.blue : SioColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: _tab == i ? FontWeight.w800 : FontWeight.w600,
                    color: _tab == i ? SioColors.blue : SioColors.textSecondary,
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
        decoration: BoxDecoration(
          color: SioColors.background,
          border: Border(top: BorderSide(color: SioColors.border, width: 1)),
        ),
        child: SafeArea(
          child: SizedBox(
            height: 62,
            child: Row(
              children: [
                item(0, Icons.spa_outlined, Icons.spa, 'Today'),
                item(1, Icons.event_outlined, Icons.event, 'Programmes'),
                item(2, Icons.group_outlined, Icons.group, 'Friends'),
                item(3, Icons.mosque_outlined, Icons.mosque, 'Prayer'),
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
      Api.call('${Api.m}my_photos').catchError((_) => []),
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
      'my_photos': r[8],
    };
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SioColors.background,
    appBar: AppBar(
      backgroundColor: SioColors.background,
      surfaceTintColor: SioColors.background,
      titleSpacing: 16,
      toolbarHeight: 52,
      title: Row(
        children: [
          Image.asset('assets/sio-logo.png', height: 24),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              'SIO Connect',
              maxLines: 1,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SioColors.ink, letterSpacing: -0.3),
            ),
          ),
        ],
      ),
      actions: [
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
        const SizedBox(width: 4),
      ],
    ),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'home',
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
        if (j != null) {
          checkNewBadges(context, j);
          final rs = _m(j['reading_streak']);
          if (rs['today'] == true) Notify.markReadToday(_i(rs['current']));
          final missed = _i(rs['current']) == 0 && _i(rs['best']) > 0;
          Notify.rememberStreak(
            _i(rs['current']),
            missed: missed,
            name: AppState.i.firstName,
            games: '${AppState.i.me['hide_games']}' != '1',
          );
          HomeWidgetSync.reading(
            j['reading'] == null ? null : _m(j['reading']),
            streak: _i(rs['current']),
            readToday: rs['today'] == true,
            missed: missed,
            name: AppState.i.firstName,
            games: '${AppState.i.me['hide_games']}' != '1',
          );
        }
        final games = '${AppState.i.me['hide_games']}' != '1';
        final stage = '${AppState.i.me['life_stage'] ?? ''}';
        final board = _l(_m(d['board'])['items']);
        final forKinds = switch (stage) {
          'School' => const ['Scholarship', 'Exam & Admission'],
          'College' => const ['Scholarship', 'Internship', 'Exam & Admission', 'Career'],
          'Working' => const ['Job', 'Internship', 'Career'],
          _ => const ['Scholarship', 'Job', 'Internship', 'Exam & Admission'],
        };
        final forYou = board.where((x) => forKinds.contains(x['kind'])).take(3).toList();
        final blood = board.where((x) => x['kind'] == 'Blood Request').take(2).toList();
        return [
          // 1. greeting + next prayer
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
            child: Text(
              'Assalamu Alaikum, ${AppState.i.firstName}',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SioColors.ink, letterSpacing: -0.3),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
            child: PrayerLine(onQibla: () => push(context, const QiblaScreen())),
          ),
          if (pending)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: SioBanner(
                text: 'Your unit will confirm you soon. Meanwhile, read today’s ayah, take the quiz and add friends.',
              ),
            ),
          if (AppState.i.isLeader)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Enter(child: _AdminCard(home: h)),
            ),
          if (_NewPhotos.of(d).isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Enter(child: _NewPhotos(photos: _NewPhotos.of(d))),
            ),
          // 2. today's ayah, compact
          if (j != null && j['reading'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _AyahCompact(journey: j, games: games),
            ),
          if (j != null && _m(j['unit_today'])['total'] != null && _i(_m(j['unit_today'])['total']) > 1)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _UnitToday(u: _m(j['unit_today'])),
            ),
          if (j != null && (DateTime.now().weekday >= DateTime.friday || DateTime.now().weekday == DateTime.monday))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: _Pill(
                icon: Icons.auto_awesome,
                color: SioColors.blue,
                text: DateTime.now().weekday == DateTime.monday
                    ? 'Your week is ready: see it and share it on WhatsApp Status'
                    : 'Your week so far: share it on WhatsApp Status',
                onTap: () => push(context, RecapScreen(games: games)),
              ),
            ),
          if (stage.isEmpty && !pending)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Pill(
                icon: Icons.person_outline,
                color: SioColors.blue,
                text: 'Tell us if you’re in school, college or working, so we show what’s useful for you',
                onTap: () => push(context, const ProfileScreen()),
              ),
            ),
          // 3. the next programme
          if (events.isNotEmpty) ...[
            _Header(
              events.length > 1 ? 'Next programme · ${events.length - 1} more' : 'Next programme',
              action: 'All',
              onAction: () => openTab(2),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(height: 176, child: EventTile(e: events.first)),
            ),
          ],
          if (h['next_meeting'] != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: MeetingCard(meeting: _m(h['next_meeting'])),
            ),
          // 4. for you, by life stage
          if (forYou.isNotEmpty || stage.isNotEmpty) ...[
            _Header(
              switch (stage) {
                'Working' => 'Jobs & giving back',
                'College' => 'For college students',
                'School' => 'Exams & scholarships',
                _ => 'Opportunities',
              },
              action: 'Board',
              onAction: () => push(context, const BoardScreen()),
            ),
            for (final x in forYou)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Pill(
                  icon: kindLook('${x['kind']}').$1,
                  color: SioColors.blue,
                  text:
                      '${kindLook('${x['kind']}').$3}: ${x['title']}'
                      '${'${x['last_date'] ?? ''}'.isNotEmpty ? ' · by ${fmtDate(x['last_date'])}' : ''}',
                  onTap: () => push(context, const BoardScreen()),
                ),
              ),
            if (stage == 'Working' && '${AppState.i.me['mentor_topics'] ?? ''}'.isEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Pill(
                  icon: Icons.volunteer_activism_outlined,
                  color: SioColors.green,
                  text: 'Guide a junior: add what you can help students with',
                  onTap: () => push(context, const ProfileScreen()),
                ),
              ),
            if (stage == 'Working')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Pill(
                  icon: Icons.business_center_outlined,
                  color: SioColors.blue,
                  text: 'Know an opening? Post a job or referral for SIO members',
                  onTap: () => push(context, const PostBoardScreen(lead: false, kind: 'Job')),
                ),
              ),
            if (stage == 'School' || stage == 'College')
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Pill(
                  icon: Icons.school_outlined,
                  color: SioColors.green,
                  text: 'Ask a senior: SIO members who can guide you on courses and careers',
                  onTap: () => push(context, const FindMembersScreen(mentors: true)),
                ),
              ),
          ],
          if (games && j != null && j['quiz'] != null && _m(j['quiz'])['my_score'] == null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: _Pill(
                icon: Icons.quiz_outlined,
                color: SioColors.purple,
                text: 'This week’s quiz: ${_m(j['quiz'])['title']} · ${_m(j['quiz'])['questions']} questions',
                onTap: () => push(context, QuizScreen(name: '${_m(j['quiz'])['name']}')),
              ),
            ),
          if (blood.isNotEmpty) ...[
            _Header('Blood needed', action: 'Board', onAction: () => push(context, const BoardScreen())),
            for (final x in blood)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: _Pill(
                  icon: Icons.bloodtype,
                  color: SioColors.red,
                  text: '🩸 ${x['blood_group'] ?? ''} needed: ${x['title']}',
                  onTap: () => push(context, const BoardScreen()),
                ),
              ),
          ],
          // 5. friends
          if (requests.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Pill(
                icon: Icons.person_add_alt_1,
                color: SioColors.blue,
                text:
                    '${requests.first['full_name']}${requests.length > 1 ? ' and ${requests.length - 1} more' : ''} '
                    'sent you a friend request',
                onTap: () => push(context, const FriendsScreen()),
              ),
            ),
          if (friends.length >= 3) ...[
            _Header('Friends', action: 'All', onAction: () => push(context, const FriendsScreen())),
            _Stories(me: AppState.i.me, journey: j, friends: friends, openJourney: () => openTab(3)),
          ] else if (suggest.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: _Pill(
                icon: Icons.group_add_outlined,
                color: SioColors.blue,
                text: 'Find friends from your unit, college or city',
                onTap: () => push(context, const FindMembersScreen()),
              ),
            ),
          if (suggest.isNotEmpty && friends.length < 8) ...[
            _Header('People you may know', action: 'Find members', onAction: () => push(context, const FindMembersScreen())),
            SizedBox(
              height: 190 * MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6),
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: suggest.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _SuggestCard(p: suggest[i]),
              ),
            ),
          ],
          // 6. photos
          if (_l(_m(d['albums'])['albums']).isNotEmpty) ...[
            _Header('Albums', action: 'All', onAction: () => push(context, const AlbumsScreen())),
            AlbumStrip(albums: _l(_m(d['albums'])['albums']).take(8).toList()),
          ],
          if (feed.isNotEmpty)
            _Header('Friends in photos', action: 'All albums', onAction: () => push(context, const AlbumsScreen())),
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
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: SioColors.ink),
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
            'Read today · $readCount of ${friends.length}',
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: SioColors.textSecondary),
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
                avatar: CircleAvatar(
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
            if ('${f['username'] ?? ''}'.isNotEmpty) Text('@${f['username']}', style: TextStyle(color: SioColors.textSecondary)),
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
        Text(label, style: TextStyle(fontSize: 12, color: SioColors.textSecondary)),
      ],
    ),
  );
}

/// "Ottaplam: 18 of 44 read today": the whole unit together, no names (togetherness, not a ranking).
class _UnitToday extends StatelessWidget {
  const _UnitToday({required this.u});
  final Map<String, dynamic> u;

  @override
  Widget build(BuildContext context) {
    final read = _i(u['read']);
    final total = _i(u['total']);
    final f = total == 0 ? 0.0 : (read / total).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🏮', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${u['unit']}: $read of $total read today',
                  style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
                ),
              ),
              Text(
                '${(f * 100).round()}%',
                style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.blue),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: f,
              minHeight: 8,
              backgroundColor: SioColors.greyBg,
              color: const Color(0xFFF2A93B),
            ),
          ),
          if (read < total)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                read == 0 ? 'Be the first in your unit today ✨' : 'Every reader lights the unit up a little more',
                style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
              ),
            ),
        ],
      ),
    );
  }
}

/// "You're in 5 new photos from Area Tour": the photos I was tagged in since I last looked (last 2 weeks).
class _NewPhotos extends StatelessWidget {
  const _NewPhotos({required this.photos});
  final List<Map<String, dynamic>> photos;

  static List<Map<String, dynamic>> of(Map<String, dynamic> d) {
    final seen = DateTime.tryParse(Api.prefs.getString('photos_seen_at') ?? '') ?? DateTime(2000);
    final since = DateTime.now().subtract(const Duration(days: 14));
    final from = seen.isAfter(since) ? seen : since;
    return [
      for (final p in _l(d['my_photos']))
        if ((DateTime.tryParse('${p['tagged_on']}') ?? DateTime(2000)).isAfter(from)) p,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final albums = {for (final p in photos) '${p['album_title'] ?? ''}'}..remove('');
    final where = albums.length == 1 ? ' from ${albums.first}' : '';
    return Squish(
      onTap: () async {
        await Api.prefs.setString('photos_seen_at', DateTime.now().toIso8601String());
        if (context.mounted) await push(context, const MyPhotosScreen());
        AppState.i.refreshAll();
      },
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(18)),
        child: Row(
          children: [
            SizedBox(
              width: 44.0 + 22 * (photos.take(3).length - 1),
              height: 50,
              child: Stack(
                children: [
                  for (var i = 0; i < photos.take(3).length; i++)
                    Positioned(
                      left: i * 22.0,
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: SioColors.background, width: 2),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            '${Api.baseUrl}${photos[i]['file_url']}',
                            cacheWidth: 150,
                            width: 44,
                            height: 46,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => Container(width: 44, height: 46, color: SioColors.greyBg),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '📸 You’re in ${photos.length} new photo${photos.length == 1 ? '' : 's'}$where',
                style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
            ),
            Icon(Icons.chevron_right, color: SioColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Home: today's ayah in a few lines; tap to open the full reader (Arabic, Malayalam, audio, lesson).
class _AyahCompact extends StatelessWidget {
  const _AyahCompact({required this.journey, required this.games});
  final Map<String, dynamic> journey;
  final bool games;

  @override
  Widget build(BuildContext context) {
    final r = _m(journey['reading']);
    final rs = _m(journey['reading_streak']);
    final done = rs['today'] == true;
    final ml = '${r['text_ml'] ?? ''}';
    final mood = noorMood(
      readToday: done,
      streak: _i(rs['current']),
      missedYesterday: _i(rs['current']) == 0 && _i(rs['best']) > 0,
    );
    final says = noorLine(mood, streak: _i(rs['current']), name: AppState.i.firstName, games: games);
    void open() => push(context, AyahReaderScreen(journey: journey, games: games));
    if (done) {
      return Squish(
        onTap: open,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(18)),
          child: Row(
            children: [
              const Noor(mood: NoorMood.happy, size: 44),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      says,
                      style: TextStyle(fontWeight: FontWeight.w700, color: SioColors.ink),
                    ),
                    Text(
                      '${r['kind'] == 'Hadith' ? 'Today’s hadith' : 'Today’s ayah'} · ${r['reference'] ?? ''}',
                      style: TextStyle(color: SioColors.textSecondary, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              if (games)
                Text(
                  '🔥 ${_i(rs['current'])}',
                  style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
                ),
              Icon(Icons.chevron_right, color: SioColors.textSecondary),
            ],
          ),
        ),
      );
    }
    return Squish(
      onTap: open,
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0E3F70), Color(0xFF1A62A8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            NoorSays(mood: mood, text: says, light: true, size: 60),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(
                  r['kind'] == 'Hadith' ? 'HADITH OF THE DAY' : 'AYAH OF THE DAY',
                  style: const TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                if (games && _i(rs['current']) > 0)
                  Text(
                    '🔥 ${_i(rs['current'])}',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              ml.isNotEmpty ? ml : '“${r['text_en'] ?? ''}”',
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: ml.isNotEmpty
                  ? malayalamStyle(color: Colors.white, size: 16, weight: FontWeight.w700)
                  : const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700, height: 1.4),
            ),
            const SizedBox(height: 4),
            Text('— ${r['reference'] ?? ''}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
            const SizedBox(height: 12),
            Row(
              children: [
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF1A62A8),
                    shape: const StadiumBorder(),
                    visualDensity: VisualDensity.compact,
                  ),
                  onPressed: open,
                  icon: const Icon(Icons.menu_book_outlined, size: 18),
                  label: const Text('Read & listen', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The full ayah: Arabic, Malayalam, English, recitation and Malayalam audio, the lesson, "I read it" and share.
class AyahReaderScreen extends StatelessWidget {
  const AyahReaderScreen({super.key, required this.journey, this.games = true});
  final Map<String, dynamic> journey;
  final bool games;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SioColors.background,
    appBar: AppBar(
      backgroundColor: SioColors.background,
      surfaceTintColor: SioColors.background,
      title: Text(_m(journey['reading'])['kind'] == 'Hadith' ? 'Hadith of the day' : 'Ayah of the day'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Builder(
          builder: (context) {
            final rs = _m(journey['reading_streak']);
            final mood = noorMood(
              readToday: rs['today'] == true,
              streak: _i(rs['current']),
              missedYesterday: _i(rs['current']) == 0 && _i(rs['best']) > 0,
            );
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: NoorSays(
                mood: mood,
                text: rs['today'] == true
                    ? noorLine(mood, streak: _i(rs['current']), name: AppState.i.firstName, games: games)
                    : 'Listen to the end, or tap “I read it”, to water me today 💧',
              ),
            );
          },
        ),
        _AyahHero(journey: journey, games: games, alwaysOpen: true),
        if (_m(journey['reading'])['kind'] != 'Hadith') _MoreAyahs(reference: '${_m(journey['reading'])['reference'] ?? ''}'),
      ],
    ),
  );
}

/// Optional: keep reading the next ayahs after today's one (today's streak only needs the first).
class _MoreAyahs extends StatefulWidget {
  const _MoreAyahs({required this.reference});
  final String reference; // "Qur'an 94:5-6"

  @override
  State<_MoreAyahs> createState() => _MoreAyahsState();
}

class _MoreAyahsState extends State<_MoreAyahs> {
  final _ayahs = <Map<String, dynamic>>[];
  bool _busy = false;
  String? _error;

  (int, int)? get _next {
    final last = _ayahs.isNotEmpty ? _ayahs.last : null;
    if (last != null) return ((last['surah'] as int), (last['ayah'] as int) + 1);
    final m = RegExp(r'(\d+):(\d+)(?:-(\d+))?').firstMatch(widget.reference);
    if (m == null) return null;
    return (int.parse(m.group(1)!), int.parse(m.group(3) ?? m.group(2)!) + 1);
  }

  Future<void> _more() async {
    final n = _next;
    if (n == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final r = await http
          .get(Uri.parse('https://api.alquran.cloud/v1/ayah/${n.$1}:${n.$2}/editions/quran-uthmani,ml.abdulhameed,en.sahih'))
          .timeout(const Duration(seconds: 15));
      final data = (jsonDecode(r.body)['data'] as List?) ?? const [];
      if (r.statusCode != 200 || data.length < 3) {
        // end of the surah: carry on with the next one
        if (n.$1 < 114 && _ayahs.isNotEmpty) {
          _ayahs.add({'surah': n.$1 + 1, 'ayah': 0, 'skip': true});
          await _more();
          return;
        }
        throw Exception('end');
      }
      setState(() {
        _ayahs.removeWhere((a) => a['skip'] == true);
        _ayahs.add({
          'surah': n.$1,
          'ayah': n.$2,
          'ar': '${data[0]['text'] ?? ''}',
          'ml': '${data[1]['text'] ?? ''}',
          'en': '${data[2]['text'] ?? ''}',
          'name': '${data[0]['surah']?['englishName'] ?? ''}',
          'audio': 'https://cdn.islamic.network/quran/audio/128/ar.alafasy/${data[0]['number']}.mp3',
        });
      });
    } catch (_) {
      if (mounted) setState(() => _error = 'Couldn’t load the next ayah. Check your internet and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      for (final a in _ayahs.where((a) => a['skip'] != true))
        Container(
          margin: const EdgeInsets.only(top: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(20)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${a['name']} ${a['surah']}:${a['ayah']}',
                style: TextStyle(color: SioColors.blue, fontWeight: FontWeight.w800, fontSize: 12, letterSpacing: 1),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: Text(
                  '${a['ar']}',
                  textAlign: TextAlign.right,
                  textDirection: TextDirection.rtl,
                  style: arabicStyle(color: SioColors.ink, size: 22),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${a['ml']}',
                style: malayalamStyle(color: SioColors.ink, size: 16, weight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Text('“${a['en']}”', style: TextStyle(color: SioColors.textSecondary, height: 1.4)),
              const SizedBox(height: 8),
              AyahAudioButton(urls: ['${a['audio']}']),
            ],
          ),
        ),
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 10),
          child: Text(_error!, style: TextStyle(color: SioColors.danger)),
        ),
      if (_next != null) ...[
        const SizedBox(height: 14),
        OutlinedButton.icon(
          onPressed: _busy ? null : _more,
          icon: _busy
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_stories_outlined),
          label: Text(_ayahs.isEmpty ? 'Keep reading: the next ayah' : 'Read one more'),
        ),
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            'Optional. One ayah a day is enough for your streak.',
            textAlign: TextAlign.center,
            style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
          ),
        ),
      ],
    ],
  );
}

class _AyahHero extends StatefulWidget {
  const _AyahHero({required this.journey, this.games = true, this.alwaysOpen = false});
  final Map<String, dynamic> journey;
  final bool games;
  final bool alwaysOpen; // the reader page: never folds into the slim strip

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
    if (_done && !_open && !widget.alwaysOpen) {
      // read today: a slim strip, so programmes and photos move up
      return Squish(
        onTap: () => setState(() => _open = true),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFFF4F9FF), Color(0xFFDDEEFC)]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Icon(Icons.check_circle, color: Color(0xFF2E9E5B)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      r['kind'] == 'Hadith' ? 'Today’s hadith read' : 'Today’s ayah read',
                      style: const TextStyle(color: Color(0xFF0E3F70), fontWeight: FontWeight.w800),
                    ),
                    Text(
                      '${r['reference'] ?? ''} · tap to read again',
                      style: const TextStyle(color: Color(0xFF46607A), fontSize: 12),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '🔥 $streak',
                  style: const TextStyle(color: Color(0xFF0E3F70), fontWeight: FontWeight.w800),
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
          colors: [Color(0xFFF7FBFF), Color(0xFFDDEEFC)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFCFE5FA), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x141A62A8), blurRadius: 14, offset: Offset(0, 6))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                r['kind'] == 'Hadith' ? 'HADITH OF THE DAY' : 'AYAH OF THE DAY',
                style: const TextStyle(color: Color(0xFF46607A), fontSize: 11, letterSpacing: 2, fontWeight: FontWeight.w800),
              ),
              const Spacer(),
              if (_done && !widget.alwaysOpen)
                InkWell(
                  onTap: () => setState(() => _open = false),
                  child: const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.expand_less, color: Color(0xFF46607A)),
                  ),
                ),
              if (widget.games)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                  child: Text(
                    '🔥 $streak',
                    style: const TextStyle(color: Color(0xFF0E3F70), fontWeight: FontWeight.w800),
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
                style: arabicStyle(color: Color(0xFF0E3F70), size: 24),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // Malayalam meaning first; the English line under it, smaller
          if (ml.isNotEmpty) ...[
            Text(
              ml,
              style: malayalamStyle(color: Color(0xFF0E3F70), size: 17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text('“${r['text_en']}”', style: const TextStyle(color: Color(0xFF46607A), fontSize: 14, height: 1.4)),
          ] else
            Text(
              '“${r['text_en']}”',
              style: const TextStyle(color: Color(0xFF0E3F70), fontSize: 18, height: 1.4, fontWeight: FontWeight.w700),
            ),
          const SizedBox(height: 6),
          Text('— ${r['reference'] ?? ''}', style: const TextStyle(color: Color(0xFF46607A))),
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
                  style: TextStyle(color: Color(0xFF6B8299), fontSize: 12),
                ),
              ),
          ],
          if ('${r['lesson_en'] ?? ''}'.isNotEmpty || '${r['lesson_ml'] ?? ''}'.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '💡 ഇന്നത്തെ പാഠം · TODAY’S LESSON',
                    style: TextStyle(color: Color(0xFFC96A1B), fontSize: 11, letterSpacing: 1.2, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  if ('${r['lesson_ml'] ?? ''}'.isNotEmpty)
                    Text('${r['lesson_ml']}', style: malayalamStyle(color: Color(0xFF0E3F70), size: 15)),
                  if ('${r['lesson_en'] ?? ''}'.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text('${r['lesson_en']}', style: const TextStyle(color: Color(0xFF46607A), fontSize: 13.5, height: 1.4)),
                  ],
                ],
              ),
            ),
          ],
          if (widget.games && !_done && streak > 0 && DateTime.now().hour >= 17) ...[
            const SizedBox(height: 10),
            FadeTransition(
              opacity: Tween(begin: 0.6, end: 1.0).animate(_pulse),
              child: Text(
                '⏳ ${24 - DateTime.now().hour}h left to keep your $streak-day streak',
                style: const TextStyle(color: Color(0xFFC96A1B), fontWeight: FontWeight.w700),
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
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                        child: const Text(
                          '✓  Read today. See you tomorrow',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Color(0xFF0E3F70), fontWeight: FontWeight.w700),
                        ),
                      )
                    : ScaleTransition(
                        scale: Tween(begin: 1.0, end: 1.04).animate(CurvedAnimation(parent: _pulse, curve: Curves.easeInOut)),
                        child: FilledButton.icon(
                          key: _btn,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF1A62A8),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: const StadiumBorder(),
                          ),
                          onPressed: _busy ? null : _read,
                          icon: const Icon(Icons.water_drop_rounded, color: Colors.white),
                          label: Text(_busy ? 'Saving…' : 'I read it', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              IconButton(
                style: IconButton.styleFrom(backgroundColor: Colors.white),
                tooltip: 'Share',
                icon: const Icon(Icons.send_outlined, color: Color(0xFF1A62A8)),
                onPressed: () => shareAyahImage(context, r),
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
      Notify.markReadToday(_i(r['current']));
      HomeWidgetSync.reading(
        null,
        streak: _i(r['current']),
        readToday: true,
        name: AppState.i.firstName,
        games: '${AppState.i.me['hide_games']}' != '1',
      );
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
    final scale = MediaQuery.textScalerOf(context).scale(1).clamp(1.0, 1.6);
    return Container(
      width: 140 * scale,
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        border: Border.all(color: SioColors.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          InkWell(
            customBorder: const CircleBorder(),
            onTap: () => push(context, PersonPage(member: '${p['member']}')),
            child: Avatar('${p['full_name'] ?? ''}', radius: 32, light: true, photo: p['photo']),
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
            style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity,
            height: 36 * scale,
            child: _sent
                ? OutlinedButton.icon(
                    onPressed: null,
                    style: OutlinedButton.styleFrom(padding: EdgeInsets.zero, shape: const StadiumBorder()),
                    icon: const Icon(Icons.check, size: 16),
                    label: const FittedBox(child: Text('Sent')),
                  )
                : FilledButton.icon(
                    style: FilledButton.styleFrom(padding: EdgeInsets.zero, shape: const StadiumBorder()),
                    onPressed: () async {
                      final ok = await run(context, () => Api.call('${Api.m}friend_request', {'member': p['member']}));
                      if (ok && mounted) setState(() => _sent = true);
                    },
                    icon: const Icon(Icons.person_add_alt_1, size: 16),
                    label: const FittedBox(
                      child: Text('Add', style: TextStyle(fontWeight: FontWeight.w700)),
                    ),
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

  static List<Color> colorsFor(String? type) => const [Color(0xFF0E3F70), Color(0xFF1A62A8)];

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
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w900,
                                      color: const Color(0xFF1F1F23),
                                      height: 1,
                                    ),
                                  ),
                                  Text(
                                    DateFormat('MMM').format(d).toUpperCase(),
                                    style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: const Color(0xFFC8202A)),
                                  ),
                                ],
                              ),
                            ),
                          const Spacer(),
                          if (registered)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                              child: Text(
                                '✓ Going',
                                style: TextStyle(color: const Color(0xFF1E8E3E), fontWeight: FontWeight.w800, fontSize: 12),
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
                      const SizedBox(height: 6),
                      FacesGoing(e: e, light: true),
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
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: AppState.i,
    builder: (context, _) {
      final s = AppState.i;
      final games = '${s.me['hide_games']}' != '1';
      final tiles = <(IconData, String, Widget)>[
        (Icons.explore_outlined, 'Qibla', const QiblaScreen()),
        (Icons.school_outlined, 'Mentors', const FindMembersScreen(mentors: true)),
        (Icons.business_center_outlined, 'Jobs & board', const BoardScreen()),
        (Icons.photo_library_outlined, 'Albums', const AlbumsScreen()),
        if (games) (Icons.emoji_events_outlined, 'Leaderboard', const ReadingBoardScreen()),
        if (games) (Icons.quiz_outlined, 'Weekly quiz', const JourneyScreen()),
      ];
      // less used: a short list under the grid, only what applies to this person
      final more = <(IconData, String, Widget)>[
        if (s.can('rsvp')) (Icons.event_note, 'Meetings', const MeetingsScreen(standalone: true)),
        if (s.me['member'] != null) (Icons.task_alt, 'My tasks', const MyTasksScreen()),
        if (s.me['member'] != null) (Icons.badge_outlined, 'My SIO card', const MemberCardScreen()),
        (Icons.info_outline, 'About SIO', const PublicScreen()),
        (Icons.bug_report_outlined, 'Report a problem', const MyReportsScreen()),
      ];
      return Scaffold(
        backgroundColor: SioColors.background,
        appBar: AppBar(
          backgroundColor: SioColors.background,
          surfaceTintColor: SioColors.background,
          automaticallyImplyLeading: false,
          title: const Text('Explore', style: TextStyle(fontWeight: FontWeight.w800)),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () => push(context, const FindMembersScreen()),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                decoration: BoxDecoration(color: SioColors.card, borderRadius: BorderRadius.circular(14)),
                child: Row(
                  children: [
                    Icon(Icons.search, color: SioColors.textSecondary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Find members by name, college, profession or city',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: SioColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.05,
              children: [
                for (final t in tiles)
                  Material(
                    color: SioColors.card,
                    borderRadius: BorderRadius.circular(18),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () => push(context, t.$3),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: SioColors.blue.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(t.$1, color: SioColors.blue, size: 26),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            t.$2,
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: SioColors.ink),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            for (final m in more)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(m.$1, color: SioColors.blue),
                title: Text(m.$2, style: const TextStyle(fontWeight: FontWeight.w600)),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => push(context, m.$3),
              ),
          ],
        ),
      );
    },
  );
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
