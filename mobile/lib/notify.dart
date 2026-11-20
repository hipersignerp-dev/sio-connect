import 'dart:convert';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:material_ui/material_ui.dart';
import 'package:workmanager/workmanager.dart';

import 'api.dart';

/// Phone notifications for new updates (notices, new programmes, meetings ...).
///
/// There is no push server: the phone checks for new updates in the background about every 15 minutes (and
/// whenever the app is opened) and shows a notification for each one it has not shown before.
class Notify {
  static const _task = 'sio-check-updates';
  static const _seenKey = 'seen_updates';
  static final _plugin = FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static Future<void> _init() async {
    if (_ready) return;
    await _plugin.initialize(const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')));
    _ready = true;
  }

  /// Called once the person is signed in.
  static Future<void> start(String user) async {
    try {
      await Api.prefs.setString('me_user', user);
      await _init();
      await _plugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
      await Workmanager().initialize(callbackDispatcher);
      await Workmanager().registerPeriodicTask(
        _task,
        _task,
        frequency: const Duration(minutes: 15),
        constraints: Constraints(networkType: NetworkType.connected),
        existingWorkPolicy: ExistingPeriodicWorkPolicy.keep,
      );
      await check();
    } catch (_) {
      // notifications are a convenience; never block the app
    }
  }

  // ---- daily reading reminder (local: works without a push server, checked with the 15-minute job)

  /// "HH:MM", or null when the person turned reminders off. Default 8 PM.
  static String? get reminderTime {
    final v = Api.prefs.getString('remind_at');
    if (v == 'off') return null;
    return v ?? '20:00';
  }

  static Future<void> setReminder(String? hm) => Api.prefs.setString('remind_at', hm ?? 'off');

  static String _today() => DateTime.now().toIso8601String().substring(0, 10);

  /// Remember that today's ayah is done (and the streak), so the reminder stays quiet.
  static void markReadToday(int streak) {
    Api.prefs.setString('read_day', _today());
    Api.prefs.setInt('streak_now', streak);
  }

  static Future<void> _dailyReminder() async {
    try {
      final at = reminderTime;
      if (at == null) return;
      final today = _today();
      if (Api.prefs.getString('read_day') == today || Api.prefs.getString('reminded_day') == today) return;
      final p = at.split(':');
      final now = DateTime.now();
      final due = DateTime(now.year, now.month, now.day, int.parse(p[0]), int.parse(p[1]));
      if (now.isBefore(due) || now.difference(due).inHours >= 3) return;
      await Api.prefs.setString('reminded_day', today);
      final streak = Api.prefs.getInt('streak_now') ?? 0;
      await _plugin.show(
        7001,
        streak > 0 ? '🔥 Keep your $streak-day streak' : '📖 Today’s ayah is waiting',
        'Take a minute to read or listen to today’s ayah in SIO Connect.',
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'sio_reading',
            'Daily ayah reminder',
            channelDescription: 'One reminder a day if you haven’t read yet',
            importance: Importance.high,
            priority: Priority.high,
          ),
        ),
      );
    } catch (_) {}
  }

  /// Signing out: stop checking.
  static Future<void> stop() async {
    try {
      await Workmanager().cancelByUniqueName(_task);
    } catch (_) {}
  }

  /// Fetches the latest updates and notifies about the ones not seen yet. The first time, everything already
  /// there is just marked as seen.
  static Future<void> check() async {
    await _init();
    await _dailyReminder();
    final list = (await Api.call('${Api.m}notices') as List?) ?? [];
    final raw = Api.prefs.getString(_seenKey);
    final seen = raw == null ? null : Set<String>.from(jsonDecode(raw) as List);
    final me = Api.prefs.getString('me_user') ?? '';
    final ids = [for (final n in list) n['name'].toString()];
    if (seen != null) {
      for (final n in list.reversed) {
        final id = n['name'].toString();
        if (seen.contains(id) || n['sent_by'] == me) continue;
        await _plugin.show(
          id.hashCode & 0x7fffffff,
          '${n['title']}',
          '${n['message']}',
          const NotificationDetails(
            android: AndroidNotificationDetails(
              'sio_updates',
              'SIO updates',
              channelDescription: 'Notices, new programmes and meetings',
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: BigTextStyleInformation(''),
            ),
          ),
        );
      }
    }
    final keep = {...?seen, ...ids}.toList();
    await Api.prefs.setString(_seenKey, jsonEncode(keep.length > 200 ? keep.sublist(keep.length - 200) : keep));
  }
}

@pragma('vm:entry-point')
void callbackDispatcher() {
  Workmanager().executeTask((task, inputData) async {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await Api.init();
      await Notify.check();
    } catch (_) {}
    return true;
  });
}
