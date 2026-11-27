import 'prayer_alarms.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'api.dart';

/// Real push notifications through Firebase (sent by the sio_connect app on the server, see sio_connect/push.py).
/// The phone registers its token after sign-in. While the server can push, the 15-minute check stops showing
/// notices itself (so nothing comes twice); Noor's daily reminder stays on the phone.
class Push {
  static const _options = FirebaseOptions(
    apiKey: 'AIzaSyAnCpin_-11sOv5Rhub5kzHLc-WIiUzYt8', // from android/app/google-services.json (public)
    appId: '1:280665319397:android:3067dfddbdc85f3e8a310c',
    messagingSenderId: '280665319397',
    projectId: 'sio-connect-1459f',
    storageBucket: 'sio-connect-1459f.firebasestorage.app',
  );
  static bool _started = false;
  static final _local = FlutterLocalNotificationsPlugin();

  static const channel = AndroidNotificationChannel(
    'sio_notices',
    'SIO notices',
    description: 'Notices, friends, photos, programmes',
    importance: Importance.high,
  );

  /// Server pushes notices (so the phone's own 15-minute check only marks them seen).
  static bool get serverPushes => Api.prefs.getBool('push_ok') ?? false;

  static Future<void> start() async {
    if (_started) return;
    _started = true;
    try {
      if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: _options);
      await _local.initialize(PrayerAlarms.initSettings, onDidReceiveNotificationResponse: PrayerAlarms.onTap);
      await _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()?.createNotificationChannel(
        channel,
      );
      final fm = FirebaseMessaging.instance;
      await fm.requestPermission();
      // ignore: deprecated_member_use
      final t = await fm.getToken();
      if (t != null) await _register(t);
      // ignore: deprecated_member_use
      fm.onTokenRefresh.listen(_register);
      // while the app is open Android doesn't show the push itself, so show it here
      FirebaseMessaging.onMessage.listen((m) {
        final n = m.notification;
        if (n == null) return;
        _local.show(
          m.hashCode & 0x7fffffff,
          n.title,
          n.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
              importance: Importance.high,
              priority: Priority.high,
              styleInformation: const BigTextStyleInformation(''),
            ),
          ),
        );
      });
    } catch (_) {
      _started = false;
    }
  }

  static Future<void> _register(String token) async {
    try {
      final r = await Api.call('${Api.m}push_register', {'token': token, 'platform': 'android'});
      await Api.prefs.setString('push_token', token);
      await Api.prefs.setBool('push_ok', r is Map && r['push'] == 1);
    } catch (_) {}
  }

  /// Sign out: this phone stops getting the person's notifications.
  static Future<void> stop() async {
    final t = Api.prefs.getString('push_token');
    if (t != null) {
      try {
        await Api.call('${Api.m}push_register', {'token': t, 'remove': 1});
      } catch (_) {}
    }
    try {
      // ignore: deprecated_member_use
      if (Firebase.apps.isNotEmpty) await FirebaseMessaging.instance.deleteToken();
    } catch (_) {}
    await Api.prefs.remove('push_token');
    await Api.prefs.setBool('push_ok', false);
    _started = false;
  }
}
