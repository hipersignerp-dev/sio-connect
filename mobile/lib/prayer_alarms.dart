import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'prayer.dart';

/// Prayer reminders. Prayer times move a little every day, so the next 7 days are scheduled from the month's
/// timetable (aladhan.com, kept on the phone) and re-scheduled whenever the app opens or the settings change.
/// By default: one reminder at azan time and one 15 minutes after. Each person can switch prayers off, add other
/// times (before or after), and pick the sound.
class PrayerAlarms {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _base = 9000; // notification ids 9000–9499

  static const sounds = {'chime': 'Soft chime', 'bell': 'Bell', 'soft': 'Gentle tone', 'default': 'Phone’s sound'};
  static const defaultOffsets = [0, 15];

  // ---- settings (kept on the phone)
  static Future<SharedPreferences> get _p => SharedPreferences.getInstance();

  static Future<bool> enabled() async => (await _p).getBool('pa_enabled') ?? true;
  static Future<Set<String>> prayersOn() async {
    final v = (await _p).getStringList('pa_on');
    return v == null ? PrayerTimes.names.toSet() : v.toSet();
  }

  static Future<List<int>> offsets() async {
    final v = (await _p).getStringList('pa_offsets');
    final o = v == null ? [...defaultOffsets] : [for (final x in v) int.tryParse(x) ?? 0];
    return o..sort();
  }

  static Future<String> sound() async => (await _p).getString('pa_sound') ?? 'chime';

  static Future<void> save({bool? enabled, Set<String>? on, List<int>? offsets, String? sound}) async {
    final p = await _p;
    if (enabled != null) await p.setBool('pa_enabled', enabled);
    if (on != null) await p.setStringList('pa_on', on.toList());
    if (offsets != null) await p.setStringList('pa_offsets', [for (final o in offsets.toSet()) '$o']);
    if (sound != null) await p.setString('pa_sound', sound);
    await schedule();
  }

  static String offsetLabel(int o) => o == 0
      ? 'At azan'
      : o < 0
      ? '${-o} min before'
      : '$o min after';

  // ---- the timetable
  static String _key(DateTime d) => 'pa_cal_${d.year}_${d.month}';

  /// Times for each day from today, for [days] days.
  static Future<List<(DateTime, Map<String, DateTime>)>> upcoming({int days = 7}) async {
    final p = await _p;
    final now = DateTime.now();
    final out = <(DateTime, Map<String, DateTime>)>[];
    final months = <String, List<dynamic>>{};
    for (var i = 0; i < days; i++) {
      final d = DateTime(now.year, now.month, now.day + i);
      final k = _key(d);
      if (!months.containsKey(k)) {
        var raw = p.getString(k);
        if (raw == null || p.getString('${k}_at') != await _placeKey()) {
          raw = await _fetchMonth(d);
          if (raw != null) {
            await p.setString(k, raw);
            await p.setString('${k}_at', await _placeKey());
          }
        }
        months[k] = raw == null ? const [] : ((jsonDecode(raw)['data'] as List?) ?? const []);
      }
      final list = months[k]!;
      if (d.day - 1 >= list.length) continue;
      final t = (list[d.day - 1]['timings'] ?? {}) as Map;
      final times = <String, DateTime>{};
      for (final n in PrayerTimes.names) {
        final m = RegExp(r'(\d{1,2}):(\d{2})').firstMatch('${t[n] ?? ''}');
        if (m != null) times[n] = DateTime(d.year, d.month, d.day, int.parse(m.group(1)!), int.parse(m.group(2)!));
      }
      if (times.length == 5) out.add((d, times));
    }
    return out;
  }

  static String? _place;
  static Future<String> _placeKey() async {
    if (_place != null) return _place!;
    final (lat, lng, _) = await PrayerTimes.where();
    // rounded to about 10 km, so the timetable is fetched again only after a real move
    return _place = '${lat.toStringAsFixed(1)},${lng.toStringAsFixed(1)}';
  }

