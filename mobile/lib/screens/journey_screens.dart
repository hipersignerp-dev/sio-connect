import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:material_ui/material_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../api.dart';
import '../app_state.dart';
import '../theme.dart';
import '../widgets.dart';

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
  const JourneyScreen({super.key});

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
      AppState.i.refreshAll();
      if (!mounted) return;
      final n = _int(r['current']);
      if (r['milestone'] == true || n == 1) {
        showShareCard(
          context,
          kind: 'Streak',
          icon: Icons.local_fire_department,
          color: _flame,
          big: '$n',
          title: n == 1 ? 'Day 1 of my reading streak' : '$n-day reading streak',
          line: 'Reading a daily ayah / hadith with SIO Connect',
          person: j['me'],
        );
      } else {
        toast(context, '🔥 $n days in a row. See you tomorrow!');
      }
    } on ApiException catch (e) {
      if (mounted) toast(context, e.message);
    } finally {
      if (mounted) setState(() => _reading = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('My journey'),
      actions: [
        IconButton(
          tooltip: 'My page',
          icon: const Icon(Icons.account_circle_outlined),
          onPressed: () => push(context, const PersonPage()),
        ),
      ],
    ),
    body: Loader<Map<String, dynamic>>(
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
              child: const Row(
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
          const SizedBox(height: 12),
          if (reading != null) _ReadingCard(reading: reading, done: rs['today'] == true, busy: _reading, onRead: () => _read(j)),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _Stat(Icons.groups, '${_int(_map(j['attendance'])['current'])}', 'meetings in a row', SioColors.blue),
              ),
              const SizedBox(width: 8),
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
                  const CircleAvatar(backgroundColor: SioColors.purple, foregroundColor: Colors.white, child: Icon(Icons.quiz)),
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
                          style: const TextStyle(color: SioColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                  quiz['my_score'] != null
                      ? const Icon(Icons.check_circle, color: SioColors.green)
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
            action: Text('$earned earned', style: const TextStyle(color: SioColors.textSecondary)),
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
            icon: Icons.dynamic_feed_outlined,
            title: 'Friends’ posts',
            subtitle: 'Achievements from you and your friends',
            onTap: () => push(context, const FeedScreen()),
          ),
          SioTile(
            icon: Icons.leaderboard_outlined,
            title: 'Unit challenge board',
            subtitle: 'Attendance, daily readers and quiz, unit against unit',
            onTap: () => push(context, const UnitBoardScreen()),
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
            if (done) const Icon(Icons.check_circle, color: SioColors.green),
          ],
        ),
        const SizedBox(height: 14),
        if ('${reading['text_ar'] ?? ''}'.isNotEmpty) ...[
          Text(
            '${reading['text_ar']}',
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: const TextStyle(fontSize: 22, height: 1.7, color: SioColors.ink),
          ),
          const SizedBox(height: 10),
        ],
        Text(
          '“${reading['text_en']}”',
          style: const TextStyle(fontSize: 18, height: 1.45, fontWeight: FontWeight.w600, color: SioColors.ink),
        ),
        if ('${reading['text_ml'] ?? ''}'.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text('${reading['text_ml']}', style: const TextStyle(fontSize: 16, height: 1.5)),
        ],
        const SizedBox(height: 8),
        Text('— ${reading['reference'] ?? ''}', style: const TextStyle(color: SioColors.textSecondary)),
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
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: SioColors.ink),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: SioColors.textSecondary),
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
          color: b['earned'] == true ? const Color(0xFFFFF4DC) : SioColors.card,
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
              Text('${b['progress']} of ${b['goal']}', style: const TextStyle(color: SioColors.textSecondary)),
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
          const Text(
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
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final caption = await _askCaption(ctx);
                      if (caption == null || !ctx.mounted) return;
                      final ok = await run(
                        ctx,
                        () => Api.call('${Api.m}create_post', {
                          'kind': kind,
                          'badge': badge,
                          'title': title,
                          'body': caption.isEmpty ? line : caption,
                        }),
                        done: 'Posted on your page',
                      );
                      if (ok && ctx.mounted) Navigator.pop(ctx);
                    },
                    icon: const Icon(Icons.post_add),
                    label: const Text('Post on my page'),
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

