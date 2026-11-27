import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../fx.dart';
import '../home_widget_sync.dart';
import '../noor.dart';
import '../notify.dart';
import '../theme.dart';
import '../widgets.dart';
import 'me_screen.dart';
import 'social_screens.dart' show AyahReaderScreen, openAdminDashboard;

// The Today tab: Noor the sprout, the streak, and a Duolingo-style path of days. One ayah a day waters the
// sprout and lights up today's step; every 7th step is a chest (a week complete). Future days are locked.

Map<String, dynamic> _m(dynamic v) => Map<String, dynamic>.from((v ?? {}) as Map);
int _i(dynamic v) => numOf(v).toInt();

const _flame = Color(0xFFFF8A1F);
// SIO blues
const _deep = Color(0xFF0E3F70);
const _sio = Color(0xFF1A62A8);
const _mid = Color(0xFF2F7BC4);
const _light = Color(0xFF5AA6E8);
const _pale = Color(0xFFE6F2FD);
const _pale2 = Color(0xFFCFE5FA);
const _lockTop = Color(0xFFDCE7F2);
const _lockEdge = Color(0xFFC3D3E4);
const _lockInk = Color(0xFF8AA3BE);
const _gold = Color(0xFFFFC800);
const _goldEdge = Color(0xFFE5A400);

bool get _games => '${AppState.i.me['hide_games']}' != '1';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: SioColors.background,
    body: SafeArea(
      bottom: false,
      child: Loader<Map<String, dynamic>>(
        cacheKey: 'journey',
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 60),
        load: () async {
          final j = _m(await Api.call('${Api.m}journey'));
          final rs = _m(j['reading_streak']);
          Noor.myStreak = _i(rs['current']);
          final missed = _i(rs['current']) == 0 && _i(rs['best']) > 0;
          Notify.rememberStreak(_i(rs['current']), missed: missed, name: AppState.i.firstName, games: _games);
          if (rs['today'] == true) Notify.markReadToday(_i(rs['current']));
          HomeWidgetSync.reading(
            j['reading'] == null ? null : _m(j['reading']),
            streak: _i(rs['current']),
            readToday: rs['today'] == true,
            missed: missed,
            name: AppState.i.firstName,
            games: _games,
          );
          return j;
        },
        builder: (context, j) {
          final rs = _m(j['reading_streak']);
          Noor.myStreak = _i(rs['current']);
          return [
            _TopBar(rs: rs),
            const SizedBox(height: 10),
            _SproutHero(j: j),
            if (j['reading'] != null) ...[const SizedBox(height: 12), _TodayAyah(j: j)],
            const SizedBox(height: 12),
            _GrowthStrip(streak: _i(rs['current'])),
            const SizedBox(height: 18),
            _Path(j: j),
          ];
        },
      ),
    ),
  );
}

/// Duolingo-like top row: my face (→ my page), the streak flame, the weekly "rain day" that saves a streak.
class _TopBar extends StatelessWidget {
  const _TopBar({required this.rs});
  final Map<String, dynamic> rs;

