import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

// Little touches that make the app feel alive: bursts of emoji, bouncy taps, count-ups, shimmer, a
// slowly turning story ring, and a full-screen celebration for streak milestones.

final _rnd = math.Random();

/// Throws a burst of emoji (or confetti) from a point on the screen; fire-and-forget.
void burst(
  BuildContext context, {
  Offset? at,
  List<String> emojis = const ['🎉', '✨', '🔥', '💙', '❤️'],
  int count = 18,
  double power = 1,
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  Offset origin = at ?? Offset.zero;
  if (at == null) {
    final box = context.findRenderObject() as RenderBox?;
    if (box != null && box.hasSize) origin = box.localToGlobal(box.size.center(Offset.zero));
  }
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _Burst(origin: origin, emojis: emojis, count: count, power: power, onDone: () => entry.remove()),
  );
  overlay.insert(entry);
}

class _Particle {
  _Particle(this.emoji, this.angle, this.speed, this.spin, this.size, this.delay);
  final String emoji;
  final double angle;
  final double speed;
  final double spin;
  final double size;
  final double delay;
}

class _Burst extends StatefulWidget {
  const _Burst({required this.origin, required this.emojis, required this.count, required this.power, required this.onDone});
  final Offset origin;
  final List<String> emojis;
  final int count;
  final double power;
  final VoidCallback onDone;

  @override
  State<_Burst> createState() => _BurstState();
}

class _BurstState extends State<_Burst> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))
    ..addStatusListener((s) {
      if (s == AnimationStatus.completed) widget.onDone();
    })
    ..forward();
  late final List<_Particle> _ps = [
    for (var i = 0; i < widget.count; i++)
      _Particle(
        widget.emojis[_rnd.nextInt(widget.emojis.length)],
        -math.pi / 2 + (_rnd.nextDouble() - 0.5) * math.pi * 1.5,
        (220 + _rnd.nextDouble() * 260) * widget.power,
        (_rnd.nextDouble() - 0.5) * 6,
        16 + _rnd.nextDouble() * 16,
        _rnd.nextDouble() * 0.15,
      ),
  ];

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Stack(
        children: [
          for (final p in _ps)
            Builder(
              builder: (context) {
                final t = ((_c.value - p.delay) / (1 - p.delay)).clamp(0.0, 1.0);
                final dx = math.cos(p.angle) * p.speed * t;
                final dy = math.sin(p.angle) * p.speed * t + 520 * t * t; // gravity
                final opacity = t < 0.7 ? 1.0 : (1 - (t - 0.7) / 0.3);
                final scale = t < 0.15 ? t / 0.15 : 1.0;
                return Positioned(
                  left: widget.origin.dx + dx - p.size / 2,
                  top: widget.origin.dy + dy - p.size / 2,
                  child: Opacity(
                    opacity: opacity.clamp(0.0, 1.0),
                    child: Transform.rotate(
                      angle: p.spin * t,
                      child: Transform.scale(
                        scale: scale,
                        child: Text(
                          p.emoji,
                          style: TextStyle(fontSize: p.size, decoration: TextDecoration.none),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

/// Bounces its child whenever [trigger] changes (e.g. a cheer count).
class Pop extends StatefulWidget {
  const Pop({super.key, required this.trigger, required this.child, this.scale = 1.45});
  final Object? trigger;
  final Widget child;
  final double scale;

  @override
  State<Pop> createState() => _PopState();
}

class _PopState extends State<Pop> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 420));
  late final Animation<double> _s = TweenSequence([
    TweenSequenceItem(
      tween: Tween(begin: 1.0, end: widget.scale).chain(CurveTween(curve: Curves.easeOut)),
      weight: 35,
    ),
    TweenSequenceItem(
      tween: Tween(begin: widget.scale, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
      weight: 65,
    ),
  ]).animate(_c);

  @override
  void didUpdateWidget(Pop old) {
    super.didUpdateWidget(old);
    if (old.trigger != widget.trigger) _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(scale: _s, child: widget.child);
}

/// Shrinks a little while pressed, springs back on release: every big button feels physical.
class Squish extends StatefulWidget {
  const Squish({super.key, required this.child, this.onTap});
  final Widget child;
  final VoidCallback? onTap;

  @override
  State<Squish> createState() => _SquishState();
}

class _SquishState extends State<Squish> {
  bool _down = false;

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onTapDown: (_) => setState(() => _down = true),
    onTapCancel: () => setState(() => _down = false),
    onTapUp: (_) => setState(() => _down = false),
    onTap: widget.onTap == null
        ? null
        : () {
            HapticFeedback.selectionClick();
            widget.onTap!();
          },
    child: AnimatedScale(
      scale: _down ? 0.94 : 1,
      duration: const Duration(milliseconds: 120),
      curve: Curves.easeOut,
      child: widget.child,
    ),
  );
}

/// Fades and slides in after a small delay, so lists arrive one item after another.
class Enter extends StatelessWidget {
  const Enter({super.key, required this.child, this.index = 0});
  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: Duration(milliseconds: 380 + math.min(index, 8) * 70),
    curve: Curves.easeOutCubic,
    builder: (context, t, child) => Opacity(
      opacity: t,
      child: Transform.translate(offset: Offset(0, (1 - t) * 24), child: child),
    ),
    child: child,
  );
}

/// Counts up to a number (streaks, cheers).
class CountUp extends StatelessWidget {
  const CountUp(this.value, {super.key, this.style, this.prefix = '', this.suffix = ''});
  final int value;
  final TextStyle? style;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: value.toDouble()),
    duration: Duration(milliseconds: 500 + math.min(value, 30) * 25),
    curve: Curves.easeOutCubic,
    builder: (context, v, _) => Text('$prefix${v.round()}$suffix', style: style),
  );
}

/// Grey placeholder blocks with a moving shine while content loads.
class Shimmer extends StatefulWidget {
  const Shimmer({super.key, required this.child});
  final Widget child;

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1300))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    builder: (context, child) => ShaderMask(
      blendMode: BlendMode.srcATop,
      shaderCallback: (r) => LinearGradient(
        colors: const [Color(0xFFE8EEF4), Color(0xFFF7FAFC), Color(0xFFE8EEF4)],
        stops: const [0.25, 0.5, 0.75],
        begin: Alignment(-1 - 2 + _c.value * 4, 0),
        end: Alignment(1 - 2 + _c.value * 4, 0),
      ).createShader(r),
      child: child,
    ),
    child: widget.child,
  );
}

class Bone extends StatelessWidget {
  const Bone({super.key, this.width, this.height = 14, this.radius = 8, this.circle = false});
  final double? width;
  final double height;
  final double radius;
  final bool circle;

  @override
  Widget build(BuildContext context) => Container(
    width: circle ? height : width,
    height: height,
    decoration: BoxDecoration(
      color: const Color(0xFFE8EEF4),
      shape: circle ? BoxShape.circle : BoxShape.rectangle,
      borderRadius: circle ? null : BorderRadius.circular(radius),
    ),
  );
}

/// Story ring that slowly turns when lit (read today), like a live status.
class SpinRing extends StatefulWidget {
  const SpinRing({super.key, required this.child, required this.lit, this.size = 68});
  final Widget child;
  final bool lit;
  final double size;

  @override
  State<SpinRing> createState() => _SpinRingState();
}

class _SpinRingState extends State<SpinRing> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(seconds: 6));

  @override
  void initState() {
    super.initState();
    if (widget.lit) _c.repeat();
  }

  @override
  void didUpdateWidget(SpinRing old) {
    super.didUpdateWidget(old);
    if (widget.lit && !_c.isAnimating) _c.repeat();
    if (!widget.lit) _c.stop();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = widget.size > 60 ? 3.0 : 2.0;
    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => Container(
        width: widget.size,
        height: widget.size,
        padding: EdgeInsets.all(pad),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.lit ? null : const Color(0xFFDADFE5),
          gradient: widget.lit
              ? SweepGradient(
                  colors: const [Color(0xFF1A62A8), Color(0xFF7C3AED), Color(0xFFC8202A), Color(0xFFF26B1D), Color(0xFF1A62A8)],
                  transform: GradientRotation(_c.value * 2 * math.pi),
                )
              : null,
        ),
        child: child,
      ),
      child: Container(
        padding: EdgeInsets.all(pad),
        decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
        child: FittedBox(child: widget.child),
      ),
    );
  }
}

