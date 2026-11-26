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
const _done = Color(0xFF58CC02);
const _doneEdge = Color(0xFF46A302);
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
          return [_TopBar(rs: rs), const SizedBox(height: 10), _SproutHero(j: j), const SizedBox(height: 18), _Path(j: j)];
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
          colors: switch (mood) {
            NoorMood.happy || NoorMood.celebrate => [const Color(0xFFE9F9DA), const Color(0xFFD3F2B8)],
            NoorMood.worried || NoorMood.urgent => [const Color(0xFFFFF1E0), const Color(0xFFFFE0C2)],
            NoorMood.out => [const Color(0xFFEDE8DE), const Color(0xFFDCD3C2)],
            _ => [const Color(0xFFE6F2FD), const Color(0xFFCFE5FA)],
          },
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
                  style: const TextStyle(color: Color(0xFF2E5E1E), fontWeight: FontWeight.w900, fontSize: 13),
                ),
                if (next != null && mood != NoorMood.out && _games) ...[
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: _growthProgress(streak),
                      minHeight: 8,
                      backgroundColor: Colors.white.withValues(alpha: 0.7),
                      color: _done,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    next,
                    style: const TextStyle(color: Color(0xFF4A5A40), fontSize: 12, fontWeight: FontWeight.w600),
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

/// The week as a winding path: done days, today, locked days, a chest on day 7.
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

    Widget banner(int w, {bool locked = false}) => Container(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
      decoration: BoxDecoration(
        color: locked ? SioColors.greyBg : _done,
        borderRadius: BorderRadius.circular(18),
        border: Border(bottom: BorderSide(color: locked ? SioColors.border : _doneEdge, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'WEEK ${w + 1}',
                  style: TextStyle(
                    color: locked ? SioColors.textSecondary : Colors.white.withValues(alpha: 0.85),
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.4,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Days ${w * 7 + 1}–${w * 7 + 7}',
                  style: TextStyle(
                    color: locked ? SioColors.textSecondary : Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                ),
              ],
            ),
          ),
          Icon(locked ? Icons.lock_rounded : Icons.spa_rounded, color: locked ? SioColors.textSecondary : Colors.white),
        ],
      ),
    );

    final nodes = <Widget>[];
    for (var k = 0; k < 7; k++) {
      final d = first + k;
      final _State s;
      if (d < dayNo || (d == dayNo && readToday)) {
        s = _State.done;
      } else if (d == dayNo) {
        s = _State.today;
      } else {
        s = _State.locked;
      }
      nodes.add(
        _Step(
          day: d,
          state: s,
          chest: d % 7 == 0,
          offset: math.sin(k * math.pi / 3) * 70,
          kind: kind,
          showSprout: d == dayNo,
          j: j,
        ),
      );
    }
    final nextWeek = <Widget>[
      for (var k = 0; k < 3; k++)
        Opacity(
          opacity: 0.55 - k * 0.15,
          child: _Step(
            day: first + 7 + k,
            state: _State.locked,
            chest: false,
            offset: math.sin(k * math.pi / 3) * 70,
            kind: kind,
            showSprout: false,
            j: j,
          ),
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        banner(week),
        const SizedBox(height: 18),
        ...nodes,
        const SizedBox(height: 12),
        Opacity(opacity: 0.8, child: banner(week + 1, locked: true)),
        const SizedBox(height: 14),
        ...nextWeek,
      ],
    );
  }
}

enum _State { done, today, locked }

class _Step extends StatefulWidget {
  const _Step({
    required this.day,
    required this.state,
    required this.chest,
    required this.offset,
    required this.kind,
    required this.showSprout,
    required this.j,
  });
  final int day;
  final _State state;
  final bool chest;
  final double offset;
  final String kind;
  final bool showSprout;
  final Map<String, dynamic> j;

  @override
  State<_Step> createState() => _StepState();
}

class _StepState extends State<_Step> with SingleTickerProviderStateMixin {
  late final AnimationController _bob = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _bob.dispose();
    super.dispose();
  }

  Future<void> _tap() async {
    HapticFeedback.selectionClick();
    switch (widget.state) {
      case _State.today:
      case _State.done when widget.day == _todayStep():
        await push(context, AyahReaderScreen(journey: widget.j, games: _games));
        AppState.i.refreshAll();
      case _State.done:
        toast(context, 'Day ${widget.day} done ✓ MashaAllah!');
      case _State.locked:
        toast(context, widget.chest ? 'Reach day ${widget.day} to open this chest 🎁' : 'Come back on day ${widget.day} 🌱');
    }
  }

  int _todayStep() {
    final rs = _m(widget.j['reading_streak']);
    final streak = _i(rs['current']);
    return rs['today'] == true ? math.max(streak, 1) : streak + 1;
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final today = s == _State.today;
    final (Color top, Color edge) = switch (s) {
      _State.done when widget.chest => (_gold, _goldEdge),
      _State.done => (_done, _doneEdge),
      _State.today => (SioColors.blue, const Color(0xFF0E3F70)),
      _State.locked => (SioColors.greyBg, SioColors.border),
    };
    final icon = widget.chest
        ? Text(s == _State.done ? '🎉' : '🎁', style: TextStyle(fontSize: 30, color: s == _State.locked ? Colors.black38 : null))
        : Icon(
            switch (s) {
              _State.done => Icons.check_rounded,
              _State.today => Icons.menu_book_rounded,
              _State.locked => Icons.lock_rounded,
            },
            color: s == _State.locked ? SioColors.textSecondary : Colors.white,
            size: 34,
          );
    final size = today ? 84.0 : 72.0;
    final button = Semantics(
      button: true,
      label: 'Day ${widget.day}${today ? ', today' : ''}',
      child: Squish(
        onTap: _tap,
        child: SizedBox(
          width: size,
          height: size * 0.92,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: size * 0.84,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: edge, shape: BoxShape.circle),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                height: size * 0.84,
                child: DecoratedBox(
                  decoration: BoxDecoration(color: top, shape: BoxShape.circle),
                  child: Center(child: icon),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    Widget node = today
        ? Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedBuilder(
                animation: _bob,
                builder: (context, child) => Transform.translate(offset: Offset(0, -4 * _bob.value), child: child),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: SioColors.border, width: 2),
                  ),
                  child: Text(
                    'START · today’s ${widget.kind}',
                    style: TextStyle(color: SioColors.blue, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.all(5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: SioColors.blue.withValues(alpha: 0.25), width: 5),
                ),
                child: button,
              ),
            ],
          )
        : button;
    final rs = _m(widget.j['reading_streak']);
    final streak = _i(rs['current']);
    final mood = noorMood(readToday: rs['today'] == true, streak: streak, missedYesterday: streak == 0 && _i(rs['best']) > 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: SizedBox(
        height: today ? 150 : 82,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Transform.translate(offset: Offset(widget.offset, 0), child: node),
            if (widget.showSprout)
              Align(
                alignment: widget.offset > 0 ? Alignment.centerLeft : Alignment.centerRight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Noor(mood: s == _State.done ? NoorMood.happy : mood, size: 104),
                ),
              ),
          ],
        ),
      ),
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
          gradient: const LinearGradient(
            colors: [Color(0xFFEFFBE3), Color(0xFFD3F2B8)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
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
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF1F3D12)),
            ),
            const SizedBox(height: 6),
            Text(
              widget.sub,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, color: Color(0xFF3F5233), height: 1.35),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: _done,
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
