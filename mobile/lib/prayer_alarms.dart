import 'dart:convert';

import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/timezone.dart' as tz;

import 'package:material_ui/material_ui.dart';

import 'links.dart';
import 'prayer.dart';
import 'screens/prayer_alarm_screen.dart';

/// Prayer reminders. Prayer times move a little every day, so the next 7 days are scheduled from the month's
/// timetable (aladhan.com, kept on the phone) and re-scheduled whenever the app opens or the settings change.
/// By default: one reminder at azan time and one 15 minutes after. Each person can switch prayers off, add other
/// times (before or after), and pick the sound.
class PrayerAlarms {
  static final _plugin = FlutterLocalNotificationsPlugin();
  static const _base = 9000; // notification ids 9000–9499

  static const sounds = {'azan': 'Azan (short: the opening Allāhu Akbar)', 'ayah': 'Recitation: Kullu nafsin dhā’iqatul mawt (29:57)', 'chime': 'Soft chime', 'bell': 'Bell', 'soft': 'Gentle tone', 'default': 'Phone’s sound'};
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

  /// The sound at azan time, and the sound for the other reminders (15 min after, or before).
  static Future<String> sound() async => (await _p).getString('pa_sound') ?? 'azan';
  static Future<String> soundAfter() async => (await _p).getString('pa_sound_after') ?? 'ayah';

  // ---- an uploaded sound (an azan downloaded from the internet, a recording…)
  static const _soundCh = MethodChannel('com.hipersign.sio_connect/sound');

  /// The name of the uploaded sound, if there is one.
  static Future<String?> customName() async {
    final p = await _p;
    final path = p.getString('pa_custom_path');
    if (path == null || !File(path).existsSync()) return null;
    return p.getString('pa_custom_name') ?? 'My sound';
  }

  static Future<String?> customPath() async => (await _p).getString('pa_custom_path');

  /// Pick an audio file on the phone and use it for prayer reminders. Returns its name, or null if cancelled.
  static Future<String?> pickCustom() async {
    final r = await FilePicker.pickFiles(type: FileType.audio);
    if (r.isEmpty) return null;
    final src = r.first.path;
    if (src == null) return null;
    final f = File(src);
    if (await f.length() > 15 * 1024 * 1024) throw Exception('That file is too big. Choose one under 15 MB.');
    final dir = Directory('${(await getApplicationSupportDirectory()).path}/sounds');
    await dir.create(recursive: true);
    for (final old in dir.listSync()) {
      try {
        old.deleteSync();
      } catch (_) {}
    }
    final ext = src.contains('.') ? src.substring(src.lastIndexOf('.')) : '.mp3';
    final id = DateTime.now().millisecondsSinceEpoch;
    final dest = '${dir.path}/prayer_$id$ext';
    await f.copy(dest);
    final uri = await _soundCh.invokeMethod<String>('uri', {'path': dest});
    final name = r.first.name.replaceAll(RegExp(r'\.[A-Za-z0-9]+$'), '');
    final p = await _p;
    await p.setString('pa_custom_path', dest);
    await p.setString('pa_custom_uri', uri ?? '');
    await p.setString('pa_custom_id', '$id');
    await p.setString('pa_custom_name', name);
    await save(sound: 'custom');
    return name;
  }

  static Future<void> save({bool? enabled, Set<String>? on, List<int>? offsets, String? sound, String? soundAfter}) async {
    final p = await _p;
    if (enabled != null) await p.setBool('pa_enabled', enabled);
    if (on != null) await p.setStringList('pa_on', on.toList());
    if (offsets != null) await p.setStringList('pa_offsets', [for (final o in offsets.toSet()) '$o']);
    if (sound != null) await p.setString('pa_sound', sound);
    if (soundAfter != null) await p.setString('pa_sound_after', soundAfter);
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
    await _plugin.initialize(initSettings, onDidReceiveNotificationResponse: onTap);
    _ready = true;
  }