  @override
  Widget build(BuildContext context) {
    final streak = _i(rs['current']);
    final today = rs['today'] == true;
    return Row(
      children: [
        Semantics(
          button: true,
          label: 'My page',
          child: InkResponse(
            onTap: () => push(context, const MeScreen()),
            child: ListenableBuilder(
              listenable: AppState.i,
              builder: (context, _) => Avatar(AppState.i.firstName, radius: 20, photo: AppState.i.me['photo']),
            ),
          ),
        ),
        const Spacer(),
        if (_games)
          Tooltip(
            message: today ? 'Streak: read today' : 'Read today to keep your streak',
            child: Row(
              children: [
                Icon(Icons.local_fire_department_rounded, color: today ? _flame : SioColors.greyBg, size: 30),
                const SizedBox(width: 2),
                Text(
                  '$streak',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: today ? _flame : SioColors.textSecondary),
                ),
              ],
            ),
          ),
        const SizedBox(width: 18),
        Tooltip(
          message: _i(rs['freeze_left']) > 0
              ? 'Rain day ready: if you miss one day this week, it rains and your sprout is saved'
              : 'This week’s rain day was used. A new one comes on Monday',
          triggerMode: TooltipTriggerMode.tap,
          child: Row(
            children: [
              Icon(
                Icons.water_drop_rounded,
                color: _i(rs['freeze_left']) > 0 ? const Color(0xFF1CB0F6) : SioColors.greyBg,
                size: 26,
              ),
              const SizedBox(width: 2),
              Text(
                '${_i(rs['freeze_left'])}',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  color: _i(rs['freeze_left']) > 0 ? const Color(0xFF1CB0F6) : SioColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        if (AppState.i.isLeader) ...[
          const SizedBox(width: 10),
          IconButton(
            tooltip: 'Admin dashboard',
            icon: Icon(Icons.dashboard_customize_outlined, color: SioColors.blue),
            onPressed: () => openAdminDashboard(context),
          ),
        ],
      ],
    );
  }
}

/// The sprout, what it says, and how far until it grows next.
class _SproutHero extends StatelessWidget {
  const _SproutHero({required this.j});
  final Map<String, dynamic> j;

  @override
  Widget build(BuildContext context) {
    final rs = _m(j['reading_streak']);
    final streak = _i(rs['current']);
    final mood = noorMood(readToday: rs['today'] == true, streak: streak, missedYesterday: streak == 0 && _i(rs['best']) > 0);
    final line = noorLine(mood, streak: streak, name: AppState.i.firstName, games: _games);
    final st = sproutStage(streak);
    final next = nextGrowth(streak);
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 14, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: mood == NoorMood.out ? [const Color(0xFFEDF1F5), const Color(0xFFDCE3EA)] : [_pale, _pale2],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Noor(mood: mood, size: 112),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(4),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(16),
                    ),
                    boxShadow: const [BoxShadow(color: Color(0x14000000), blurRadius: 6, offset: Offset(0, 2))],
                  ),
                  child: Text(
                    line,
                    style: const TextStyle(color: Color(0xFF1F1F23), fontWeight: FontWeight.w700, height: 1.3),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  mood == NoorMood.out ? 'Noor dried up' : 'Noor · ${sproutStageNames[st]}',
                  style: const TextStyle(color: _deep, fontWeight: FontWeight.w900, fontSize: 13),
                ),
                if (next != null && mood != NoorMood.out && _games) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _growthProgress(streak),
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      color: _sio,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next,
                    style: const TextStyle(color: _mid, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  double _growthProgress(int streak) {
    const at = [0, 3, 7, 30, 100];
    final st = sproutStage(streak);
    if (st >= 4) return 1;
    return ((streak - at[st]) / (at[st + 1] - at[st])).clamp(0.0, 1.0);
  }
}

/// Today's ayah right on the Today tab: the Arabic, the Malayalam meaning, and a button to read it.
class _TodayAyah extends StatelessWidget {
  const _TodayAyah({required this.j});
  final Map<String, dynamic> j;

  @override
  Widget build(BuildContext context) {
    final r = _m(j['reading']);
    final read = _m(j['reading_streak'])['today'] == true;
    final hadith = r['kind'] == 'Hadith';
    final ar = '${r['text_ar'] ?? ''}';
    final ml = '${r['text_ml'] ?? ''}';
    Future<void> open() async {
      HapticFeedback.selectionClick();
      await push(context, AyahReaderScreen(journey: j, games: _games));
      AppState.i.refreshAll();
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: open,
        child: Ink(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFF7FBFF), Color(0xFFE6F2FD)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: _pale2, width: 1.5),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    hadith ? 'HADITH OF THE DAY' : 'AYAH OF THE DAY',
                    style: const TextStyle(color: _sio, fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 12),
                  ),
                  const Spacer(),
                  Text(
                    '${r['reference'] ?? ''}',
                    style: const TextStyle(color: _lockInk, fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              if (ar.isNotEmpty) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    ar,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.right,
                    textDirection: TextDirection.rtl,
                    style: arabicStyle(color: _deep, size: 22),
                  ),
                ),
              ],
              if (ml.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  ml,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: malayalamStyle(color: _deep, size: 15, weight: FontWeight.w700),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: read
                    ? OutlinedButton.icon(
                        onPressed: open,
                        icon: const Icon(Icons.check_circle_rounded, color: _mid),
                        label: const Text('Read today · open again'),
                      )
                    : FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: _sio,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: const StadiumBorder(),
                        ),
                        onPressed: open,
                        icon: const Icon(Icons.water_drop_rounded),
                        label: const Text('Read & water Noor', style: TextStyle(fontWeight: FontWeight.w800)),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Noor's growth journey: the five sizes the sprout grows through, the current one highlighted, future ones
/// waiting in grey with the day they unlock.
class _GrowthStrip extends StatelessWidget {
  const _GrowthStrip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    const at = [1, 3, 7, 30, 100];
    final cur = sproutStage(streak);
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 12, 10, 10),
      decoration: BoxDecoration(
        color: SioColors.card,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _pale2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 6, bottom: 6),
            child: Text(
              'NOOR’S GROWTH',
              style: TextStyle(color: _sio, fontWeight: FontWeight.w900, letterSpacing: 1.3, fontSize: 12),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Expanded(
                  child: Column(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: i == cur ? _pale : Colors.transparent,
                          border: Border.all(color: i == cur ? _sio : Colors.transparent, width: 2.5),
                        ),
                        child: Opacity(
                          opacity: i <= cur ? 1 : 0.35,
                          child: ColorFiltered(
                            colorFilter: i <= cur
                                ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                                : const ColorFilter.matrix([
                                    0.33, 0.33, 0.33, 0, 0, //
                                    0.33, 0.33, 0.33, 0, 0,
                                    0.33, 0.33, 0.33, 0, 0,
                                    0, 0, 0, 1, 0,
                                  ]),
                            child: Noor(mood: NoorMood.happy, size: 52, stage: i, animate: i == cur),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (i < cur)
                        const Icon(Icons.check_circle_rounded, size: 16, color: _light)
                      else
                        Text(
                          i == cur ? 'Now' : 'Day ${at[i]}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w800,
                            color: i == cur ? _sio : (i < cur ? _light : _lockInk),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The week as a winding garden trail: a soft blue road joins the steps, the walked part darker, little
/// plants and flowers along the edges, a chest on day 7, and a signpost where Noor grows to a new size.
class _Path extends StatelessWidget {
  const _Path({required this.j});
  final Map<String, dynamic> j;

  @override
  Widget build(BuildContext context) {
    final rs = _m(j['reading_streak']);
    final streak = _i(rs['current']);
    final readToday = rs['today'] == true;
    final dayNo = readToday ? math.max(streak, 1) : streak + 1; // the step that is "today"
    final week = (dayNo - 1) ~/ 7; // 0-based
    final first = week * 7 + 1;
    final reading = j['reading'] == null ? null : _m(j['reading']);
    final kind = reading?['kind'] == 'Hadith' ? 'hadith' : 'ayah';

    _State st(int d) => d < dayNo || (d == dayNo && readToday)
        ? _State.done
        : d == dayNo
        ? _State.today
        : _State.locked;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WeekBanner(week: week),
        const SizedBox(height: 8),
        _Trail(days: [for (var k = 0; k < 7; k++) first + k], state: st, todayDay: dayNo, kind: kind, j: j),
        const SizedBox(height: 6),
        _WeekBanner(week: week + 1, locked: true),
        const SizedBox(height: 8),
        Opacity(
          opacity: 0.55,
          child: _Trail(
            days: [for (var k = 0; k < 3; k++) first + 7 + k],
            state: (_) => _State.locked,
            todayDay: -1,
            kind: kind,
            j: j,
            fadeOut: true,
          ),
        ),
      ],
    );
  }
}

class _WeekBanner extends StatelessWidget {
  const _WeekBanner({required this.week, this.locked = false});
  final int week;
  final bool locked;

  @override
  Widget build(BuildContext context) {
    final from = week * 7 + 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 12, 12, 12),
      decoration: BoxDecoration(
        gradient: locked
            ? null
            : const LinearGradient(colors: [_sio, _mid], begin: Alignment.centerLeft, end: Alignment.centerRight),
        color: locked ? _lockTop : null,
        borderRadius: BorderRadius.circular(18),
        border: Border(bottom: BorderSide(color: locked ? _lockEdge : _deep, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEK ${week + 1}',
                  style: TextStyle(
                    color: locked ? _lockInk : Colors.white.withValues(alpha: 0.8),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 12.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Days $from–${from + 6}',
                  style: TextStyle(color: locked ? _lockInk : Colors.white, fontWeight: FontWeight.w900, fontSize: 20),
                ),
              ],
            ),
          ),
          if (locked)
            const Icon(Icons.lock_rounded, color: _lockInk)
          else
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Noor(mood: NoorMood.happy, size: 44, stage: sproutStage(from + 6), animate: false),
            ),
        ],
      ),
    );
  }
}

enum _State { done, today, locked }

class _Trail extends StatelessWidget {
  const _Trail({
    required this.days,
    required this.state,
    required this.todayDay,
    required this.kind,
    required this.j,
    this.fadeOut = false,
  });
  final List<int> days;
  final _State Function(int day) state;
  final int todayDay;
  final String kind;
  final Map<String, dynamic> j;
  final bool fadeOut;

