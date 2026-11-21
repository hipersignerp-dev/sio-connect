import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../notify.dart';
import '../ayah_audio.dart';
import '../fx.dart';
import '../links.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';
import 'card_screens.dart';
import 'album_screens.dart';
import 'find_members_screen.dart';
import 'more_screen.dart';

// My journey: daily ayah / hadith streak, weekly quiz, badges, friends and their pages, posts, unit board.

const _flame = Color(0xFFF26B1D);
const _gold = Color(0xFFE0A100);

IconData badgeIcon(String? name) => switch (name) {
  'local_fire_department' => Icons.local_fire_department,
  'whatshot' => Icons.whatshot,
  'event_available' => Icons.event_available,
  'groups' => Icons.groups,
  'verified' => Icons.verified,
  'volunteer_activism' => Icons.volunteer_activism,
  'favorite' => Icons.favorite,
  'quiz' => Icons.quiz,
  'emoji_events' => Icons.emoji_events,
  'military_tech' => Icons.military_tech,
  'person_add' => Icons.person_add,
  'diversity_3' => Icons.diversity_3,
  _ => Icons.workspace_premium,
};

Map<String, dynamic> _map(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
List<Map<String, dynamic>> _list(dynamic v) => [for (final x in (v as List? ?? [])) _map(x)];
int _int(dynamic v) => numOf(v).toInt();

String handle(Map p) => '${p['username'] ?? ''}'.isEmpty ? '' : '@${p['username']}';

// ---------------------------------------------------------------- journey home

class JourneyScreen extends StatefulWidget {
  const JourneyScreen({super.key, this.asTab = false});
  final bool asTab;

  @override
  State<JourneyScreen> createState() => _JourneyScreenState();
}

class _JourneyScreenState extends State<JourneyScreen> {
  bool _reading = false;

  Future<Map<String, dynamic>> _load() async => _map(await Api.call('${Api.m}journey'));

  Future<void> _read(Map<String, dynamic> j) async {
    setState(() => _reading = true);
    try {
      final r = _map(await Api.call('${Api.m}read_today'));
      Notify.markReadToday(_int(r['current']));
      AppState.i.refreshAll();
      if (!mounted) return;
      await celebrateRead(context, r);
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !widget.asTab,
      title: const Text('My journey', style: TextStyle(fontWeight: FontWeight.w800)),
      actions: [
        if (!widget.asTab)
          IconButton(
            tooltip: 'My page',
            icon: const Icon(Icons.account_circle_outlined),
            onPressed: () => push(context, const PersonPage()),
          ),
      ],
    ),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'journey',
      load: _load,
      builder: (context, j) {
        final me = _map(j['me']);
        final rs = _map(j['reading_streak']);
        final reading = j['reading'] == null ? null : _map(j['reading']);
        final badges = _list(j['badges']);
        final earned = badges.where((b) => b['earned'] == true).length;
        final quiz = j['quiz'] == null ? null : _map(j['quiz']);
        return [
          if ('${me['username'] ?? ''}'.isEmpty) ...[
            SioPanel(
              color: SioColors.warningBg,
              onTap: () => pickUsername(context),
              child: Row(
                children: [
                  Icon(Icons.alternate_email, color: SioColors.warning),
                  SizedBox(width: 12),
                  Expanded(child: Text('Choose your username so friends can find you and you can invite people.')),
                  Icon(Icons.chevron_right),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ],
          _StreakHero(streak: rs),
          const SizedBox(height: 8),
          SioTile(
            icon: Icons.emoji_events_outlined,
            title: 'Reading leaderboard',
            subtitle: 'See your rank among all SIO students',
            onTap: () => push(context, const ReadingBoardScreen()),
          ),
          const SizedBox(height: 12),
          if (reading != null) _ReadingCard(reading: reading, done: rs['today'] == true, busy: _reading, onRead: () => _read(j)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _Stat(Icons.quiz, '${_int(_map(j['quiz_streak'])['current'])}', 'quiz weeks', SioColors.purple)),
              const SizedBox(width: 8),
              Expanded(child: _Stat(Icons.emoji_events, '$earned/${badges.length}', 'badges', _gold)),
            ],
          ),
          if (quiz != null) ...[
            const SectionTitle('This week’s quiz'),
            SioPanel(
              onTap: () => push(context, QuizScreen(name: '${quiz['name']}')),
              child: Row(
                children: [
                  CircleAvatar(backgroundColor: SioColors.purple, foregroundColor: Colors.white, child: Icon(Icons.quiz)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${quiz['title']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                        Text(
                          quiz['my_score'] != null
                              ? 'You scored ${quiz['my_score']} / ${quiz['my_total']}'
                              : '${quiz['questions']} questions · open till ${fmtDate(quiz['ends_on'], 'd MMM')}',
                          style: TextStyle(color: SioColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  quiz['my_score'] != null
                      ? Icon(Icons.check_circle, color: SioColors.green)
                      : FilledButton(
                          onPressed: () => push(context, QuizScreen(name: '${quiz['name']}')),
                          child: const Text('Start'),
                        ),
                ],
              ),
            ),
          ],
          SectionTitle(
            'Badges',
            action: Text('$earned earned', style: TextStyle(color: SioColors.textSecondary)),
          ),
          _BadgeGrid(badges: badges, person: me),
          const SectionTitle('Together'),
          SioTile(
            icon: Icons.people_alt_outlined,
            title: 'Friends',
            subtitle: _int(j['friend_requests']) > 0
                ? '${j['friend_requests']} friend request${_int(j['friend_requests']) > 1 ? 's' : ''} waiting'
                : '${j['friends']} friends · streaks together',
            trailing: _int(j['friend_requests']) > 0
                ? Badge(label: Text('${j['friend_requests']}'), child: const Icon(Icons.chevron_right))
                : null,
            onTap: () => push(context, const FriendsScreen()),
          ),

          SioTile(
            icon: Icons.person_add_alt_1,
            title: 'Invite a friend',
            subtitle: _int(j['invited']) > 0 ? '${j['invited']} joined with your code' : 'Share the app with your invite code',
            onTap: () => SharePlus.instance.share(ShareParams(text: '${j['invite_text']}')),
          ),
        ];
      },
    ),
  );
}

class _StreakHero extends StatelessWidget {
  const _StreakHero({required this.streak});
  final Map<String, dynamic> streak;

  @override
  Widget build(BuildContext context) {
    final n = _int(streak['current']);
    final today = streak['today'] == true;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: today ? const [Color(0xFFF26B1D), Color(0xFFC8202A)] : const [Color(0xFF1A62A8), Color(0xFF0E3F70)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          Icon(today ? Icons.local_fire_department : Icons.local_fire_department_outlined, color: Colors.white, size: 54),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$n day${n == 1 ? '' : 's'}',
                  style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w800),
                ),
                Text(
                  today
                      ? 'Reading streak · done for today'
                      : n > 0
                      ? 'Read today’s ayah to keep your streak'
                      : 'Start your reading streak today',
                  style: const TextStyle(color: Colors.white70),
                ),
                const SizedBox(height: 4),
                Text(
                  (streak['frozen'] as List? ?? []).isNotEmpty
                      ? '🧊 Streak freeze saved a missed day this week'
                      : _int(streak['freeze_left']) > 0
                      ? '🧊 1 freeze left this week: one missed day won’t break it'
                      : '🧊 Freeze used this week',
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '${_int(streak['best'])}',
                style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const Text('best', style: TextStyle(color: Colors.white70, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _ReadingCard extends StatelessWidget {
  const _ReadingCard({required this.reading, required this.done, required this.busy, required this.onRead});
  final Map<String, dynamic> reading;
  final bool done;
  final bool busy;
  final VoidCallback onRead;

  @override
  Widget build(BuildContext context) => SioPanel(
    padding: const EdgeInsets.all(18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            StatusChip(reading['kind'] == 'Hadith' ? 'Hadith of the day' : 'Ayah of the day', tone: Tone.blue),
            const Spacer(),
            if (done) Icon(Icons.check_circle, color: SioColors.green),
          ],
        ),
        const SizedBox(height: 14),
        if ('${reading['text_ar'] ?? ''}'.isNotEmpty) ...[
          Text(
            '${reading['text_ar']}',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: arabicStyle(color: SioColors.ink, size: 24),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          '“${reading['text_en']}”',
          style: TextStyle(fontSize: 18, height: 1.45, fontWeight: FontWeight.w600, color: SioColors.ink),
        ),
        if ('${reading['text_ml'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${reading['text_ml']}', style: malayalamStyle(size: 16, color: SioColors.ink)),
        ],
        const SizedBox(height: 8),
        Text('— ${reading['reference'] ?? ''}', style: TextStyle(color: SioColors.textSecondary)),
        if ((reading['audio'] as List? ?? []).isNotEmpty || malayalamToRead(reading).isNotEmpty) ...[
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((reading['audio'] as List? ?? []).isNotEmpty)
                AyahAudioButton(urls: [for (final u in reading['audio'] as List) '$u'], light: false),
              if (malayalamToRead(reading).isNotEmpty) MalayalamSpeakButton(text: malayalamToRead(reading), light: false),
            ],
          ),
        ],
        if ('${reading['lesson_en'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: SioColors.warningBg, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '💡 TODAY’S LESSON',
                  style: TextStyle(color: Color(0xFFB07800), fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text('${reading['lesson_en']}', style: TextStyle(fontSize: 15, height: 1.4, color: SioColors.ink)),
                if ('${reading['lesson_ml'] ?? ''}'.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('${reading['lesson_ml']}', style: const TextStyle(fontSize: 14, height: 1.5)),
                ],
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: done
                  ? OutlinedButton.icon(onPressed: null, icon: const Icon(Icons.check), label: const Text('Read today'))
                  : FilledButton.icon(
                      style: FilledButton.styleFrom(backgroundColor: _flame),
                      onPressed: busy ? null : onRead,
                      icon: const Icon(Icons.local_fire_department),
                      label: Text(busy ? 'Saving…' : 'I read it'),
                    ),
            ),
            const SizedBox(width: 8),
            IconButton.outlined(
              tooltip: 'Share',
              icon: const Icon(Icons.share),
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      '“${reading['text_en']}”\n— ${reading['reference'] ?? ''}'
                      '${'${reading['text_ml'] ?? ''}'.isNotEmpty ? '\n\n${reading['text_ml']}' : ''}\n\nvia SIO Connect',
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat(this.icon, this.value, this.label, this.color);
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => SioPanel(
    padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
    child: Column(
      children: [
        Icon(icon, color: color),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SioColors.ink),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: SioColors.textSecondary),
        ),
      ],
    ),
  );
}

class _BadgeGrid extends StatelessWidget {
  const _BadgeGrid({required this.badges, required this.person, this.readOnly = false});
  final List<Map<String, dynamic>> badges;
  final Map<String, dynamic> person;
  final bool readOnly;

  @override
  Widget build(BuildContext context) => GridView.count(
    crossAxisCount: 3,
    shrinkWrap: true,
    physics: const NeverScrollableScrollPhysics(),
    mainAxisSpacing: 8,
    crossAxisSpacing: 8,
    childAspectRatio: 0.82,
    children: [
      for (final b in badges)
        SioPanel(
          padding: const EdgeInsets.all(8),
          color: b['earned'] == true ? SioColors.warningBg : SioColors.card,
          onTap: () => _open(context, b),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 24,
                backgroundColor: b['earned'] == true ? _gold : SioColors.greyBg,
                foregroundColor: b['earned'] == true ? Colors.white : SioColors.grey,
                child: Icon(badgeIcon('${b['icon']}')),
              ),
              const SizedBox(height: 6),
              Text(
                '${b['title']}',
                textAlign: TextAlign.center,
                maxLines: 2,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: b['earned'] == true ? SioColors.ink : SioColors.textSecondary,
                ),
              ),
              if (b['earned'] != true && b['goal'] != null && _int(b['goal']) > 1) ...[
                const SizedBox(height: 4),
                ProgressBar(_int(b['progress']) / _int(b['goal'])),
              ],
            ],
          ),
        ),
    ],
  );

  void _open(BuildContext context, Map<String, dynamic> b) {
    if (b['earned'] == true && !readOnly) {
      showShareCard(
        context,
        kind: 'Badge',
        badge: '${b['code']}',
        icon: badgeIcon('${b['icon']}'),
        color: _gold,
        title: '${b['title']}',
        line: '${b['how']}',
        person: person,
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: b['earned'] == true ? _gold : SioColors.greyBg,
              foregroundColor: b['earned'] == true ? Colors.white : SioColors.grey,
              child: Icon(badgeIcon('${b['icon']}'), size: 32),
            ),
            const SizedBox(height: 12),
            Text('${b['title']}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text('${b['how'] ?? ''}', textAlign: TextAlign.center),
            if (b['goal'] != null && b['earned'] != true) ...[
              const SizedBox(height: 12),
              ProgressBar(_int(b['progress']) / _int(b['goal'])),
              const SizedBox(height: 4),
              Text('${b['progress']} of ${b['goal']}', style: TextStyle(color: SioColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- username

Future<void> pickUsername(BuildContext context, [String? current]) async {
  final c = TextEditingController(text: current ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Your username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: c,
            autofocus: true,
            decoration: const InputDecoration(prefixText: '@', hintText: 'e.g. faheem_ts'),
          ),
          const SizedBox(height: 8),
          Text(
            'Letters, numbers, dot or underscore. Friends find you with it, and it is your invite code.',
            style: TextStyle(color: SioColors.textSecondary, fontSize: 13),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
      ],
    ),
  );
  if (ok == true && context.mounted) {
    await run(context, () => Api.call('${Api.m}set_username', {'username': c.text.trim()}), done: 'Username saved');
  }
}

// ---------------------------------------------------------------- share card

/// A good-looking card of an achievement, to share as a picture (WhatsApp, status…) or post on my page.
Future<void> showShareCard(
  BuildContext context, {
  required String kind,
  required IconData icon,
  required Color color,
  required String title,
  required String line,
  dynamic person,
  String? big,
  String? badge,
}) async {
  final key = GlobalKey();
  final p = _map(person);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: key,
              child: _AchievementCard(icon: icon, color: color, title: title, line: line, big: big, person: p),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      final bytes = await _capture(key);
                      final text = '$title! ${handle(p).isEmpty ? '' : '${handle(p)} '}on SIO Connect';
                      await SharePlus.instance.share(
                        ShareParams(
                          text: text,
                          files: bytes == null
                              ? null
                              : [XFile.fromData(bytes, mimeType: 'image/png', name: 'sio-achievement.png')],
                          fileNameOverrides: bytes == null ? null : ['sio-achievement.png'],
                        ),
                      );
                    },
                    icon: const Icon(Icons.share),
                    label: const Text('Share'),
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

Future<Uint8List?> _capture(GlobalKey key) async {
  try {
    final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}

class _AchievementCard extends StatelessWidget {
  const _AchievementCard({
    required this.icon,
    required this.color,
    required this.title,
    required this.line,
    required this.person,
    this.big,
  });
  final IconData icon;
  final Color color;
  final String title;
  final String line;
  final String? big;
  final Map<String, dynamic> person;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      gradient: const LinearGradient(
        colors: [Color(0xFF0E3F70), Color(0xFF1A62A8)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
    ),
    child: Column(
      children: [
        Container(
          width: 104,
          height: 104,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            border: Border.all(color: Colors.white, width: 4),
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 16, offset: Offset(0, 6))],
          ),
          child: big == null
              ? Icon(icon, color: Colors.white, size: 54)
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 30),
                    Text(
                      big!,
                      style: const TextStyle(color: Colors.white, fontSize: 30, fontWeight: FontWeight.w900, height: 1),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          line,
          textAlign: TextAlign.center,
          style: const TextStyle(color: Colors.white70, fontSize: 14),
        ),
        const SizedBox(height: 18),
        const Divider(color: Colors.white24, height: 1),
        const SizedBox(height: 12),
        Row(
          children: [
            Avatar('${person['full_name'] ?? ''}', radius: 16, light: true, photo: person['photo']),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                ['${person['full_name'] ?? ''}', if (handle(person).isNotEmpty) handle(person)].join('  '),
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
              child: Image.asset('assets/sio-logo.png', height: 18),
            ),
            const SizedBox(width: 6),
            const Text(
              'SIO Connect',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
            ),
          ],
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- quiz

class QuizScreen extends StatefulWidget {
  const QuizScreen({super.key, required this.name});
  final String name;

  @override
  State<QuizScreen> createState() => _QuizScreenState();
}

class _QuizScreenState extends State<QuizScreen> {
  Map<String, dynamic>? _q;
  String? _error;
  final Map<int, int> _answers = {};
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final q = _map(await Api.call('${Api.m}quiz', {'name': widget.name}));
      if (mounted) setState(() => _q = q);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _submit() async {
    final qs = _list(_q!['questions']);
    if (_answers.length < qs.length) {
      toast(context, 'Answer all ${qs.length} questions first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final r = _map(
        await Api.call('${Api.m}submit_quiz', {
          'name': widget.name,
          'answers': jsonEncode([for (var i = 0; i < qs.length; i++) _answers[i]]),
        }),
      );
      AppState.i.refreshAll();
      await _load();
      if (!mounted) return;
      final full = r['score'] == r['total'];
      await celebrate(
        context,
        number: _int(r['score']),
        emoji: full ? '🏆' : (_int(r['score']) * 2 >= _int(r['total']) ? '⭐' : '📚'),
        colors: full ? const [Color(0xFFE0A100), Color(0xFFF26B1D)] : const [Color(0xFF7C3AED), Color(0xFF1A62A8)],
        title: full ? 'Full marks!' : 'You scored ${r['score']} of ${r['total']}',
        subtitle: full ? 'Every answer right. Share it!' : 'See the right answers below and try again next week.',
        onShare: () => showShareCard(
          context,
          kind: 'Quiz',
          badge: full ? 'quiz_full' : null,
          icon: full ? Icons.emoji_events : Icons.quiz,
          color: full ? _gold : SioColors.purple,
          big: '${r['score']}/${r['total']}',
          title: full ? 'Full marks in the weekly quiz!' : 'I scored ${r['score']}/${r['total']} in the weekly quiz',
          line: '${_q!['title']}',
          person: AppState.i.me,
        ),
      );
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final q = _q;
    return Scaffold(
      appBar: AppBar(title: Text(q == null ? 'Quiz' : '${q['title']}')),
      body: q == null
          ? Center(child: _error != null ? Text(_error!) : const CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                if (q['done'] == true)
                  SioPanel(
                    color: SioColors.greenBg,
                    child: Text(
                      'You scored ${q['score']} out of ${q['total']}. The right answers are marked below.',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                if ('${q['prize'] ?? ''}'.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: SioPanel(
                      color: SioColors.warningBg,
                      child: Row(
                        children: [
                          const Text('🎁', style: TextStyle(fontSize: 26)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text('Prize: ${q['prize']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (q['done'] == true) _Leaderboard(q: q),
                for (final (i, x) in _list(q['questions']).indexed) _question(i, x, q['done'] == true, q),
                if (q['done'] != true) ...[
                  const SizedBox(height: 12),
                  FilledButton(onPressed: _busy ? null : _submit, child: Text(_busy ? 'Checking…' : 'Submit answers')),
                ],
              ],
            ),
    );
  }

  Widget _question(int i, Map<String, dynamic> x, bool done, Map<String, dynamic> q) {
    final opts = (x['options'] as List).map((e) => '$e').toList();
    final mine = done ? ((q['my_answers'] as List?) ?? []).elementAtOrNull(i) : _answers[i];
    final right = done ? _int(x['correct']) : null;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SioPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${i + 1}. ${x['question']}', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 8),
            for (final (k, o) in opts.indexed)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Material(
                  color: done
                      ? (k == right ? SioColors.greenBg : (k == mine ? SioColors.dangerBg : Colors.white))
                      : (mine == k ? SioColors.cardHigh : Colors.white),
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: done ? null : () => setState(() => _answers[i] = k),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(
                            done
                                ? (k == right ? Icons.check_circle : (k == mine ? Icons.cancel : Icons.circle_outlined))
                                : (mine == k ? Icons.radio_button_checked : Icons.radio_button_off),
                            color: done
                                ? (k == right ? SioColors.green : (k == mine ? SioColors.danger : SioColors.textSecondary))
                                : SioColors.blue,
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: Text(o)),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            if (done && '${x['explanation'] ?? ''}'.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('${x['explanation']}', style: TextStyle(color: SioColors.textSecondary)),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- friends

class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  final _search = TextEditingController();
  List<Map<String, dynamic>>? _found;
  int _seq = 0;

  Future<void> _find(String q) async {
    final mine = ++_seq;
    if (q.trim().length < 2) {
      setState(() => _found = null);
      return;
    }
    try {
      final r = _list(await Api.call('${Api.m}find_people', {'q': q.trim()}));
      if (mounted && mine == _seq) setState(() => _found = r);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Friends')),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'friends',
      load: () async => _map(await Api.call('${Api.m}friends')),
      builder: (context, f) {
        final incoming = _list(f['incoming']);
        final friends = _list(f['friends']);
        final outgoing = _list(f['outgoing']);
        return [
          TextField(
            controller: _search,
            onChanged: _find,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: 'Find people by @username or name',
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
          const SizedBox(height: 8),
          SioTile(
            icon: Icons.travel_explore,
            title: 'Find SIO members anywhere',
            subtitle: 'By unit, college, home town, or near you',
            onTap: () => push(context, const FindMembersScreen()),
          ),
          if (_found != null) ...[
            const SectionTitle('People'),
            if (_found!.isEmpty) const EmptyNote('No one found.'),
            if (_found!.isNotEmpty)
              PanelList(
                children: [
                  for (final p in _found!)
                    _PersonRow(
                      p: p,
                      trailing: _FriendButton(member: '${p['member']}', state: '${p['friend']}', compact: true),
                    ),
                ],
              ),
          ],
          if (incoming.isNotEmpty) ...[
            const SectionTitle('Friend requests'),
            PanelList(
              children: [
                for (final p in incoming)
                  _PersonRow(
                    p: p,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Decline',
                          icon: Icon(Icons.close, color: SioColors.danger),
                          onPressed: () =>
                              run(context, () => Api.call('${Api.m}friend_request', {'request': p['request'], 'accept': 0})),
                        ),
                        IconButton.filled(
                          tooltip: 'Accept',
                          icon: const Icon(Icons.check),
                          onPressed: () => run(
                            context,
                            () => Api.call('${Api.m}friend_request', {'request': p['request'], 'accept': 1}),
                            done: 'You are now friends',
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
          SectionTitle('My friends (${friends.length})'),
          if (friends.isEmpty)
            const EmptyNote('Search above to add friends. Read every day together and build a streak side by side.'),
          if (friends.isNotEmpty)
            PanelList(
              children: [
                for (final p in friends)
                  _PersonRow(
                    p: p,
                    subtitle:
                        'Their streak ${_int(_map(p['reading'])['current'])} · together ${_int(_map(p['together'])['current'])}',
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_map(p['reading'])['today'] != true)
                          Builder(
                            builder: (bctx) => IconButton(
                              tooltip: 'Nudge to read today',
                              icon: const Text('👋', style: TextStyle(fontSize: 22)),
                              onPressed: () async {
                                HapticFeedback.mediumImpact();
                                burst(bctx, emojis: const ['👋', '🔥', '✨'], count: 12, power: 0.7);
                                try {
                                  final r = _map(await Api.call('${Api.m}nudge', {'member': p['member']}));
                                  if (context.mounted) {
                                    toast(context, r['already'] == 1 ? 'Already nudged today' : 'Nudge sent 👋');
                                  }
                                } on ApiException catch (e) {
                                  if (context.mounted) toast(context, e.message);
                                }
                              },
                            ),
                          ),
                        _DuoFlame(together: _map(p['together'])),
                      ],
                    ),
                  ),
              ],
            ),
          if (outgoing.isNotEmpty) ...[
            const SectionTitle('Requests you sent'),
            PanelList(
              children: [
                for (final p in outgoing)
                  _PersonRow(
                    p: p,
                    trailing: _FriendButton(member: '${p['member']}', state: 'sent', compact: true),
                  ),
              ],
            ),
          ],
        ];
      },
    ),
  );
}

class _DuoFlame extends StatelessWidget {
  const _DuoFlame({required this.together});
  final Map<String, dynamic> together;

  @override
  Widget build(BuildContext context) {
    final n = _int(together['current']);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.local_fire_department, color: n > 0 ? _flame : SioColors.greyBg),
        Text(
          '$n',
          style: TextStyle(fontWeight: FontWeight.w800, color: n > 0 ? _flame : SioColors.textSecondary),
        ),
      ],
    );
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.p, this.trailing, this.subtitle});
  final Map<String, dynamic> p;
  final Widget? trailing;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: Avatar('${p['full_name'] ?? ''}', photo: p['photo'], light: true),
    title: Text('${p['full_name'] ?? ''}'),
    subtitle: Text(
      subtitle ?? [if (handle(p).isNotEmpty) handle(p), if (p['unit'] != null) '${p['unit']}'].join(' · '),
      style: TextStyle(color: SioColors.textSecondary),
    ),
    trailing: trailing,
    onTap: () => push(context, PersonPage(member: '${p['member']}')),
  );
}

class _FriendButton extends StatelessWidget {
  const _FriendButton({required this.member, required this.state, this.compact = false});
  final String member;
  final String state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    Future<void> act(Map<String, dynamic> a, String done) =>
        run(context, () => Api.call('${Api.m}friend_request', {'member': member, ...a}), done: done);
    switch (state) {
      case 'friends':
        return OutlinedButton.icon(
          onPressed: () async {
            if (await _confirm(context, 'Remove this friend?')) act({'remove': 1}, 'Removed');
          },
          icon: const Icon(Icons.how_to_reg),
          label: const Text('Friends'),
        );
      case 'sent':
        return OutlinedButton(onPressed: () => act({'remove': 1}, 'Request cancelled'), child: const Text('Cancel'));
      case 'received':
        return FilledButton(onPressed: () => act({}, 'You are now friends'), child: const Text('Accept'));
      case 'self':
        return const SizedBox.shrink();
      default:
        return FilledButton.icon(
          onPressed: () => act({}, 'Friend request sent'),
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: Text(compact ? 'Add' : 'Add friend'),
        );
    }
  }
}

Future<bool> _confirm(BuildContext context, String q) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Text(q),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('No')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Yes')),
        ],
      ),
    ) ==
    true;

// ---------------------------------------------------------------- a person's page

class PersonPage extends StatelessWidget {
  const PersonPage({super.key, this.member, this.asTab = false, this.username});
  final String? member; // null (and no username) = my page
  final String? username; // from a shared link
  final bool asTab; // the Profile tab of the associate app (no back button, a menu instead)

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      automaticallyImplyLeading: !asTab,
      title: ListenableBuilder(
        listenable: AppState.i,
        builder: (context, _) => Text(
          member == null && username == null && '${AppState.i.me['username'] ?? ''}'.isNotEmpty
              ? '@${AppState.i.me['username']}'
              : (member == null && username == null ? 'My page' : 'Profile'),
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
      ),
      actions: [
        if (asTab)
          IconButton(
            tooltip: 'Settings and more',
            icon: const Icon(Icons.menu),
            onPressed: () => push(context, const MoreScreen()),
          ),
      ],
    ),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'profile_${member ?? username ?? 'me'}',
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 110),
      load: () async => _map(await Api.call('${Api.m}profile', {'member': ?member, 'username': ?username})),
      builder: (context, p) => [_ProfileBody(p: p)],
    ),
  );
}

class _ProfileBody extends StatefulWidget {
  const _ProfileBody({required this.p});
  final Map<String, dynamic> p;

  @override
  State<_ProfileBody> createState() => _ProfileBodyState();
}

class _ProfileBodyState extends State<_ProfileBody> {
  bool _grid = true;

  @override
  Widget build(BuildContext context) {
    final p = widget.p;
    final st = '${_map(p['friend'])['state']}';
    final photos = _list(p['photos']);
    final badges = _list(p['badges']);
    final self = st == 'self';
    final reading = _map(p['reading']);
    final games = '${p['hide_games']}' != '1';
    final stageLine = [
      if ('${p['profession'] ?? ''}'.isNotEmpty)
        '${p['profession']}${'${p['workplace'] ?? ''}'.isNotEmpty ? ' at ${p['workplace']}' : ''}'
      else if ('${p['campus'] ?? ''}'.isNotEmpty)
        '${'${p['course'] ?? ''}'.isNotEmpty ? '${p['course']}, ' : ''}${p['campus']}',
      if ('${p['current_city'] ?? ''}'.isNotEmpty) '📍 ${p['current_city']}',
    ].join(' · ');
    final mobile = '${p['mobile'] ?? ''}';
    Widget count(String n, String label, [VoidCallback? onTap]) => Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text(
                n,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
              Text(label, style: TextStyle(fontSize: 12.5, color: SioColors.text)),
            ],
          ),
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Row(
            children: [
              StoryRing(
                spin: true,
                active: reading['today'] == true,
                size: 92,
                child: Avatar('${p['full_name']}', radius: 40, photo: p['photo']),
              ),
              const SizedBox(width: 8),
              count('${photos.length}', 'photos'),
              count('${p['friends'] ?? 0}', 'friends', self ? () => push(context, const FriendsScreen()) : null),
              if (games) count('${_int(reading['current'])}🔥', 'streak'),
              if (games) count('${badges.length}', 'badges'),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${p['full_name']}',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: SioColors.ink),
              ),
              const SizedBox(height: 2),
              Text(
                [
                  if (friendlyRole(p['member_role']) != null) friendlyRole(p['member_role'])!,
                  if (p['unit'] != null) 'SIO ${p['unit']}',
                ].join(' · '),
                style: TextStyle(color: SioColors.textSecondary),
              ),
              if (stageLine.isNotEmpty) ...[const SizedBox(height: 2), Text(stageLine, style: TextStyle(color: SioColors.text))],
              if ('${p['mentor_topics'] ?? ''}'.isNotEmpty) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: SioColors.blue.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '🎓 Can guide students in: ${p['mentor_topics']}',
                    style: TextStyle(color: SioColors.blue, fontWeight: FontWeight.w600, fontSize: 13),
                  ),
                ),
              ],
              if (self && '${p['username'] ?? ''}'.isEmpty && '${AppState.i.me['life_stage'] ?? ''}'.isEmpty) ...[
                const SizedBox(height: 8),
                InkWell(
                  onTap: () => push(context, const ProfileScreen()),
                  child: Text(
                    '+ Add your college or work so SIO friends can find you',
                    style: TextStyle(color: SioColors.blue, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: self
                ? [
                    Expanded(
                      child: _SoftButton(label: 'Edit profile', onTap: () => push(context, const ProfileScreen())),
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: _SoftButton(label: 'My SIO card', onTap: () => push(context, const MemberCardScreen())),
                    ),
                    const SizedBox(width: 6),
                    _SoftButton(icon: Icons.group_outlined, onTap: () => push(context, const FriendsScreen())),
                  ]
                : [
                    Expanded(
                      child: _FriendButton(member: '${p['member']}', state: st),
                    ),
                    if (mobile.isNotEmpty) ...[
                      const SizedBox(width: 6),
                      _SoftButton(icon: Icons.call_outlined, onTap: () => launchUrl(Uri.parse('tel:$mobile'))),
                      const SizedBox(width: 6),
                      _SoftButton(
                        icon: Icons.chat_outlined,
                        onTap: () => launchUrl(
                          Uri.parse(
                            'https://wa.me/${waNumber(mobile)}?text=${Uri.encodeComponent('Assalamu Alaikum! Found you on SIO Connect.')}',
                          ),
                          mode: LaunchMode.externalApplication,
                        ),
                      ),
                    ],
                  ],
          ),
        ),
        if (p['together'] != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFFEBDD), Color(0xFFFFE1E3)]),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: _flame, size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Streak together: ${_int(_map(p['together'])['current'])} days · best ${_int(_map(p['together'])['best'])}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (games && badges.isNotEmpty) ...[
          const SizedBox(height: 14),
          SizedBox(
            height: 104,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final b in badges)
                  InkWell(
                    borderRadius: BorderRadius.circular(40),
                    onTap: () => self
                        ? showShareCard(
                            context,
                            kind: 'Badge',
                            badge: '${b['code']}',
                            icon: badgeIcon('${b['icon']}'),
                            color: _gold,
                            title: '${b['title']}',
                            line: '${b['how']}',
                            person: p,
                          )
                        : toast(context, '${b['title']}: ${b['how']}'),
                    child: SizedBox(
                      width: 76,
                      child: Column(
                        children: [
                          Container(
                            width: 62,
                            height: 62,
                            padding: const EdgeInsets.all(2.5),
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(colors: [_gold, _flame]),
                            ),
                            child: Container(
                              decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                              padding: const EdgeInsets.all(2.5),
                              child: CircleAvatar(
                                backgroundColor: SioColors.warningBg,
                                foregroundColor: _gold,
                                child: Icon(badgeIcon('${b['icon']}')),
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${b['title']}',
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 11, height: 1.15),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 8),
        if (games)
          Row(
            children: [
              for (final (i, ic) in [Icons.grid_on, Icons.workspace_premium_outlined].indexed)
                Expanded(
                  child: InkWell(
                    onTap: () => setState(() => _grid = i == 0),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        border: Border(
                          bottom: BorderSide(
                            color: (_grid == (i == 0)) ? SioColors.ink : SioColors.border,
                            width: (_grid == (i == 0)) ? 1.6 : 1,
                          ),
                        ),
                      ),
                      child: Icon(ic, color: (_grid == (i == 0)) ? SioColors.ink : SioColors.textSecondary),
                    ),
                  ),
                ),
            ],
          ),
        if (!games) Divider(height: 1, color: SioColors.border),
        if (_grid || !games) ...[
          if (photos.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.photo_camera_outlined, size: 40, color: SioColors.textSecondary),
                  const SizedBox(height: 8),
                  Text(self ? 'No photos of you yet' : 'No photos yet', style: const TextStyle(fontWeight: FontWeight.w700)),
                  if (self) ...[
                    const SizedBox(height: 6),
                    Text(
                      'Open a programme album, find yourself and tap “That’s me!”. Your SIO moments collect here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: SioColors.textSecondary),
                    ),
                  ],
                ],
              ),
            )
          else
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
              children: [
                for (final (i, x) in photos.indexed)
                  GestureDetector(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => PhotoViewer(
                          photos: [
                            for (final y in photos) {...y, 'me': self, 'tags': const []},
                          ],
                          start: i,
                        ),
                      ),
                    ),
                    child: Image.network('${Api.baseUrl}${x['file_url']}', fit: BoxFit.cover, cacheWidth: 400),
                  ),
              ],
            ),
        ] else
          Padding(
            padding: const EdgeInsets.all(12),
            child: _BadgeGrid(
              badges: self
                  ? _list(p['all_badges']).isNotEmpty
                        ? _list(p['all_badges'])
                        : badges
                  : badges,
              person: p,
              readOnly: !self,
            ),
          ),
      ],
    );
  }
}

class _SoftButton extends StatelessWidget {
  const _SoftButton({this.label, this.icon, required this.onTap});
  final String? label;
  final IconData? icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: SioColors.card,
    borderRadius: BorderRadius.circular(10),
    child: InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 9, horizontal: label == null ? 10 : 8),
        child: label == null
            ? Icon(icon, size: 20, color: SioColors.ink)
            : Text(
                label!,
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w700, color: SioColors.ink),
              ),
      ),
    ),
  );
}