  static Future<NotificationDetails> _details(String sound, {String? big, bool fullScreen = false}) async {
    final style = big == null ? null : BigTextStyleInformation(big);
    if (sound == 'custom') {
      final p = await _p;
      final uri = p.getString('pa_custom_uri') ?? '';
      final path = p.getString('pa_custom_path') ?? '';
      if (uri.isNotEmpty && File(path).existsSync()) {
        // each uploaded file gets its own channel: Android fixes a channel's sound when it is made
        return NotificationDetails(
          android: AndroidNotificationDetails(
            'prayer_custom_${p.getString('pa_custom_id') ?? '0'}',
            'Prayer reminders (my sound)',
            channelDescription: 'Reminders for the five prayers, with the sound you uploaded',
            importance: Importance.max,
            priority: Priority.high,
            category: AndroidNotificationCategory.alarm,
            audioAttributesUsage: AudioAttributesUsage.alarm, // plays in full, at alarm volume
            sound: UriAndroidNotificationSound(uri),
            styleInformation: style,
            fullScreenIntent: fullScreen,
            largeIcon: const DrawableResourceAndroidBitmap('noor_hello'),
          ),
        );
      }
      sound = 'chime';
    }
    return NotificationDetails(
      android: AndroidNotificationDetails(
        'prayer_$sound',
        'Prayer reminders (${sounds[sound] ?? sound})',
        channelDescription: 'Reminders for the five prayers',
        importance: Importance.max,
        priority: Priority.high,
        category: _voice(sound) ? AndroidNotificationCategory.alarm : AndroidNotificationCategory.reminder,
        // the azan and the recitation play in full, at alarm volume, so they are never cut off
        audioAttributesUsage: _voice(sound) ? AudioAttributesUsage.alarm : AudioAttributesUsage.notification,
        sound: sound == 'default' ? null : RawResourceAndroidNotificationSound('prayer_$sound'),
        styleInformation: style,
        fullScreenIntent: fullScreen,
        largeIcon: const DrawableResourceAndroidBitmap('noor_hello'),
      ),
    );
  }

  static bool _voice(String sound) => sound == 'azan' || sound == 'ayah';