  static const _gap = 112.0;
  static double _off(int k) => math.sin(k * math.pi / 3) * 78;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, c) {
      final w = c.maxWidth;
      final cx = w / 2;
      final todayIdx = days.indexOf(todayDay);
      // extra room above today's node for its START bubble
      final ys = <double>[];
      var y = 46.0;
      for (var k = 0; k < days.length; k++) {
        if (k == todayIdx) y += 34;
        ys.add(y);
        y += _gap;
      }
      final height = y - _gap + 70;
      final pts = [for (var k = 0; k < days.length; k++) Offset(cx + _off(k), ys[k])];
      final walked = todayIdx >= 0
          ? todayIdx
          : (state(days.first) == _State.done ? days.length - 1 : -1); // last point the road is "walked" to
      final rs = _m(j['reading_streak']);
      final streak = _i(rs['current']);
      final mood = noorMood(readToday: rs['today'] == true, streak: streak, missedYesterday: streak == 0 && _i(rs['best']) > 0);

      final kids = <Widget>[
        Positioned.fill(
          child: CustomPaint(
            painter: _TrailPainter(points: pts, walked: walked, fadeOut: fadeOut, seed: days.first),
          ),
        ),
      ];
      for (var k = 0; k < days.length; k++) {
        final d = days[k];
        final s = state(d);
        final today = s == _State.today;
        final size = today ? 86.0 : 70.0;
        final p = pts[k];
        // the step
        kids.add(
          Positioned(
            left: p.dx - size / 2,
            top: p.dy - size / 2,
            child: _Node(day: d, state: s, chest: d % 7 == 0, size: size, kind: kind, j: j),
          ),
        );
        // "START" bubble above today's step
        if (today) {
          kids.add(
            Positioned(
              left: p.dx - 90,
              width: 180,
              top: p.dy - size / 2 - 46,
              child: const Center(child: _StartBubble()),
            ),
          );
        }
        // day label
        kids.add(
          Positioned(
            left: p.dx - 50,
            width: 100,
            top: p.dy + size / 2 + 2,
            child: Text(
              d % 7 == 0 ? 'Day $d · chest' : 'Day $d',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w800, color: s == _State.locked ? _lockInk : _sio),
            ),
          ),
        );
        // beside the step: Noor on today's step; a signpost where Noor grows to a new size
        final side = _off(k) > 1 ? -1.0 : 1.0; // the roomier side
        final grows = d > 1 && sproutStage(d) != sproutStage(d - 1);
        if (today || (todayIdx < 0 && k == 0 && s == _State.done && !fadeOut)) {
          kids.add(
            Positioned(
              left: side > 0 ? w - 128 : 8,
              width: 120,
              top: p.dy - 68,
              child: Noor(mood: s == _State.done ? NoorMood.happy : mood, size: 116),
            ),
          );
        } else if (grows) {
          kids.add(
            Positioned(
              left: side > 0 ? w - 118 : 6,
              width: 112,
              top: p.dy - 52,
              child: _GrowSign(stage: sproutStage(d), reached: s == _State.done),
            ),
          );
        }
      }
      return SizedBox(
        height: height,
        child: Stack(clipBehavior: Clip.none, children: kids),
      );
    },
  );
}

