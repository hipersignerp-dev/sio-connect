import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Noor: SIO Connect's little sprout in an SIO-blue pot. One ayah a day waters it. It grows with the streak
/// (seedling → sprout → growing → first bud → in bloom), gets thirsty through the day while today's ayah waits,
/// and dries up when a day is missed. The same pictures are used by the home-screen widgets and notifications.
enum NoorMood {
  happy, // read today
  hello, // morning, not read yet
  waiting, // afternoon
  worried, // evening: thirsty
  urgent, // late night: very thirsty
  out, // a day was missed: dried up
  celebrate, // just read
}

/// Which mood fits right now.
NoorMood noorMood({required bool readToday, required int streak, required bool missedYesterday, DateTime? now}) {
  final h = (now ?? DateTime.now()).hour;
  if (readToday) return NoorMood.happy;
  if (missedYesterday && streak == 0) return NoorMood.out;
  if (h < 12) return NoorMood.hello;
  if (h < 17) return NoorMood.waiting;
  if (h < 21) return NoorMood.worried;
  return NoorMood.urgent;
}

/// How big the sprout has grown: 0 seedling (days 0–2), 1 sprout (3–6), 2 growing (7–29), 3 first bud (30–99),
/// 4 in bloom (100+).
int sproutStage(int streak) => streak >= 100
    ? 4
    : streak >= 30
    ? 3
    : streak >= 7
    ? 2
    : streak >= 3
    ? 1
    : 0;

const sproutStageNames = ['Tiny seedling', 'Little sprout', 'Growing', 'First bud', 'In bloom'];

/// Pot colours, won from the chests: one new colour for each week of the series completed.
const potColours = <String, (String, Color)>{
  'blue': ('SIO Blue', Color(0xFF1A62A8)),
  'green': ('Leaf Green', Color(0xFF3E9B4F)),
  'red': ('SIO Red', Color(0xFFC8202A)),
  'purple': ('Royal Purple', Color(0xFF6A4BC4)),
  'orange': ('Sunset Orange', Color(0xFFE87A2A)),
  'teal': ('Ocean Teal', Color(0xFF1C9A9A)),
  'pink': ('Rose Pink', Color(0xFFE2607F)),
  'gold': ('Golden', Color(0xFFE0A800)),
};
const _stageAt = [0, 3, 7, 30, 100];

/// "4 more days until your first bud" (null when fully grown).
String? nextGrowth(int streak) {
  final st = sproutStage(streak);
  if (st >= 4) return null;
  final left = _stageAt[st + 1] - streak;
  final what = ['it sprouts', 'it starts growing', 'its first bud', 'it blooms'][st];
  return left == 1 ? '1 more day until $what' : '$left more days until $what';
}

String _img(NoorMood m) => switch (m) {
  NoorMood.happy => 'happy',
  NoorMood.hello => 'hello',
  NoorMood.waiting => 'waiting',
  NoorMood.worried || NoorMood.urgent => 'sad',
  NoorMood.out => 'out',
  NoorMood.celebrate => 'celebrate',
};