Future<void> newNotePost(BuildContext context) async {
  final c = TextEditingController();
  final text = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('New post'),
      content: TextField(
        controller: c,
        maxLines: 4,
        maxLength: 140,
        decoration: const InputDecoration(hintText: 'Share a reflection, a goal, something you did…'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Post')),
      ],
    ),
  );
  if (text != null && text.isNotEmpty && context.mounted) {
    await run(context, () => Api.call('${Api.m}create_post', {'kind': 'Note', 'title': text}), done: 'Posted');
  }
}

// ---------------------------------------------------------------- posts

/// The picture part of a post: badge / streak / quiz achievements get a bold gradient tile, notes a quote card.
class PostArt extends StatelessWidget {
  const PostArt({super.key, required this.post, this.small = false});
  final Map<String, dynamic> post;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final kind = '${post['kind']}';
    final (icon, colors) = switch (kind) {
      'Badge' => (badgeIconForCode('${post['badge'] ?? ''}'), const [Color(0xFFE0A100), Color(0xFFF26B1D)]),
      'Streak' => (Icons.local_fire_department, const [Color(0xFFF26B1D), Color(0xFFC8202A)]),
      'Quiz' => (Icons.emoji_events, const [Color(0xFF7C3AED), Color(0xFF1A62A8)]),
      _ => (Icons.format_quote, const [Color(0xFF1A62A8), Color(0xFF0E3F70)]),
    };
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        padding: EdgeInsets.all(small ? 8 : 28),
        child: Stack(
          children: [
            Positioned(
              right: small ? -14 : -40,
              bottom: small ? -14 : -40,
              child: Icon(icon, size: small ? 70 : 220, color: Colors.white.withValues(alpha: 0.12)),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (kind != 'Note')
                    Container(
                      padding: EdgeInsets.all(small ? 6 : 18),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white.withValues(alpha: 0.2),
                        border: Border.all(color: Colors.white, width: small ? 1.5 : 3),
                      ),
                      child: Icon(icon, color: Colors.white, size: small ? 22 : 64),
                    ),
                  SizedBox(height: small ? 4 : 18),
                  Text(
                    '${post['title']}',
                    textAlign: TextAlign.center,
                    maxLines: small ? 3 : 6,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: small ? 11 : (kind == 'Note' ? 22 : 24),
                      height: 1.25,
                    ),
                  ),
                  if (!small) ...[
                    const SizedBox(height: 16),
                    const Text(
                      'SIO CONNECT',
                      style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 3, fontWeight: FontWeight.w700),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

IconData badgeIconForCode(String code) {
  if (code.startsWith('reader')) return Icons.local_fire_department;
  return switch (code) {
    'first_programme' => Icons.event_available,
    'meetings_10' => Icons.groups,
    'attend_4' => Icons.verified,
    'volunteer' => Icons.volunteer_activism,
    'giver' => Icons.favorite,
    'quiz_first' => Icons.quiz,
    'quiz_full' => Icons.emoji_events,
    'quiz_4' => Icons.military_tech,
    'inviter' => Icons.person_add,
    'friends_5' => Icons.diversity_3,
    _ => Icons.workspace_premium,
  };
}

/// A post in the feed, Instagram style: who, the picture, cheers, caption.
class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post});
  final Map<String, dynamic> post;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> with SingleTickerProviderStateMixin {
  late int _cheers = _int(widget.post['cheers']);
  late bool _mine = widget.post['my_cheer'] == true;
  bool _burst = false;
  int _pops = 0;
  final _cheerKey = GlobalKey();
  final _artKey = GlobalKey();
  Offset? _tapAt;

  static const _cheerEmojis = ['🎉', '✨', '💙', '❤️', '🔥', '⭐', '👏'];

  void _flash() {
    setState(() => _burst = true);
    Future.delayed(const Duration(milliseconds: 750), () => mounted ? setState(() => _burst = false) : null);
  }

  Future<void> _cheer({bool onlyOn = false, Offset? at}) async {
    HapticFeedback.mediumImpact();
    if (onlyOn) {
      _flash();
      final ctx = _artKey.currentContext;
      if (ctx != null) burst(ctx, at: at, emojis: _cheerEmojis, count: 22);
      if (_mine) return;
    } else if (!_mine) {
      final ctx = _cheerKey.currentContext;
      if (ctx != null) burst(ctx, emojis: _cheerEmojis, count: 14, power: 0.7);
    }
    setState(() {
      _mine = !_mine;
      _cheers += _mine ? 1 : -1;
      _pops++;
    });
    try {
      final r = _map(await Api.call('${Api.m}post_action', {'name': widget.post['name']}));
      if (mounted) {
        setState(() {
          _cheers = _int(r['cheers']);
          _mine = r['my_cheer'] == true;
        });
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final by = _map(p['by']);
    final isMe = by['member'] == AppState.i.me['member'];
    final body = '${p['body'] ?? ''}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 4, 8),
            child: Row(
              children: [
                InkWell(
                  customBorder: const CircleBorder(),
                  onTap: () => push(context, PersonPage(member: '${by['member']}')),
                  child: StoryRing(
                    size: 40,
                    active: true,
                    child: Avatar('${by['full_name'] ?? ''}', radius: 16, light: true, photo: by['photo']),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: InkWell(
                    onTap: () => push(context, PersonPage(member: '${by['member']}')),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          handle(by).isNotEmpty ? '${by['username']}' : '${by['full_name'] ?? ''}',
                          style: TextStyle(fontWeight: FontWeight.w700, color: SioColors.ink),
                        ),
                        Text(
                          [if (by['unit'] != null) 'SIO ${by['unit']}', timeAgo(p['creation'])].join(' · '),
                          style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
                if (isMe || AppState.i.can('approve_members'))
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.more_horiz),
                    onPressed: () async {
                      if (await _confirm(context, 'Delete this post?') && context.mounted) {
                        run(context, () => Api.call('${Api.m}post_action', {'name': p['name'], 'action': 'delete'}));
                      }
                    },
                  ),
              ],
            ),
          ),
          GestureDetector(
            key: _artKey,
            onDoubleTapDown: (d) => _tapAt = d.globalPosition,
            onDoubleTap: () => _cheer(onlyOn: true, at: _tapAt),
            child: Stack(
              alignment: Alignment.center,
              children: [
                PostArt(post: p),
                AnimatedScale(
                  scale: _burst ? 1 : 0,
                  duration: Duration(milliseconds: _burst ? 380 : 200),
                  curve: _burst ? Curves.elasticOut : Curves.easeIn,
                  child: AnimatedOpacity(
                    opacity: _burst ? 1 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: const Text(
                      '🎉',
                      style: TextStyle(fontSize: 120, shadows: [Shadow(blurRadius: 24, color: Colors.black26)]),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 2, 4, 0),
            child: Row(
              children: [
                IconButton(
                  key: _cheerKey,
                  tooltip: 'Cheer',
                  onPressed: _cheer,
                  icon: Pop(
                    trigger: _pops,
                    scale: 1.6,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      transitionBuilder: (c, a) => RotationTransition(
                        turns: Tween(begin: -0.15, end: 0.0).animate(a),
                        child: ScaleTransition(scale: a, child: c),
                      ),
                      child: Icon(
                        _mine ? Icons.celebration : Icons.celebration_outlined,
                        key: ValueKey(_mine),
                        color: _mine ? _flame : SioColors.ink,
                        size: 28,
                      ),
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Share',
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(
                      text:
                          '${p['title']}${body.isNotEmpty ? '\n$body' : ''}\n— ${by['full_name'] ?? ''}'
                          '${handle(by).isNotEmpty ? ' (${handle(by)})' : ''} on SIO Connect',
                    ),
                  ),
                  icon: Icon(Icons.send_outlined, size: 26, color: SioColors.ink),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 200),
                  alignment: Alignment.topLeft,
                  child: _cheers > 0
                      ? AnimatedSwitcher(
                          duration: const Duration(milliseconds: 260),
                          transitionBuilder: (c, a) => SlideTransition(
                            position: Tween(begin: const Offset(0, 0.6), end: Offset.zero).animate(a),
                            child: FadeTransition(opacity: a, child: c),
                          ),
                          child: Text(
                            '$_cheers cheer${_cheers == 1 ? '' : 's'}',
                            key: ValueKey(_cheers),
                            style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
                          ),
                        )
                      : const SizedBox(width: double.infinity),
                ),
                if (body.isNotEmpty && p['kind'] != 'Note' || (p['kind'] == 'Note' && body.isNotEmpty)) ...[
                  const SizedBox(height: 4),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: '${handle(by).isNotEmpty ? by['username'] : by['full_name']}  ',
                          style: TextStyle(fontWeight: FontWeight.w800, color: SioColors.ink),
                        ),
                        TextSpan(text: body),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String timeAgo(dynamic v) {
  final d = parseDate(v);
  if (d == null) return '';
  final s = DateTime.now().difference(d);
  if (s.inMinutes < 1) return 'now';
  if (s.inMinutes < 60) return '${s.inMinutes}m';
  if (s.inHours < 24) return '${s.inHours}h';
  if (s.inDays < 7) return '${s.inDays}d';
  return fmtDate(v, 'd MMM');
}

/// Instagram-style ring: SIO blue → red when active (read today), grey when not.
class StoryRing extends StatelessWidget {
  const StoryRing({super.key, required this.child, this.active = true, this.size = 68, this.spin = false});
  final Widget child;
  final bool active;
  final double size;
  final bool spin; // slowly turning gradient (story row, my profile)

  @override
  Widget build(BuildContext context) => spin
      ? SpinRing(lit: active, size: size, child: child)
      : Container(
          width: size,
          height: size,
          padding: EdgeInsets.all(size > 60 ? 3 : 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: active
                ? const LinearGradient(
                    colors: [Color(0xFF1A62A8), Color(0xFF7C3AED), Color(0xFFC8202A), Color(0xFFF26B1D)],
                    begin: Alignment.bottomLeft,
                    end: Alignment.topRight,
                  )
                : null,
            color: active ? null : SioColors.greyBg,
          ),
          child: Container(
            padding: EdgeInsets.all(size > 60 ? 3 : 2),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
            child: FittedBox(child: child),
          ),
        );
}

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Friends’ posts')),
    floatingActionButton: AddFab(onPressed: () => newNotePost(context), tooltip: 'New post'),
    body: Loader<List<Map<String, dynamic>>>(
      load: () async => _list(await Api.call('${Api.m}feed')),
      builder: (context, posts) => [
        if (posts.isEmpty)
          const EmptyNote('Nothing yet. Earn a badge or keep a streak and post it, or add friends to see theirs.'),
        for (final p in posts) PostCard(post: p),
      ],
    ),
  );
}

// ---------------------------------------------------------------- unit board

class UnitBoardScreen extends StatelessWidget {
  const UnitBoardScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Unit challenge board')),
    body: Loader<Map<String, dynamic>>(
      load: () async => _map(await Api.call('${Api.m}unit_board')),
      builder: (context, b) {
        final units = _list(b['units']);
        return [
          Text(
            'Score = average of meeting attendance (last 30 days), members reading daily (last 7 days) and quiz marks '
            '(last 30 days)${b['area'] != null ? ' · ${b['area']} area' : ''}.',
            style: TextStyle(color: SioColors.textSecondary),
          ),
          const SizedBox(height: 12),
          for (final (i, u) in units.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SioPanel(
                color: u['mine'] == true ? SioColors.cardHigh : null,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 16,
                          backgroundColor: i == 0
                              ? _gold
                              : i == 1
                              ? const Color(0xFF9AA4AE)
                              : i == 2
                              ? const Color(0xFFB87333)
                              : SioColors.greyBg,
                          foregroundColor: i < 3 ? Colors.white : SioColors.grey,
                          child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '${u['unit']}${u['mine'] == true ? '  (my unit)' : ''}',
                            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        Text(
                          '${u['score']}',
                          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SioColors.blue),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    _bar('Attendance', _int(u['attendance'])),
                    _bar('Daily readers (${u['readers']} of ${u['members']})', _int(u['readers_pct'])),
                    _bar('Quiz (${u['quiz_takers']} took)', _int(u['quiz'])),
                  ],
                ),
              ),
            ),
        ];
      },
    ),
  );

  Widget _bar(String label, int pct) => Padding(
    padding: const EdgeInsets.only(top: 6),
    child: Row(
      children: [
        SizedBox(
          width: 150,
          child: Text(label, style: TextStyle(fontSize: 12, color: SioColors.textSecondary)),
        ),
        Expanded(child: ProgressBar(pct / 100)),
        SizedBox(
          width: 44,
          child: Text('$pct%', textAlign: TextAlign.right, style: const TextStyle(fontSize: 12)),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------- quizzes (leaders)

class QuizzesScreen extends StatelessWidget {
  const QuizzesScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Weekly quizzes')),
    floatingActionButton: AddFab(onPressed: () => push(context, const QuizFormScreen()), tooltip: 'New quiz'),
    body: Loader<List<Map<String, dynamic>>>(
      load: () async => _list(await Api.call('${Api.m}quizzes')),
      builder: (context, rows) => [
        if (rows.isEmpty) const EmptyNote('No quizzes yet. Tap + to make one.'),
        if (rows.isNotEmpty)
          PanelList(
            children: [
              for (final q in rows)
                ListTile(
                  title: Text('${q['title']}'),
                  subtitle: Text(
                    '${fmtDate(q['starts_on'], 'd MMM')} – ${fmtDate(q['ends_on'], 'd MMM')} · ${q['questions']} questions · '
                    '${q['attempts']} took${q['avg_pct'] != null ? ' · avg ${numOf(q['avg_pct']).round()}%' : ''}',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => push(context, QuizFormScreen(name: '${q['name']}')),
                ),
            ],
          ),
      ],
    ),
  );
}

class _Q {
  final question = TextEditingController();
  final options = List.generate(4, (_) => TextEditingController());
  final explanation = TextEditingController();
  int correct = 0;
}

class QuizFormScreen extends StatefulWidget {
  const QuizFormScreen({super.key, this.name});
  final String? name;

  @override
  State<QuizFormScreen> createState() => _QuizFormScreenState();
}

class _QuizFormScreenState extends State<QuizFormScreen> {
  final _title = TextEditingController();
  final _prize = TextEditingController();
  late DateTime _start = DateTime.now();
  late DateTime _end = DateTime.now().add(const Duration(days: 6));
  final List<_Q> _qs = [_Q()];
  bool _loading = false;
  bool _locked = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    if (widget.name != null) _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = _map(await Api.call('${Api.m}quiz', {'name': widget.name, 'edit': 1}));
      _title.text = '${q['title']}';
      _prize.text = '${q['prize'] ?? ''}';
      _start = parseDate(q['starts_on']) ?? _start;
      _end = parseDate(q['ends_on']) ?? _end;
      _qs.clear();
      for (final x in _list(q['questions'])) {
        final r = _Q();
        r.question.text = '${x['question'] ?? ''}';
        final opts = (x['options'] as List? ?? []);
        for (var i = 0; i < opts.length && i < 4; i++) {
          r.options[i].text = '${opts[i]}';
        }
        r.explanation.text = '${x['explanation'] ?? ''}';
        r.correct = _int(x['correct']).clamp(0, 3);
        _qs.add(r);
      }
      if (_qs.isEmpty) _qs.add(_Q());
    } catch (e) {
      if (mounted) toast(context, '$e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await run(context, () async {
      final r = _map(
        await Api.call('${Api.m}save_quiz', {
          'name': ?widget.name,
          'title': _title.text.trim(),
          'starts_on': apiDate(_start),
          'ends_on': apiDate(_end),
          'questions': jsonEncode([
            for (final q in _qs)
              {
                'question': q.question.text.trim(),
                'options': [for (final o in q.options) o.text.trim()],
                'correct': q.correct,
                'explanation': q.explanation.text.trim(),
              },
          ]),
        }),
      );
      _locked = r['locked'] == true;
    }, done: 'Quiz saved');
    if (mounted) setState(() => _busy = false);
    if (ok && mounted) {
      if (_locked) toast(context, 'People already took it, so the questions were kept as they were.');
      Navigator.pop(context);
    }
  }

  Future<void> _pick(bool start) async {
    final d = await showDatePicker(
      context: context,
      initialDate: start ? _start : _end,
      firstDate: DateTime(2025),
      lastDate: DateTime(2030),
    );
    if (d != null) setState(() => start ? _start = d : _end = d);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(widget.name == null ? 'New quiz' : 'Edit quiz')),
    body: _loading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
            children: [
              TextField(
                controller: _title,
                decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. Week 2: Seerah'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _prize,
                decoration: const InputDecoration(
                  labelText: 'Prize (optional)',
                  hintText: 'e.g. Book prize for the top 3, given at the unit meeting',
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(true),
                      icon: const Icon(Icons.event),
                      label: Text('From ${fmtDate(apiDate(_start), 'd MMM')}'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _pick(false),
                      icon: const Icon(Icons.event_busy),
                      label: Text('Till ${fmtDate(apiDate(_end), 'd MMM')}'),
                    ),
                  ),
                ],
              ),
              for (final (i, q) in _qs.indexed)
                Padding(
                  padding: const EdgeInsets.only(top: 14),
                  child: SioPanel(
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Text('Question ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                            const Spacer(),
                            if (_qs.length > 1)
                              IconButton(
                                icon: const Icon(Icons.delete_outline),
                                onPressed: () => setState(() => _qs.removeAt(i)),
                              ),
                          ],
                        ),
                        TextField(
                          controller: q.question,
                          maxLines: null,
                          decoration: const InputDecoration(labelText: 'Question'),
                        ),
                        for (var k = 0; k < 4; k++)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Row(
                              children: [
                                IconButton(
                                  tooltip: 'Right answer',
                                  icon: Icon(
                                    q.correct == k ? Icons.check_circle : Icons.circle_outlined,
                                    color: q.correct == k ? SioColors.green : SioColors.textSecondary,
                                  ),
                                  onPressed: () => setState(() => q.correct = k),
                                ),
                                Expanded(
                                  child: TextField(
                                    controller: q.options[k],
                                    decoration: InputDecoration(labelText: 'Option ${'ABCD'[k]}${k >= 2 ? ' (optional)' : ''}'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: q.explanation,
                          maxLines: null,
                          decoration: const InputDecoration(labelText: 'Explanation shown after (optional)'),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => setState(() => _qs.add(_Q())),
                icon: const Icon(Icons.add),
                label: const Text('Add question'),
              ),
              const SizedBox(height: 6),
              Text('Tap the circle next to the right answer.', style: TextStyle(color: SioColors.textSecondary, fontSize: 12)),
              const SizedBox(height: 16),
              FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Saving…' : 'Save quiz')),
            ],
          ),
  );
}

// ---------------------------------------------------------------- home card

/// Small card on the home screen: today's streak and a way in.
class JourneyHomeCard extends StatelessWidget {
  const JourneyHomeCard({super.key});

  @override
  Widget build(BuildContext context) => FutureBuilder<dynamic>(
    future: Api.call('${Api.m}journey'),
    builder: (context, snap) {
      if (!snap.hasData) return const SizedBox.shrink();
      final j = _map(snap.data);
      final rs = _map(j['reading_streak']);
      final n = _int(rs['current']);
      final done = rs['today'] == true;
      final quiz = j['quiz'] == null ? null : _map(j['quiz']);
      final requests = _int(j['friend_requests']);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: SioPanel(
          color: done ? const Color(0xFFFFEBDD) : SioColors.cardHigh,
          onTap: () => push(context, const JourneyScreen()),
          child: Row(
            children: [
              Icon(Icons.local_fire_department, color: done ? _flame : SioColors.blue, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      done
                          ? '$n-day streak · read today'
                          : (n > 0 ? '$n-day streak: read today to keep it' : 'Today’s ayah is waiting'),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      [
                        'My journey',
                        if (quiz != null && quiz['my_score'] == null) 'quiz open',
                        if (requests > 0) '$requests friend request${requests > 1 ? 's' : ''}',
                      ].join(' · '),
                      style: TextStyle(color: SioColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      );
    },
  );
}

/// Where a journey update (friend request, cheer, streak reminder) should open.
Widget? journeyNotice(dynamic n) {
  final t = '${n['title'] ?? ''}';
  if (t.contains('friend request')) return const FriendsScreen();
  if (t.contains('cheered your post')) return const PersonPage();
  if (t.startsWith('Keep your streak') || t.contains('nudged you')) return const JourneyScreen();
  return null;
}

/// After "I read it": the streak moment, every day (bigger words on milestones), with Share.
Future<void> celebrateRead(BuildContext context, Map<String, dynamic> r) {
  final n = _int(r['current']);
  final milestone = r['milestone'] == true;
  final title = n == 1
      ? 'Your streak has begun!'
      : milestone
      ? '$n days. MashaAllah!'
      : '$n days in a row';
  final sub = n == 1
      ? 'Come back tomorrow to make it 2 🔥'
      : milestone
      ? 'A milestone. Share it with your friends.'
      : 'See you tomorrow, insha Allah. Don’t break the chain!';
  return celebrate(
    context,
    number: n,
    title: title,
    subtitle: sub,
    onShare: () => showShareCard(
      context,
      kind: 'Streak',
      icon: Icons.local_fire_department,
      color: _flame,
      big: '$n',
      title: n == 1 ? 'Day 1 of my reading streak' : '$n-day reading streak',
      line: 'Reading a daily ayah / hadith with SIO Connect',
      person: AppState.i.me,
    ),
  );
}

/// How a role is shown to students: no internal words like Associate or Worker.
String? friendlyRole(dynamic role) => switch ('${role ?? ''}') {
  '' => null,
  'Associate' || 'Worker' => 'Student',
  'Member' => 'SIO Member',
  'Area Admin' => 'Area Team',
  final r => r,
};

/// After the quiz: me and my friends ranked, and the top of the area.
class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.q});
  final Map<String, dynamic> q;

  @override
  Widget build(BuildContext context) {
    final friends = _list(q['friends_board']);
    final top = _list(q['top']);
    Widget row(int i, Map<String, dynamic> x, {bool me = false}) => Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: me ? const Color(0xFFE8F0FA) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: SioColors.border),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              i < 3 ? ['🥇', '🥈', '🥉'][i] : '${i + 1}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
          ),
          Avatar('${x['full_name'] ?? ''}', radius: 16, photo: x['photo'], light: true),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              me ? 'You' : '${x['full_name'] ?? ''}',
              style: TextStyle(fontWeight: me ? FontWeight.w800 : FontWeight.w600),
            ),
          ),
          Text(
            '${x['score']}/${x['total']}',
            style: TextStyle(fontWeight: FontWeight.w900, color: SioColors.blue),
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: SioPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('🏆 You and your friends', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            if (friends.length <= 1)
              Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(
                  'None of your friends has taken it yet. Challenge them!',
                  style: TextStyle(color: SioColors.textSecondary),
                ),
              ),
            for (final (i, x) in friends.indexed) row(i, x, me: x['me'] == true),
            if (top.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text('Top in the area · ${q['takers'] ?? top.length} took it', style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              for (final (i, x) in top.indexed) row(i, x, me: x['member'] == AppState.i.me['member']),
            ],
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => SharePlus.instance.share(
                ShareParams(
                  text:
                      'I scored ${q['score']}/${q['total']} in this week’s SIO quiz “${q['title']}”. Can you beat me? 🏆\n${Links.share({'q': '${q['name']}'})}',
                ),
              ),
              icon: const Icon(Icons.share),
              label: const Text('Challenge friends on WhatsApp'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reading leaderboard: everyone ranked by reading streak (no weekly reset), with my unit and my friends.
class ReadingBoardScreen extends StatefulWidget {
  const ReadingBoardScreen({super.key});

  @override
  State<ReadingBoardScreen> createState() => _ReadingBoardScreenState();
}

class _ReadingBoardScreenState extends State<ReadingBoardScreen> {
  int _view = 0;

  Widget _row(BuildContext context, Map<String, dynamic> p, {bool pinned = false}) {
    final rank = _int(p['rank']);
    final me = p['me'] == true;
    final medal = rank == 1
        ? '🥇'
        : rank == 2
        ? '🥈'
        : rank == 3
        ? '🥉'
        : '#$rank';
    return Container(
      margin: EdgeInsets.only(bottom: pinned ? 0 : 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: me ? SioColors.blue.withValues(alpha: 0.10) : SioColors.card,
        borderRadius: BorderRadius.circular(14),
        border: me ? Border.all(color: SioColors.blue.withValues(alpha: 0.5)) : null,
      ),
      child: InkWell(
        onTap: me ? null : () => push(context, PersonPage(member: '${p['member']}')),
        child: Row(
          children: [
            SizedBox(
              width: 44,
              child: Text(
                medal,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: rank <= 3 ? 20 : 14, fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
            ),
            const SizedBox(width: 6),
            Avatar('${p['full_name'] ?? ''}', radius: 18, light: true, photo: p['photo']),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    me ? 'You' : '${p['full_name'] ?? ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    '${p['unit'] ?? ''} · ${_int(p['total'])} days read${p['today'] == true ? ' · ✅ today' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
                  ),
                ],
              ),
            ),
            Text('🔥 ${_int(p['streak'])}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Reading leaderboard')),
    body: Loader<Map<String, dynamic>>(
      cacheKey: 'reading_board',
      load: () async => _map(await Api.call('${Api.m}reading_board')),
      builder: (context, b) {
        final key = ['everyone', 'unit', 'friends'][_view];
        final board = _map(b[key]);
        final top = _list(board['top']);
        final me = board['me'] == null ? null : _map(board['me']);
        final inTop = top.any((p) => p['me'] == true);
        final ahead = me == null ? null : top.where((p) => _int(p['rank']) == _int(me['rank']) - 1).firstOrNull;
        return [
          if (me != null)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFF0E3F70), Color(0xFF1A62A8)]),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('YOUR RANK', style: TextStyle(color: Colors.white70, fontSize: 11, letterSpacing: 1.5)),
                      Text(
                        '#${_int(me['rank'])}',
                        style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w900),
                      ),
                      Text('of ${_int(board['out_of'])}', style: const TextStyle(color: Colors.white70)),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      _int(me['total']) == 0
                          ? 'Read today’s ayah to get on the board 🌱'
                          : _int(me['rank']) == 1
                          ? 'You’re on top! Keep reading every day to stay there 👑'
                          : ahead != null
                          ? 'Read ${(_int(ahead['streak']) - _int(me['streak']) + 1).clamp(1, 999)} more day(s) in a row to pass '
                                '${AppState.callName('${ahead['full_name'] ?? ''}')} 🚀'
                          : 'Read every day to climb. Your streak decides your rank 🔥',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, height: 1.35),
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              const ButtonSegment(value: 0, label: Text('Everyone')),
              ButtonSegment(value: 1, label: Text('${b['unit_name'] ?? 'Unit'}', overflow: TextOverflow.ellipsis)),
              const ButtonSegment(value: 2, label: Text('Friends')),
            ],
            selected: {_view},
            onSelectionChanged: (v) => setState(() => _view = v.first),
          ),
          const SizedBox(height: 14),
          if (_view == 2 && top.length <= 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SioTile(
                icon: Icons.group_add_outlined,
                title: 'Add friends to race them',
                subtitle: 'Find students from your unit',
                onTap: () => push(context, const FriendsScreen()),
              ),
            ),
          if (top.isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('Nobody is on the board yet. Read today’s ayah and be #1! 🌱', textAlign: TextAlign.center),
            ),
          for (final p in top) _row(context, p),
          if (me != null && !inTop) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Center(
                child: Text('⋮', style: TextStyle(fontSize: 20, color: SioColors.textSecondary)),
              ),
            ),
            _row(context, me, pinned: true),
          ],
          const SizedBox(height: 12),
          Text(
            'Ranked by your current reading streak, then total days read. One missed day a week is saved by your streak freeze 🧊',
            style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
          ),
        ];
      },
    ),
  );
}