class _StartBubble extends StatefulWidget {
  const _StartBubble();

  @override
  State<_StartBubble> createState() => _StartBubbleState();
}

class _StartBubbleState extends State<_StartBubble> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _bob,
    builder: (context, child) => Transform.translate(offset: Offset(0, -4 * _bob.value), child: child),
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _pale2, width: 2),
        boxShadow: const [BoxShadow(color: Color(0x1A0E3F70), blurRadius: 8, offset: Offset(0, 3))],
      ),
      child: const Text(
        'START',
        style: TextStyle(color: _sio, fontWeight: FontWeight.w900, fontSize: 14, letterSpacing: 1.2),
      ),
    ),
  );
}

/// A little wooden signpost: "Day 7 · Noor grows leaves".
class _GrowSign extends StatelessWidget {
  const _GrowSign({required this.stage, required this.reached});
  final int stage;
  final bool reached;

  @override
  Widget build(BuildContext context) => Opacity(
    opacity: reached ? 1 : 0.85,
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Noor(mood: NoorMood.happy, size: 64, stage: stage, animate: false),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: reached ? _pale : Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _pale2, width: 1.5),
          ),
          child: Text(
            reached ? 'Grew! ✓' : sproutStageNames[stage],
            textAlign: TextAlign.center,
            style: const TextStyle(color: _sio, fontWeight: FontWeight.w900, fontSize: 11),
          ),
        ),
      ],
    ),
  );
}

