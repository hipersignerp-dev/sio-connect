import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

/// Noor (نور, "light"): SIO Connect's little lantern. Its light is your reading streak: bright after you read,
/// fading through the day while today's ayah waits, nearly out late at night, and out when a day is missed.
/// The same moods are drawn for the home-screen widget and notification pictures.
enum NoorMood {
  happy, // read today
  hello, // morning, not read yet
  waiting, // afternoon
  worried, // evening
  urgent, // late night, light nearly out
  out, // a day was missed: the light went out
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

/// What Noor says. A different line each day (picked by the date), so it doesn't feel like a robot.
String noorLine(NoorMood m, {int streak = 0, String name = '', bool games = true, DateTime? now}) {
  final n = name.isEmpty ? '' : ', $name';
  final s = games && streak > 0;
  final lines = switch (m) {
    NoorMood.happy => [
      if (s) '$streak days of light$n! I’m glowing ✨',
      'Alhamdulillah! Today’s ayah is done. I’m shining bright.',
      'You lit me up today$n. See you tomorrow!',
      if (s) 'MashaAllah, $streak days! Keep me glowing tomorrow too.',
    ],
    NoorMood.hello => [
      'Assalamu Alaikum$n! Today’s ayah is ready ☀️',
      'Good morning$n. One ayah, one minute. Shall we?',
      'Start the day with light: today’s ayah is waiting.',
    ],
    NoorMood.waiting => [
      'Still waiting for you$n 👀 Just one ayah.',
      'A quick break? Read today’s ayah with me.',
      if (s) 'Your $streak-day light is waiting for today’s ayah.',
      'I saved today’s ayah for you$n.',
    ],
    NoorMood.worried => [
      'My light is getting dim$n… 🥺',
      if (s) 'Don’t let your $streak-day streak go dark tonight!',
      'Just one minute before the day ends?',
      'I’m flickering… read today’s ayah and I’ll glow again.',
    ],
    NoorMood.urgent => [
      if (s) 'Only a few hours left for your $streak-day streak 😟',
      'I’m almost out$n! One ayah before you sleep?',
      'Quick, before midnight! Keep me burning 🕯️',
    ],
    NoorMood.out => [
      'My light went out$n… read today and light me up again 🕯️',
      'I missed you yesterday. Let’s start a new streak today!',
      'Every day is a new start. Light me up again$n?',
    ],
  };
  final d = now ?? DateTime.now();
  return lines[(d.year * 400 + d.month * 31 + d.day) % lines.length];
}

/// Noor, gently floating (and glowing) on screen.
class Noor extends StatefulWidget {
  const Noor({super.key, required this.mood, this.size = 96, this.animate = true});
  final NoorMood mood;
  final double size;
  final bool animate;

  @override
  State<Noor> createState() => _NoorState();
}

class _NoorState extends State<Noor> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));

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
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        final t = _c.value * 2 * math.pi;
        final bob = widget.mood == NoorMood.happy ? math.sin(t) * 0.05 : math.sin(t) * 0.025;
        return Transform.translate(
          offset: Offset(0, bob * widget.size),
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: NoorPainter(widget.mood, flicker: widget.animate ? (math.sin(t * 3) + 1) / 2 : 0.5),
          ),
        );
      },
    ),
  );
}

/// Noor in a speech row: the lantern and what it says.
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

class NoorPainter extends CustomPainter {
  NoorPainter(this.mood, {this.flicker = 0.5});
  final NoorMood mood;
  final double flicker; // 0..1, for the glow pulse

  static const _frame = Color(0xFF1A4F8A);
  static const _frameDark = Color(0xFF0E3F70);
  static const _gold = Color(0xFFE8B33A);

  double get _light => switch (mood) {
    NoorMood.happy => 1.0,
    NoorMood.hello => 0.85,
    NoorMood.waiting => 0.7,
    NoorMood.worried => 0.45,
    NoorMood.urgent => 0.25 + 0.15 * flicker,
    NoorMood.out => 0.0,
  };

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final u = w / 100; // design on a 100 x 100 box
    final cx = w / 2;
    final light = _light;
    Offset p(double x, double y) => Offset(x * u, y * u);