/// What Noor says. A different line each day (picked by the date), so it doesn't feel like a robot.
String noorLine(NoorMood m, {int streak = 0, String name = '', bool games = true, DateTime? now}) {
  final n = name.isEmpty ? '' : ', $name';
  final s = games && streak > 0;
  final lines = switch (m) {
    NoorMood.happy || NoorMood.celebrate => [
      if (s) '$streak days$n! I’m growing so well 🌱',
      'Alhamdulillah! You watered me today 💧',
      'Thank you$n. I feel so fresh now. See you tomorrow!',
      if (s) 'MashaAllah, $streak days! Look how tall I’m getting.',
    ],
    NoorMood.hello => [
      'Assalamu Alaikum$n! ☀️ One ayah to water me?',
      'Good morning$n. I’m ready for today’s ayah.',
      'Morning! Let’s grow together today 🌱',
    ],
    NoorMood.waiting => [
      'I’m waiting for you$n 👀 Just one ayah.',
      'A quick break? One ayah and I’ll be happy.',
      if (s) 'Your $streak-day sprout is getting a little thirsty.',
      'I saved today’s ayah for you$n.',
    ],
    NoorMood.worried => [
      'I’m getting thirsty$n… 🥺',
      if (s) 'Please don’t let me dry up after $streak days!',
      'Just one minute before the day ends?',
      'My leaves are drooping… one ayah and I’ll stand up again.',
    ],
    NoorMood.urgent => [
      if (s) 'Only a few hours left$n. Don’t let $streak days dry up 😢',
      'I’m so thirsty$n! One ayah before you sleep?',
      'Quick, before midnight! Water me with one ayah 💧',
    ],
    NoorMood.out => [
      'I dried up$n… 🥀 Water me today and I’ll grow again.',
      'I missed you yesterday. Let’s start again together?',
      'Every day is a new start. Plant me again$n?',
    ],
  };
  final d = now ?? DateTime.now();
  return lines[(d.year * 400 + d.month * 31 + d.day) % lines.length];
}

/// The sprout, gently swaying on screen.
class Noor extends StatefulWidget {
  const Noor({super.key, required this.mood, this.size = 96, this.animate = true, this.stage, this.pot});
  final NoorMood mood;
  final double size;
  final bool animate;

  /// Growth stage 0–4; null = the signed-in person's sprout ([Noor.myStreak]).
  final int? stage;

  /// Pot colour key ([potColours]); null = the signed-in person's pot ([Noor.myPot]).
  final String? pot;

  /// The signed-in person's streak, so every Noor on screen shows their sprout at the right size.
  static int myStreak = 0;

  /// The signed-in person's chosen pot.
  static String myPot = 'blue';

  @override
  State<Noor> createState() => _NoorState();
}

class _NoorState extends State<Noor> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600));

  @override
  void initState() {
    super.initState();
    if (widget.animate) _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final st = widget.mood == NoorMood.out ? 0 : (widget.stage ?? sproutStage(Noor.myStreak));
    final pot = potColours.containsKey(widget.pot ?? Noor.myPot) ? (widget.pot ?? Noor.myPot) : 'blue';
    Widget layer(String f) => Image.asset(
      'assets/sprout/$f.png',
      width: widget.size,
      height: widget.size,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
    );
    final img = SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(children: [layer('p${st}_${_img(widget.mood)}'), layer('pot_$pot')]),
    );
    if (!widget.animate) return img;
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, child) {
          final t = _c.value * 2 * math.pi;
          final happy = widget.mood == NoorMood.happy || widget.mood == NoorMood.celebrate;
          final droop = widget.mood == NoorMood.out;
          final sway = droop ? 0.0 : math.sin(t) * (happy ? 0.05 : 0.03);
          final squash = happy ? 1 + math.sin(t * 2).abs() * 0.04 : 1.0;
          return Transform(
            alignment: Alignment.bottomCenter,
            transform: Matrix4.identity()
              ..rotateZ(sway)
              ..scaleByDouble(1 / squash, squash, 1, 1),
            child: child,
          );
        },
        child: img,
      ),
    );
  }
}

/// Noor in a speech row: the sprout and what it says.
class NoorSays extends StatelessWidget {
  const NoorSays({super.key, required this.mood, required this.text, this.light = false, this.size = 64});
  final NoorMood mood;
  final String text;
  final bool light; // on a dark/blue background
  final double size;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Noor(mood: mood, size: size),
      const SizedBox(width: 8),
      Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: light ? Colors.white.withValues(alpha: 0.16) : Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: const BorderRadius.only(
              topLeft: Radius.circular(4),
              topRight: Radius.circular(16),
              bottomLeft: Radius.circular(16),
              bottomRight: Radius.circular(16),
            ),
          ),
          child: Text(
            text,
            style: TextStyle(
              color: light ? Colors.white : Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
              height: 1.3,
            ),
          ),
        ),
      ),
    ],
  );
}