/// The soft road between the steps, plus grass, flowers and pebbles along it.
class _TrailPainter extends CustomPainter {
  _TrailPainter({required this.points, required this.walked, required this.fadeOut, required this.seed});
  final List<Offset> points;
  final int walked; // index of the last walked step (-1 = none)
  final bool fadeOut;
  final int seed;

  Path _road(int from, int to) {
    final path = Path()..moveTo(points[from].dx, points[from].dy);
    for (var i = from; i < to; i++) {
      final a = points[i];
      final b = points[i + 1];
      final my = (a.dy + b.dy) / 2;
      path.cubicTo(a.dx, my, b.dx, my, b.dx, b.dy);
    }
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    // a little lead-in above the first step
    final lead = Path()
      ..moveTo(points.first.dx, points.first.dy - 50)
      ..lineTo(points.first.dx, points.first.dy);
    final all = _road(0, points.length - 1)..addPath(lead, Offset.zero);
    if (fadeOut) {
      all.lineTo(points.last.dx, points.last.dy + 60);
    }
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 40
      ..color = const Color(0xFFD7E7F7);
    final top = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 32
      ..color = const Color(0xFFEAF3FC);
    canvas.drawPath(all, edge);
    canvas.drawPath(all, top);
    if (walked > 0) {
      final w = _road(0, walked);
      canvas.drawPath(w, edge..color = const Color(0xFF9CC8EF));
      canvas.drawPath(w, top..color = const Color(0xFFBFDDF7));
    }
    // dashed centre line
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = Colors.white;
    for (final m in all.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 22) {
        canvas.drawPath(m.extractPath(d, math.min(d + 9, m.length)), dash);
      }
    }
    // decorations between the steps, on the side away from the bend
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      final mid = Offset((a.dx + b.dx) / 2, (a.dy + b.dy) / 2);
      final away = mid.dx > size.width / 2 ? -1.0 : 1.0;
      final at = Offset(mid.dx + away * 92, mid.dy);
      if (at.dx < 14 || at.dx > size.width - 14) continue;
      final faded = i >= walked && walked >= 0 || walked < 0;
      switch ((seed + i) % 3) {
        case 0:
          _grass(canvas, at, faded);
        case 1:
          _flower(canvas, at, faded);
        default:
          _pebbles(canvas, at, faded);
      }
    }
  }

  void _grass(Canvas c, Offset o, bool faded) {
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4
      ..color = faded ? const Color(0xFFB7D7A8) : const Color(0xFF6BBF59);
    for (final (dx, h, lean) in [(-8.0, 16.0, -6.0), (0.0, 22.0, 0.0), (8.0, 15.0, 6.0)]) {
      final path = Path()
        ..moveTo(o.dx + dx, o.dy + 8)
        ..quadraticBezierTo(o.dx + dx, o.dy + 8 - h / 2, o.dx + dx + lean, o.dy + 8 - h);
      c.drawPath(path, p);
    }
  }

  void _flower(Canvas c, Offset o, bool faded) {
    final stem = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..color = faded ? const Color(0xFFB7D7A8) : const Color(0xFF6BBF59);
    c.drawLine(o.translate(0, 12), o.translate(0, -2), stem);
    final petal = Paint()..color = faded ? const Color(0xFFF2D9DD) : const Color(0xFFF7A1B5);
    for (var k = 0; k < 5; k++) {
      final a = k * 2 * math.pi / 5;
      c.drawCircle(o.translate(math.cos(a) * 6, -6 + math.sin(a) * 6), 4.6, petal);
    }
    c.drawCircle(o.translate(0, -6), 3.6, Paint()..color = faded ? const Color(0xFFF6E7A6) : const Color(0xFFFFC83D));
  }

  void _pebbles(Canvas c, Offset o, bool faded) {
    final p = Paint()..color = faded ? const Color(0xFFE1E8EF) : const Color(0xFFC9D6E3);
    c.drawOval(Rect.fromCenter(center: o.translate(-7, 4), width: 16, height: 10), p);
    c.drawOval(Rect.fromCenter(center: o.translate(7, 7), width: 11, height: 7), p);
    c.drawOval(Rect.fromCenter(center: o.translate(4, -3), width: 8, height: 6), p);
  }

  @override
  bool shouldRepaint(covariant _TrailPainter old) => old.walked != walked || old.points != points;
}