/// Full-screen moment for a streak: the flame grows, the number counts up, confetti falls.
Future<void> celebrate(
  BuildContext context, {
  required int number,
  required String title,
  required String subtitle,
  String emoji = '🔥',
  List<Color> colors = const [Color(0xFFF26B1D), Color(0xFFC8202A)],
  VoidCallback? onShare,
}) {
  HapticFeedback.heavyImpact();
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
    pageBuilder: (ctx, _, _) =>
        _Celebration(number: number, title: title, subtitle: subtitle, emoji: emoji, colors: colors, onShare: onShare),
  );
}

class _Celebration extends StatefulWidget {
  const _Celebration({
    required this.number,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.colors,
    this.onShare,
  });
  final int number;
  final String title;
  final String subtitle;
  final String emoji;
  final List<Color> colors;
  final VoidCallback? onShare;

  @override
  State<_Celebration> createState() => _CelebrationState();
}

class _CelebrationState extends State<_Celebration> with SingleTickerProviderStateMixin {
  late final AnimationController _glow = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
    ..repeat(reverse: true);
  final _key = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      for (final x in [0.2, 0.5, 0.8]) {
        burst(
          context,
          at: Offset(size.width * x, size.height * 0.38),
          count: 16,
          power: 1.2,
          emojis: [widget.emoji, '✨', '🎉', '⭐'],
        );
      }
    });
  }

  @override
  void dispose() {
    _glow.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Center(
    child: Material(
      color: Colors.transparent,
      child: Container(
        key: _key,
        width: 320,
        padding: const EdgeInsets.fromLTRB(24, 32, 24, 20),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: widget.colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          borderRadius: BorderRadius.circular(32),
          boxShadow: [BoxShadow(color: widget.colors.first.withValues(alpha: 0.5), blurRadius: 40, offset: const Offset(0, 12))],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _glow,
              builder: (context, child) => Transform.scale(scale: 1 + _glow.value * 0.08, child: child),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0.2, end: 1),
                duration: const Duration(milliseconds: 900),
                curve: Curves.elasticOut,
                builder: (context, s, child) => Transform.scale(scale: s, child: child),
                child: Text(widget.emoji, style: const TextStyle(fontSize: 96)),
              ),
            ),
            CountUp(
              widget.number,
              style: const TextStyle(color: Colors.white, fontSize: 64, fontWeight: FontWeight.w900, height: 1),
            ),
            const SizedBox(height: 8),
            Text(
              widget.title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              widget.subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white70, fontSize: 15),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                if (widget.onShare != null) ...[
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: widget.colors.last,
                        shape: const StadiumBorder(),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        widget.onShare!();
                      },
                      icon: const Icon(Icons.ios_share),
                      label: const Text('Share', style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white70),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Continue', style: TextStyle(fontWeight: FontWeight.w700)),
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
