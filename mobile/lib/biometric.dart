import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

/// Fingerprint / face sign-in. The API key + secret ERP gives this phone live in its secure storage
/// (Android Keystore / iOS Keychain) and are only read after the fingerprint check passes.
class Biometric {
  static final _auth = LocalAuthentication();
  static const _storage = FlutterSecureStorage();
  static const _key = 'sio_device_token';

  static Future<bool> available() async {
    try {
      if (!await _auth.isDeviceSupported()) return false;
      if (await _auth.canCheckBiometrics) return true;
      return (await _auth.getAvailableBiometrics()).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Shows the system fingerprint/face prompt (the phone PIN works as a fallback).
  static Future<bool> check(String reason) async {
    try {
      return await _auth.authenticate(localizedReason: reason, persistAcrossBackgrounding: true);
    } catch (_) {
      return false;
    }
  }

  static Future<void> saveToken(String token) => _storage.write(key: _key, value: token);
  static Future<String?> readToken() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null;
    }
  }

  static Future<void> clear() => _storage.delete(key: _key);

  static Future<String> deviceName() async {
    try {
      final info = DeviceInfoPlugin();
      if (Platform.isAndroid) {
        final a = await info.androidInfo;
        return '${a.manufacturer} ${a.model}';
      }
      if (Platform.isIOS) {
        final i = await info.iosInfo;
        return i.utsname.machine;
      }
    } catch (_) {}
    return 'Phone';
  }
}