class _Node extends StatelessWidget {
  const _Node({
    required this.day,
    required this.state,
    required this.chest,
    required this.size,
    required this.kind,
    required this.j,
  });
  final int day;
  final _State state;
  final bool chest;
  final double size;
  final String kind;
  final Map<String, dynamic> j;

  int _todayStep() {
    final rs = _m(j['reading_streak']);
    final streak = _i(rs['current']);
    return rs['today'] == true ? math.max(streak, 1) : streak + 1;
  }

  Future<void> _tap(BuildContext context) async {
    HapticFeedback.selectionClick();
    if (state == _State.today || (state == _State.done && day == _todayStep())) {
      await push(context, AyahReaderScreen(journey: j, games: _games));
      AppState.i.refreshAll();
    } else if (state == _State.done) {
      toast(context, 'Day $day done ✓ MashaAllah!');
    } else {
      toast(context, chest ? 'Reach day $day to open this chest 🎁' : 'Come back on day $day 🌱');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = state;
    final today = s == _State.today;
    final (Color top, Color edge) = switch (s) {
      _State.done when chest => (_gold, _goldEdge),
      _State.done => (_light, _mid),
      _State.today => (_sio, _deep),
      _State.locked => (_lockTop, _lockEdge),
    };
    final icon = chest
        ? Text(
            s == _State.done ? '🎉' : '🎁',
            style: TextStyle(fontSize: size * 0.4, color: s == _State.locked ? Colors.black38 : null),
          )
        : Icon(
            switch (s) {
              _State.done => Icons.check_rounded,
              _State.today => kind == 'hadith' ? Icons.format_quote_rounded : Icons.menu_book_rounded,
              _State.locked => Icons.lock_rounded,
            },
            color: s == _State.locked ? _lockInk : Colors.white,
            size: size * 0.44,
          );
    Widget disc = SizedBox(
      width: size,
      height: size,
      child: Stack(
        children: [
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: size * 0.9,
            child: DecoratedBox(
              decoration: BoxDecoration(color: edge, shape: BoxShape.circle),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            top: 0,
            height: size * 0.9,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.45),
                  radius: 0.9,
                  colors: [Color.lerp(top, Colors.white, 0.28)!, top],
                ),
              ),
              child: Center(child: icon),
            ),
          ),
        ],
      ),
    );
    if (today) {
      disc = Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [BoxShadow(color: _sio.withValues(alpha: 0.35), blurRadius: 18, spreadRadius: 4)],
        ),
        child: disc,
      );
    }
    return Semantics(
      button: true,
      label: 'Day $day${today ? ', today' : ''}',
      child: Squish(onTap: () => _tap(context), child: disc),
    );
  }
}