  static String _hm(DateTime t) {
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'AM' : 'PM'}';
  }

  /// Shown under the reminder when the recitation is the sound, so people read what they hear.
  static const ayahText = 'كُلُّ نَفْسٍ ذَائِقَةُ الْمَوْتِ ۖ ثُمَّ إِلَيْنَا تُرْجَعُونَ';
  static const ayahMeaning = 'Every soul will taste death, then to Us you will be returned. (29:57)';
  static const ayahMeaningMl = 'ഓരോ ആത്മാവും മരണം രുചിക്കുന്നതാണ്. പിന്നീട് നമ്മുടെ അടുക്കലേക്കാണ് നിങ്ങൾ മടക്കപ്പെടുക.';
  static String withAyah(String body) => '$body\n\n$ayahText\n$ayahMeaning\n$ayahMeaningMl';

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

  // ---- the full-screen reminder
  static const initSettings = InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher'));

  /// A prayer reminder was tapped, or rang full screen: show the alarm screen.
  static void onTap(NotificationResponse r) => _open(r.payload, r.id);

  static String? _shown;
  static void _open(String? payload, int? id) {
    if (payload == null || !payload.startsWith('prayer|')) return;
    final parts = payload.split('|');
    if (parts.length < 3 || _shown == payload) return;
    final nav = navKey.currentState;
    if (nav == null) return;
    _shown = payload;
    nav
        .push(
          MaterialPageRoute<void>(
            fullscreenDialog: true,
            builder: (_) => PrayerAlarmScreen(prayer: parts[1], offset: int.tryParse(parts[2]) ?? 15, id: id),
          ),
        )
        .whenComplete(() => _shown = null);
  }

  /// Opened by a reminder (the phone was locked, or the app was closed)? Called once the app is up.
  static Future<void> checkLaunch() async {
    try {
      await _init();
      final d = await _plugin.getNotificationAppLaunchDetails();
      if (d?.didNotificationLaunchApp ?? false) {
        final r = d!.notificationResponse;
        _open(r?.payload, r?.id);
      }
    } catch (_) {}
  }

  /// Stops the reminder's sound (by clearing the notification).
  static Future<void> stop(int? id) async {
    if (id == null) return;
    try {
      await _plugin.cancel(id);
    } catch (_) {}
  }

  /// Show the alarm screen over the lock screen and wake the screen, only while it is open.
  static Future<void> overLockScreen(bool on) async {
    try {
      await _battery.invokeMethod('lock', {'on': on});
    } catch (_) {}
  }

  /// Android 14+ asks the person once before an app may ring full screen.
  static Future<void> askFullScreen() async {
    try {
      await _init();
      final p = await _p;
      if (p.getBool('pa_fs_asked') ?? false) return;
      await p.setBool('pa_fs_asked', true);
      await _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.requestFullScreenIntentPermission();
    } catch (_) {}
  }

  // ---- phones that stop alarms to save battery
  static const _battery = MethodChannel('com.hipersign.sio_connect/battery');

  /// Is the app allowed to run in the background (battery "Unrestricted")?
  static Future<bool> batteryFree() async {
    try {
      return await _battery.invokeMethod<bool>('free') ?? true;
    } catch (_) {
      return true;
    }
  }

  static Future<String> brand() async {
    try {
      return (await _battery.invokeMethod<String>('brand') ?? '').toLowerCase();
    } catch (_) {
      return '';
    }
  }

  static Future<void> openBattery() => _battery.invokeMethod('battery');
  static Future<void> openAutostart() => _battery.invokeMethod('autostart');

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
      final sndAzan = await sound();
      final sndAfter = await soundAfter();
      final exact = await exactAllowed();
      final now = DateTime.now();
      final ids = <String>[];
      var n = 0;
      for (final (_, times) in await upcoming()) {
        for (final prayer in PrayerTimes.names) {
          if (!on.contains(prayer)) continue;
          final at = times[prayer]!;
          for (final o in offs) {
            // Maghrib's time is short and people pray it right away: no "did you pray?" reminder after it
            if (prayer == 'Maghrib' && o > 0) continue;
            final when = at.add(Duration(minutes: o));
            if (!when.isAfter(now.add(const Duration(seconds: 30))) || n >= 450) continue;
            final id = _base + n++;
            final snd = o == 0 ? sndAzan : sndAfter;
            final (title, text) = _text(prayer, at, o);
            final body = snd == 'ayah' ? withAyah(text) : text;
            await _plugin.zonedSchedule(
              id,
              title,
              body,
              tz.TZDateTime.from(when.toUtc(), tz.UTC),
              await _details(snd, big: body, fullScreen: o > 0),
              // alarmClock: rings like a real alarm, even in battery saver and while the app is closed
              payload: 'prayer|$prayer|$o',
              androidScheduleMode: exact ? AndroidScheduleMode.alarmClock : AndroidScheduleMode.inexactAllowWhileIdle,
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

  /// A reminder right now, to hear the sound: the azan-time one, or the one 15 minutes after.
  static Future<void> test({bool after = false}) async {
    await _init();
    final snd = after ? await soundAfter() : await sound();
    final title = after ? 'Did you pray Dhuhr? 🤲' : 'It’s time for Dhuhr · ളുഹ്ർ';
    const text = 'This is how your prayer reminder will look 🕌';
    final body = snd == 'ayah' ? withAyah(text) : text;
    await _plugin.show(
      _base + (after ? 498 : 499),
      title,
      body,
      await _details(snd, big: body, fullScreen: after),
      payload: after ? 'prayer|Dhuhr|15' : null,
    );
  }
}