Future<String?> _askCaption(BuildContext context) {
  final c = TextEditingController();
  return showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Add a caption'),
      content: TextField(
        controller: c,
        maxLines: 3,
        maxLength: 300,
        decoration: const InputDecoration(hintText: 'Optional: say something to your friends'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('Post')),
      ],
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
      showShareCard(
        context,
        kind: 'Quiz',
        badge: full ? 'quiz_full' : null,
        icon: full ? Icons.emoji_events : Icons.quiz,
        color: full ? _gold : SioColors.purple,
        big: '${r['score']}/${r['total']}',
        title: full ? 'Full marks in the weekly quiz!' : 'I scored ${r['score']}/${r['total']} in the weekly quiz',
        line: '${_q!['title']}',
        person: AppState.i.me,
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
              Text('${x['explanation']}', style: const TextStyle(color: SioColors.textSecondary)),
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
                          icon: const Icon(Icons.close, color: SioColors.danger),
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
                    trailing: _DuoFlame(together: _map(p['together'])),
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
      style: const TextStyle(color: SioColors.textSecondary),
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
  const PersonPage({super.key, this.member});
  final String? member; // null = my page

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(member == null ? 'My page' : 'Profile')),
    body: Loader<Map<String, dynamic>>(
      load: () async => _map(await Api.call('${Api.m}profile', {'member': ?member})),
      builder: (context, p) {
        final st = '${_map(p['friend'])['state']}';
        final posts = _list(p['posts']);
        final badges = _list(p['badges']);
        final self = st == 'self';
        return [
          const SizedBox(height: 8),
          Center(child: Avatar('${p['full_name']}', radius: 46, photo: p['photo'])),
          const SizedBox(height: 10),
          Text(
            '${p['full_name']}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SioColors.ink),
          ),
          Text(
            [
              if (handle(p).isNotEmpty) handle(p),
              if (p['member_role'] != null) '${p['member_role']}',
              if (p['unit'] != null) '${p['unit']}',
            ].join(' · '),
            textAlign: TextAlign.center,
            style: const TextStyle(color: SioColors.textSecondary),
          ),
          const SizedBox(height: 12),
          if (self)
            Center(
              child: OutlinedButton.icon(
                onPressed: () => pickUsername(context, '${p['username'] ?? ''}'),
                icon: const Icon(Icons.alternate_email, size: 18),
                label: Text(handle(p).isEmpty ? 'Choose username' : 'Change username'),
              ),
            )
          else
            Center(
              child: _FriendButton(member: '${p['member']}', state: st),
            ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _Stat(Icons.local_fire_department, '${_int(_map(p['reading'])['current'])}', 'day streak', _flame)),
              const SizedBox(width: 8),
              Expanded(child: _Stat(Icons.emoji_events, '${badges.length}', 'badges', _gold)),
              const SizedBox(width: 8),
              Expanded(child: _Stat(Icons.people_alt, '${p['friends'] ?? 0}', 'friends', SioColors.blue)),
            ],
          ),
          if (p['together'] != null) ...[
            const SizedBox(height: 8),
            SioPanel(
              color: const Color(0xFFFFEBDD),
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department, color: _flame, size: 36),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Your streak together: ${_int(_map(p['together'])['current'])} days '
                      '(best ${_int(_map(p['together'])['best'])}). Keep reading every day, both of you.',
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (badges.isNotEmpty) ...[const SectionTitle('Badges'), _BadgeGrid(badges: badges, person: p, readOnly: !self)],
          SectionTitle(
            'Posts',
            action: self
                ? TextButton.icon(
                    onPressed: () => _newNote(context),
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Post'),
                  )
                : null,
          ),
          if (!self && st != 'friends') const EmptyNote('Become friends to see their posts.'),
          if ((self || st == 'friends') && posts.isEmpty) const EmptyNote('No posts yet.'),
          for (final x in posts) PostCard(post: {...x, 'by': p}),
        ];
      },
    ),
  );
}

Future<void> _newNote(BuildContext context) async {
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

class PostCard extends StatefulWidget {
  const PostCard({super.key, required this.post});
  final Map<String, dynamic> post;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late int _cheers = _int(widget.post['cheers']);
  late bool _mine = widget.post['my_cheer'] == true;

  @override
  Widget build(BuildContext context) {
    final p = widget.post;
    final by = _map(p['by']);
    final kind = '${p['kind']}';
    final (icon, color) = switch (kind) {
      'Badge' => (Icons.emoji_events, _gold),
      'Streak' => (Icons.local_fire_department, _flame),
      'Quiz' => (Icons.quiz, SioColors.purple),
      _ => (Icons.edit_note, SioColors.blue),
    };
    final isMe = by['member'] == AppState.i.me['member'];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SioPanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                InkWell(
                  onTap: () => push(context, PersonPage(member: '${by['member']}')),
                  child: Avatar('${by['full_name'] ?? ''}', radius: 18, light: true, photo: by['photo']),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('${by['full_name'] ?? ''}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(
                        fmtDate(p['creation'], 'd MMM, h:mm a'),
                        style: const TextStyle(color: SioColors.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (isMe || AppState.i.can('approve_members'))
                  IconButton(
                    tooltip: 'Delete',
                    icon: const Icon(Icons.delete_outline, size: 20),
                    onPressed: () async {
                      if (await _confirm(context, 'Delete this post?') && context.mounted) {
                        run(context, () => Api.call('${Api.m}post_action', {'name': p['name'], 'action': 'delete'}));
                      }
                    },
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (kind != 'Note') ...[
                  CircleAvatar(radius: 22, backgroundColor: color, foregroundColor: Colors.white, child: Icon(icon)),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${p['title']}',
                        style: TextStyle(fontSize: kind == 'Note' ? 15 : 16, fontWeight: kind == 'Note' ? null : FontWeight.w700),
                      ),
                      if ('${p['body'] ?? ''}'.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text('${p['body']}', style: const TextStyle(color: SioColors.text)),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () async {
                    try {
                      final r = _map(await Api.call('${Api.m}post_action', {'name': p['name']}));
                      if (mounted) {
                        setState(() {
                          _cheers = _int(r['cheers']);
                          _mine = r['my_cheer'] == true;
                        });
                      }
                    } on ApiException catch (e) {
                      if (context.mounted) toast(context, e.message);
                    }
                  },
                  icon: Icon(_mine ? Icons.celebration : Icons.celebration_outlined, color: _mine ? _flame : null),
                  label: Text(_cheers == 0 ? 'Cheer' : '$_cheers cheer${_cheers == 1 ? '' : 's'}'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Friends’ posts')),
    floatingActionButton: AddFab(onPressed: () => _newNote(context), tooltip: 'New post'),
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
            style: const TextStyle(color: SioColors.textSecondary),
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
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: SioColors.blue),
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
          child: Text(label, style: const TextStyle(fontSize: 12, color: SioColors.textSecondary)),
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
              const Text(
                'Tap the circle next to the right answer.',
                style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
              ),
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
                      style: const TextStyle(color: SioColors.textSecondary),
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
  if (t.startsWith('Keep your streak')) return const JourneyScreen();
  return null;
}