  static Future<String?> _fetchMonth(DateTime d) async {
    try {
      final (lat, lng, _) = await PrayerTimes.where();
      final r = await http
          .get(
            Uri.parse('https://api.aladhan.com/v1/calendar/${d.year}/${d.month}?latitude=$lat&longitude=$lng&method=1&school=0'),
          )
          .timeout(const Duration(seconds: 15));
      if (r.statusCode == 200) return r.body;
    } catch (_) {}
    return null;
  }

  // ---- notifications
  static bool _ready = false;
  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  static NotificationDetails _details(String sound) => NotificationDetails(
    android: AndroidNotificationDetails(
      'prayer_$sound',
      'Prayer reminders (${sounds[sound] ?? sound})',
      channelDescription: 'Reminders for the five prayers',
      importance: Importance.max,
      priority: Priority.high,
      category: AndroidNotificationCategory.reminder,
      sound: sound == 'default' ? null : RawResourceAndroidNotificationSound('prayer_$sound'),
      largeIcon: const DrawableResourceAndroidBitmap('noor_hello'),
    ),
  );

  static String _hm(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  static (String, String) _text(String prayer, DateTime at, int offset) {
    final ml = PrayerTimes.ml[prayer] ?? '';
    if (offset < 0) return ('$prayer in ${-offset} minutes 🕌', 'Get ready for $prayer · $ml (${_hm(at)})');
    if (offset == 0) return ('It’s time for $prayer · $ml', '${_hm(at)} · Allahu Akbar 🕌');
    return ('Did you pray $prayer? 🤲', '$prayer was at ${_hm(at)}. Noor is waiting for you 🌱');
  }

  /// Can we ring at the exact minute? (Android 12+ asks the person once.)
  static Future<bool> exactAllowed() async {
    try {
      final a = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await a?.canScheduleExactNotifications() ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<void> askExact() async {
    await _init();
    await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestExactAlarmsPermission();
  }

  /// Clears and sets the reminders for the next 7 days. Safe to call often.
  static Future<void> schedule() async {
    try {
      await _init();
      final p = await _p;
      for (final id in p.getStringList('pa_ids') ?? const <String>[]) {
        await _plugin.cancel(int.parse(id));
      }
      await p.setStringList('pa_ids', const []);
      if (!await enabled()) return;
      final on = await prayersOn();
      final offs = await offsets();
      final snd = await sound();
      final exact = await exactAllowed();
      final now = DateTime.now();
      final ids = <String>[];
      var n = 0;
      for (final (_, times) in await upcoming()) {
        for (final prayer in PrayerTimes.names) {
          if (!on.contains(prayer)) continue;
          final at = times[prayer]!;
          for (final o in offs) {
            final when = at.add(Duration(minutes: o));
            if (!when.isAfter(now.add(const Duration(seconds: 30))) || n >= 450) continue;
            final id = _base + n++;
            final (title, body) = _text(prayer, at, o);
            await _plugin.zonedSchedule(
              id,
              title,
              body,
              tz.TZDateTime.from(when.toUtc(), tz.UTC),
              _details(snd),
              androidScheduleMode: exact ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
            );
            ids.add('$id');
          }
        }
      }
      await p.setStringList('pa_ids', ids);
    } catch (_) {
      // reminders are a convenience; never block the app
    }
  }

  /// From the background job: once a day is enough to keep a 7-day window filled.
  static Future<void> scheduleDaily() async {
    final p = await _p;
    final today = DateTime.now().toIso8601String().substring(0, 10);
    if (p.getString('pa_last') == today) return;
    await schedule();
    await p.setString('pa_last', today);
  }

  /// A reminder right now, to hear the sound.
  static Future<void> test() async {
    await _init();
    await _plugin.show(
      _base + 499,
      'It’s time for Dhuhr · ളുഹ്ർ',
      'This is how your prayer reminder will look 🕌',
      _details(await sound()),
    );
  }
}
