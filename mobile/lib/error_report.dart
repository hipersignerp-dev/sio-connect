import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';

import 'api.dart';
import 'update_service.dart';

/// Sends unexpected app errors to the SIO server (SIO Feedback, kind "App error"), quietly and at most a few a
/// session, so problems get fixed without students having to report them. Network errors are not sent.
class ErrorReport {
  static int _sent = 0;
  static String? _device;
  static final _seen = <String>{};

  static void install() {
    final previous = FlutterError.onError;
    FlutterError.onError = (details) {
      previous?.call(details);
      send(details.exception, details.stack);
    };
    PlatformDispatcher.instance.onError = (e, st) {
      send(e, st);
      return true;
    };
  }

  static Future<void> send(Object e, StackTrace? st) async {
    try {
      if (kDebugMode || !Api.hasSession) return;
      final text = e.toString();
      if (e is ApiException ||
          text.contains('SocketException') ||
          text.contains('ClientException') ||
          text.contains('TimeoutException') ||
          text.contains('HandshakeException')) {
        return;
      }
      if (_sent >= 5 || !_seen.add(text)) return;
      _sent++;
      if (_device == null) {
        try {
          final a = await DeviceInfoPlugin().androidInfo;
          _device = '${a.manufacturer} ${a.model} · Android ${a.version.release}';
        } catch (_) {
          _device = '';
        }
      }
      await Api.call('${Api.m}report_error', {
        'error': text.length > 300 ? text.substring(0, 300) : text,
        'stack': (st ?? StackTrace.current).toString().split('\n').take(25).join('\n'),
        'app_build': UpdateService.versionLabel,
        'device': _device,
      });
    } catch (_) {}
  }
}