    // glow behind
    if (light > 0) {
      final g = Paint()
        ..shader = RadialGradient(
          colors: [
            const Color(0xFFFFD36B).withValues(alpha: 0.55 * light * (0.85 + 0.15 * flicker)),
            const Color(0xFFFFD36B).withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: p(50, 56), radius: 48 * u));
      canvas.drawCircle(p(50, 56), 48 * u, g);
    }

    // hanging ring and cap
    final ring = Paint()
      ..color = _gold
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3 * u;
    canvas.drawCircle(p(50, 9), 5 * u, ring);
    final cap = Path()
      ..moveTo(cx - 14 * u, 26 * u)
      ..quadraticBezierTo(cx, 8 * u, cx + 14 * u, 26 * u)
      ..close();
    canvas.drawPath(cap, Paint()..color = _frameDark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 20 * u, 24 * u, 40 * u, 6 * u), Radius.circular(3 * u)),
      Paint()..color = _gold,
    );

    // glass body
    final body = RRect.fromRectAndRadius(Rect.fromLTWH(cx - 22 * u, 29 * u, 44 * u, 50 * u), Radius.circular(14 * u));
    final warm = Color.lerp(const Color(0xFF8A97A6), const Color(0xFFFFE7A3), light)!;
    final warm2 = Color.lerp(const Color(0xFF5E6B7A), const Color(0xFFFFB547), light)!;
    canvas.drawRRect(
      body,
      Paint()
        ..shader = LinearGradient(
          colors: [warm, warm2],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(body.outerRect),
    );
    // frame bars
    final bar = Paint()
      ..color = _frame
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.2 * u;
    canvas.drawRRect(body, bar);
    canvas.drawLine(p(50, 30), p(50, 37), bar..strokeWidth = 2.4 * u);
    canvas.drawLine(p(50, 72), p(50, 78), bar);
    // little arch window detail
    final arch = Path()
      ..moveTo(cx - 16 * u, 40 * u)
      ..quadraticBezierTo(cx, 30 * u, cx + 16 * u, 40 * u);
    canvas.drawPath(
      arch,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.35 * (0.4 + light))
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6 * u,
    );

    // base
    final base = Path()
      ..moveTo(cx - 18 * u, 78 * u)
      ..lineTo(cx + 18 * u, 78 * u)
      ..lineTo(cx + 12 * u, 88 * u)
      ..lineTo(cx - 12 * u, 88 * u)
      ..close();
    canvas.drawPath(base, Paint()..color = _frameDark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(cx - 14 * u, 87 * u, 28 * u, 4 * u), Radius.circular(2 * u)),
      Paint()..color = _gold,
    );

    // face
    final ink = Paint()..color = const Color(0xFF2B2118);
    final eyeY = 52.0;
    void eye(double x, {double h = 7, double wdt = 5.5}) {
      canvas.drawOval(Rect.fromCenter(center: p(x, eyeY), width: wdt * u, height: h * u), ink);
      canvas.drawCircle(p(x + 1.2, eyeY - 1.8), 1.3 * u, Paint()..color = Colors.white);
    }

    void arcEye(double x, {bool up = true}) {
      final path = Path()
        ..moveTo((x - 3.5) * u, eyeY * u)
        ..quadraticBezierTo(x * u, (eyeY + (up ? -5 : 4)) * u, (x + 3.5) * u, eyeY * u);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFF2B2118)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4 * u
          ..strokeCap = StrokeCap.round,
      );
    }

    final mouth = Paint()
      ..color = const Color(0xFF2B2118)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2 * u
      ..strokeCap = StrokeCap.round;
    final cheek = Paint()..color = const Color(0xFFFF8A80).withValues(alpha: 0.45);

    switch (mood) {
      case NoorMood.happy:
        arcEye(42);
        arcEye(58);
        canvas.drawPath(
          Path()
            ..moveTo(44 * u, 60 * u)
            ..quadraticBezierTo(50 * u, 68 * u, 56 * u, 60 * u),
          mouth,
        );
        canvas.drawCircle(p(37, 59), 3 * u, cheek);
        canvas.drawCircle(p(63, 59), 3 * u, cheek);
        _sparkle(canvas, p(18, 34), 5 * u);
        _sparkle(canvas, p(83, 28), 4 * u);
        _sparkle(canvas, p(84, 62), 3 * u);
      case NoorMood.hello:
        eye(42);
        eye(58);
        canvas.drawPath(
          Path()
            ..moveTo(45 * u, 61 * u)
            ..quadraticBezierTo(50 * u, 65 * u, 55 * u, 61 * u),
          mouth,
        );
        canvas.drawCircle(p(37, 59), 2.6 * u, cheek);
        canvas.drawCircle(p(63, 59), 2.6 * u, cheek);
      case NoorMood.waiting:
        eye(43, h: 6.5);
        eye(59, h: 6.5);
        canvas.drawLine(p(46, 62), p(54, 62), mouth);
        // a little "…" thought bubble
        canvas.drawRRect(
          RRect.fromRectAndRadius(Rect.fromCenter(center: p(80, 27), width: 22 * u, height: 12 * u), Radius.circular(6 * u)),
          Paint()..color = Colors.white,
        );
        canvas.drawCircle(p(70, 36), 2 * u, Paint()..color = Colors.white);
        for (final x in [74.0, 80.0, 86.0]) {
          canvas.drawCircle(p(x, 27), 1.8 * u, Paint()..color = const Color(0xFF1A62A8));
        }
      case NoorMood.worried:
        eye(42, h: 7.5);
        eye(58, h: 7.5);
        // brows up in the middle
        canvas.drawLine(p(38, 44), p(45, 42), mouth);
        canvas.drawLine(p(62, 44), p(55, 42), mouth);
        canvas.drawPath(
          Path()
            ..moveTo(45 * u, 64 * u)
            ..quadraticBezierTo(50 * u, 60 * u, 55 * u, 64 * u),
          mouth,
        );
        _drop(canvas, p(70, 40), 4 * u);
      case NoorMood.urgent:
        eye(42, h: 9, wdt: 7);
        eye(58, h: 9, wdt: 7);
        canvas.drawLine(p(37, 43), p(45, 40), mouth);
        canvas.drawLine(p(63, 43), p(55, 40), mouth);
        canvas.drawOval(Rect.fromCenter(center: p(50, 64), width: 5 * u, height: 6 * u), ink);
        _drop(canvas, p(71, 38), 4.5 * u);
        _drop(canvas, p(29, 44), 3.5 * u);
      case NoorMood.out:
        arcEye(42, up: false);
        arcEye(58, up: false);
        canvas.drawPath(
          Path()
            ..moveTo(45 * u, 65 * u)
            ..quadraticBezierTo(50 * u, 60 * u, 55 * u, 65 * u),
          mouth,
        );
        // a wisp of smoke from the cap
        final smoke = Paint()
          ..color = const Color(0xFF9AA7B4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2 * u
          ..strokeCap = StrokeCap.round;
        canvas.drawPath(
          Path()
            ..moveTo(62 * u, 22 * u)
            ..quadraticBezierTo(70 * u, 16 * u, 64 * u, 10 * u)
            ..quadraticBezierTo(58 * u, 4 * u, 68 * u, 0),
          smoke,
        );
    }
  }

  void _sparkle(Canvas c, Offset o, double r) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx + r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx, o.dy, o.dx - r, o.dy)
      ..quadraticBezierTo(o.dx, o.dy, o.dx, o.dy - r);
    c.drawPath(path, Paint()..color = _gold);
  }

  void _drop(Canvas c, Offset o, double r) {
    final path = Path()
      ..moveTo(o.dx, o.dy - r * 1.6)
      ..quadraticBezierTo(o.dx + r, o.dy, o.dx, o.dy + r)
      ..quadraticBezierTo(o.dx - r, o.dy, o.dx, o.dy - r * 1.6);
    c.drawPath(path, Paint()..color = const Color(0xFF6EC1FF));
  }

  @override
  bool shouldRepaint(NoorPainter old) => old.mood != mood || old.flicker != flicker;
}
