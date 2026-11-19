import 'dart:async';
import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Today's five prayer times for where the phone is (falls back to Ottapalam). Fetched from aladhan.com once a
/// day and kept on the phone, so the card works offline after the first load.
class PrayerTimes {
  PrayerTimes(this.times, this.place, this.day);
  final Map<String, DateTime> times; // Fajr, Dhuhr, Asr, Maghrib, Isha
  final String place;
  final String day;

  static const names = ['Fajr', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];
  static const ml = {'Fajr': 'സുബ്ഹ്', 'Dhuhr': 'ളുഹ്ർ', 'Asr': 'അസ്ർ', 'Maghrib': 'മഗ്‌രിബ്', 'Isha': 'ഇശാ'};
  static const ottapalam = (10.7735, 76.3770);

  static PrayerTimes? _cache;

  /// The next prayer from now (tomorrow's Fajr after Isha is approximated as today's Fajr + 1 day).
  MapEntry<String, DateTime> get next {
    final now = DateTime.now();
    for (final n in names) {
      final t = times[n];
      if (t != null && t.isAfter(now)) return MapEntry(n, t);
    }
    return MapEntry('Fajr', times['Fajr']!.add(const Duration(days: 1)));
  }

  static String _today() {
    final n = DateTime.now();
    return '${n.day.toString().padLeft(2, '0')}-${n.month.toString().padLeft(2, '0')}-${n.year}';
  }

  /// Location without nagging: uses it only if already allowed (asks once, never opens settings).
  static Future<(double, double, String)> _where() async {
    try {
      if (await Geolocator.isLocationServiceEnabled()) {
        var p = await Geolocator.checkPermission();
        final prefs = await SharedPreferences.getInstance();
        if (p == LocationPermission.denied && prefs.getBool('prayer_asked') != true) {
          await prefs.setBool('prayer_asked', true);
          p = await Geolocator.requestPermission();
        }
        if (p == LocationPermission.always || p == LocationPermission.whileInUse) {
          final last = await Geolocator.getLastKnownPosition();
          final pos =
              last ??
              await Geolocator.getCurrentPosition(
                locationSettings: const LocationSettings(accuracy: LocationAccuracy.low, timeLimit: Duration(seconds: 10)),
              );
          return (pos.latitude, pos.longitude, 'Your location');
        }
      }
    } catch (_) {}
    return (ottapalam.$1, ottapalam.$2, 'Ottapalam');
  }

  static PrayerTimes? _parse(String body, String place, String day) {
    final j = jsonDecode(body);
    final t = (j['data']?['timings'] ?? {}) as Map;
    final now = DateTime.now();
    final out = <String, DateTime>{};
    for (final n in names) {
      final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch('${t[n] ?? ''}');
      if (m == null) return null;
      out[n] = DateTime(now.year, now.month, now.day, int.parse(m.group(1)!), int.parse(m.group(2)!));
    }
    return PrayerTimes(out, place, day);
  }

  static Future<PrayerTimes?> load() async {
    final day = _today();
    if (_cache != null && _cache!.day == day) return _cache;
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString('prayer_json');
    if (saved != null && prefs.getString('prayer_day') == day) {
      _cache = _parse(saved, prefs.getString('prayer_place') ?? 'Ottapalam', day);
      if (_cache != null) return _cache;
    }
    try {
      final (lat, lng, place) = await _where();
      // method 1 = Karachi (used in Kerala), school 0 = Shafi'i Asr
      final r = await http
          .get(Uri.parse('https://api.aladhan.com/v1/timings/$day?latitude=$lat&longitude=$lng&method=1&school=0'))
          .timeout(const Duration(seconds: 12));
      if (r.statusCode == 200) {
        final p = _parse(r.body, place, day);
        if (p != null) {
          await prefs.setString('prayer_json', r.body);
          await prefs.setString('prayer_day', day);
          await prefs.setString('prayer_place', place);
          _cache = p;
          return p;
        }
      }
    } catch (_) {}
    return null;
  }
}

String _hm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
}

/// Home card: next prayer with a live countdown, and all five times underneath.
class PrayerCard extends StatefulWidget {
  const PrayerCard({super.key});

  @override
  State<PrayerCard> createState() => _PrayerCardState();
}

class _PrayerCardState extends State<PrayerCard> {
  PrayerTimes? _p;
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    PrayerTimes.load().then((p) {
      if (mounted) setState(() => _p = p);
    });
    _tick = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = _p;
    if (p == null) return const SizedBox.shrink();
    final next = p.next;
    final left = next.value.difference(DateTime.now());
    final h = left.inHours;
    final m = left.inMinutes % 60;
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🕌', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Next: ${next.key} · ${PrayerTimes.ml[next.key]}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      '${_hm(next.value)} · in ${h > 0 ? '${h}h ' : ''}${m}m',
                      style: TextStyle(color: cs.primary, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
              Row(
                children: [
                  Icon(Icons.place_outlined, size: 14, color: cs.outline),
                  Text(p.place, style: TextStyle(color: cs.outline, fontSize: 12)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              for (final n in PrayerTimes.names)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    decoration: BoxDecoration(
                      color: n == next.key ? cs.primary : cs.primary.withValues(alpha: 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      children: [
                        Text(
                          n,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: n == next.key ? Colors.white : cs.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          _hm(p.times[n]!).replaceAll(' AM', '').replaceAll(' PM', ''),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w800,
                            color: n == next.key ? Colors.white : cs.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
