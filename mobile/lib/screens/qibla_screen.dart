import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/services.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:geolocator/geolocator.dart';
import 'package:material_ui/material_ui.dart';

import '../prayer.dart';
import '../theme.dart';

/// Qibla finder: the phone's compass plus the great-circle direction from where you are to the Kaaba.
class QiblaScreen extends StatefulWidget {
  const QiblaScreen({super.key});

  @override
  State<QiblaScreen> createState() => _QiblaScreenState();
}

class _QiblaScreenState extends State<QiblaScreen> {
  static const _kaaba = (21.422487, 39.826206);
  double? _qibla; // degrees from true north
  String _place = 'Ottapalam';
  double _km = 0;
  StreamSubscription<CompassEvent>? _sub;
  double? _heading;
  double? _accuracy;
  bool _noSensor = false;
  bool _wasAligned = false;

  @override
  void initState() {
    super.initState();
    _locate();
    final events = FlutterCompass.events;
    if (events == null) {
      _noSensor = true;
    } else {
      _sub = events.listen((e) {
        if (!mounted) return;
        if (e.heading == null) {
          setState(() => _noSensor = true);
          return;
        }
        setState(() {
          _heading = e.heading;
          _accuracy = e.accuracy;
        });
        final aligned = _aligned;
        if (aligned && !_wasAligned) HapticFeedback.heavyImpact();
        _wasAligned = aligned;
      });
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<void> _locate() async {
    var lat = PrayerTimes.ottapalam.$1;
    var lng = PrayerTimes.ottapalam.$2;
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var p = await Geolocator.checkPermission();
        if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
        if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
          final pos =
              await Geolocator.getLastKnownPosition() ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
              );
          lat = pos.latitude;
          lng = pos.longitude;
          _place = 'Your location';
        }
      }
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _qibla = bearing(lat, lng, _kaaba.$1, _kaaba.$2);
      _km = Geolocator.distanceBetween(lat, lng, _kaaba.$1, _kaaba.$2) / 1000;
    });
  }

  static double bearing(double lat1, double lng1, double lat2, double lng2) {
    double r(double d) => d * math.pi / 180;
    final dl = r(lng2 - lng1);
    final y = math.sin(dl) * math.cos(r(lat2));
    final x = math.cos(r(lat1)) * math.sin(r(lat2)) - math.sin(r(lat1)) * math.cos(r(lat2)) * math.cos(dl);
    return (math.atan2(y, x) * 180 / math.pi + 360) % 360;
  }

  /// How far the phone must turn (−180..180) so its top points to the Qibla.
  double? get _off {
    if (_qibla == null || _heading == null) return null;
    return ((_qibla! - _heading! + 540) % 360) - 180;
  }

  bool get _aligned => (_off?.abs() ?? 99) < 4;

  @override
  Widget build(BuildContext context) {
    final off = _off;
    final aligned = _aligned;
    return Scaffold(
      backgroundColor: aligned ? const Color(0xFF0B3D2A) : const Color(0xFF0E2A47),
      appBar: AppBar(backgroundColor: Colors.transparent, foregroundColor: Colors.white, title: const Text('Qibla · ഖിബ്‌ല')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Text(
                _qibla == null ? 'Finding your location…' : 'Qibla is ${_qibla!.toStringAsFixed(0)}° from north',
                style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                '$_place · Makkah is ${_km.toStringAsFixed(0)} km away',
                style: const TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const Spacer(),
              if (_noSensor)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'This phone has no compass sensor, so the direction can’t be shown live. '
                    'Use the angle above with any compass.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white, height: 1.5),
                  ),
                )
              else
                AspectRatio(
                  aspectRatio: 1,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // the dial turns with the phone so N stays north
                      Transform.rotate(
                        angle: -(_heading ?? 0) * math.pi / 180,
                        child: CustomPaint(
                          size: Size.infinite,
                          painter: _DialPainter(qibla: _qibla, aligned: aligned),
                        ),
                      ),
                      // fixed arrow: the top of the phone
                      Icon(Icons.navigation_rounded, size: 84, color: aligned ? const Color(0xFF7CE0A0) : Colors.white),
                    ],
                  ),
                ),
              const Spacer(),
              if (!_noSensor)
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: Text(
                    off == null
                        ? 'Hold the phone flat'
                        : aligned
                        ? '✅ You are facing the Qibla'
                        : off > 0
                        ? 'Turn right ${off.abs().toStringAsFixed(0)}° →'
                        : '← Turn left ${off.abs().toStringAsFixed(0)}°',
                    key: ValueKey(
                      aligned
                          ? 'a'
                          : (off ?? 0) > 0
                          ? 'r'
                          : 'l',
                    ),
                    style: TextStyle(
                      color: aligned ? const Color(0xFF7CE0A0) : Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                (_accuracy != null && _accuracy! > 30)
                    ? 'Compass is unsure. Move the phone in a figure-8 a few times, away from metal and speakers.'
                    : 'Hold the phone flat, away from metal, fans and speakers.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white60, fontSize: 12.5, height: 1.4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.qibla, required this.aligned});
  final double? qibla;
  final bool aligned;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 8;
    canvas.drawCircle(c, r, Paint()..color = Colors.white.withValues(alpha: 0.06));
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = Colors.white24,
    );
    final tick = Paint()..color = Colors.white38;
    for (var d = 0; d < 360; d += 10) {
      final a = (d - 90) * math.pi / 180;
      final len = d % 90 == 0 ? 14.0 : 7.0;
      tick.strokeWidth = d % 90 == 0 ? 3 : 1.5;
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * (r - len), c + Offset(math.cos(a), math.sin(a)) * r, tick);
    }
    void label(String t, double deg, Color color) {
      final a = (deg - 90) * math.pi / 180;
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c + Offset(math.cos(a), math.sin(a)) * (r - 32) - Offset(tp.width / 2, tp.height / 2));
    }

    label('N', 0, SioColors.red);
    label('E', 90, Colors.white70);
    label('S', 180, Colors.white70);
    label('W', 270, Colors.white70);
    if (qibla != null) {
      final a = (qibla! - 90) * math.pi / 180;
      final p = c + Offset(math.cos(a), math.sin(a)) * (r - 4);
      canvas.drawLine(
        c,
        p,
        Paint()
          ..color = (aligned ? const Color(0xFF7CE0A0) : const Color(0xFFFFC857)).withValues(alpha: 0.7)
          ..strokeWidth = 3,
      );
      final tp = TextPainter(
        text: const TextSpan(text: '🕋', style: TextStyle(fontSize: 34)),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, p - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(_DialPainter old) => old.qibla != qibla || old.aligned != aligned;
}