/// After today's ayah: Noor celebrates, grows if it reached a new stage, and a chest opens every 7th day.
Future<void> celebrateSprout(BuildContext context, Map<String, dynamic> r) {
  final n = _i(r['current']);
  final grew = n > 0 && sproutStage(n) != sproutStage(n - 1);
  final chest = n > 0 && n % 7 == 0;
  HapticFeedback.heavyImpact();
  Noor.myStreak = n;
  final title = n <= 1
      ? 'You planted Noor! 🌱'
      : grew
      ? 'Noor grew! ${sproutStageNames[sproutStage(n)]}'
      : chest
      ? 'Week ${n ~/ 7} complete! 🎁'
      : 'Day $n done!';
  final sub = n <= 1
      ? 'Water it with one ayah every day and watch it grow.'
      : grew
      ? 'MashaAllah, $n days in a row. Keep going!'
      : chest
      ? '$n days in a row. Noor is so proud of you.'
      : (nextGrowth(n) ?? 'Noor is in full bloom. See you tomorrow!');
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 380),
    transitionBuilder: (context, a, _, child) => FadeTransition(
      opacity: a,
      child: ScaleTransition(
        scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
        child: child,
      ),
    ),
    pageBuilder: (ctx, _, _) => _SproutCelebration(n: n, title: title, sub: sub),
  );
}

class _SproutCelebration extends StatefulWidget {
  const _SproutCelebration({required this.n, required this.title, required this.sub});
  final int n;
  final String title;
  final String sub;

  @override
  State<_SproutCelebration> createState() => _SproutCelebrationState();
}

class _SproutCelebrationState extends State<_SproutCelebration> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      for (final x in [0.25, 0.5, 0.75]) {
        burst(context, at: Offset(size.width * x, size.height * 0.36), count: 14, emojis: const ['💧', '🌱', '✨', '🎉']);
      }
    });
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: Colors.transparent,
      child: Container(
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Colors.white, _pale2], begin: Alignment.topCenter, end: Alignment.bottomCenter),
          borderRadius: BorderRadius.circular(28),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Noor(mood: NoorMood.celebrate, size: 170, stage: sproutStage(widget.n)),
            if (_games && widget.n > 0)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.local_fire_department_rounded, color: _flame, size: 34),
                  Text(
                    '${widget.n}',
                    style: const TextStyle(fontSize: 34, fontWeight: FontWeight.w900, color: _flame),
                  ),
                ],
              ),
            const SizedBox(height: 4),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: _deep),
            ),
            const SizedBox(height: 6),
            Text(
              widget.sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: _mid, height: 1.35),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _sio,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('CONTINUE', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1)),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
