import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiException implements Exception {
  const ApiException(this.message, {this.status});
  final String message;
  final int? status;
  bool get isAuth => status == 401;
  @override
  String toString() => message;
}

/// Talks to Hipersign ERP (Frappe). Password sign-in is the same as the Hipersign mobile app:
/// /api/method/login with device=mobile, a long session that needs no CSRF token. Fingerprint
/// sign-in sends the person's API key as a token instead (see [token]).
class Api {
  static const defaultUrl = 'https://siootp.hipersignerp.cloud';
  static const m = 'sio_connect.api.mobile.';
  static const a = 'sio_connect.api.auth.';
  static late SharedPreferences prefs;

  /// Called when the server says the session is over (set by AppState).
  static void Function()? onSessionExpired;

  static Future<void> init() async => prefs = await SharedPreferences.getInstance();

  static String get baseUrl => prefs.getString('server') ?? defaultUrl;
  static Future<void> setServer(String url) async {
    var u = url.trim();
    if (u.isEmpty) u = defaultUrl;
    if (!u.startsWith('http://') && !u.startsWith('https://')) u = 'https://$u';
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    await prefs.setString('server', u);
  }

  static String? get sid => prefs.getString('sid');

  /// Fingerprint sign-in: "api_key:api_secret", held in memory only after the fingerprint check
  /// (stored in secure storage by Biometric). When set, it is sent instead of the session cookie.
  static String? token;

  static bool get hasSession => (token ?? '').isNotEmpty || (sid ?? '').isNotEmpty;

  static Map<String, String> _fields(Map<String, dynamic> args) {
    final out = <String, String>{};
    args.forEach((k, v) {
      if (v == null) return;
      if (v is Map || v is List) {
        out[k] = jsonEncode(v);
      } else if (v is bool) {
        out[k] = v ? '1' : '0';
      } else {
        out[k] = v.toString();
      }
    });
    return out;
  }

  static Future<http.Response> _post(String path, Map<String, dynamic> args, {bool withSession = true}) async {
    try {
      return await http
          .post(
            Uri.parse('$baseUrl$path'),
            headers: {
              'Accept': 'application/json',
              if (withSession && (token ?? '').isNotEmpty) 'Authorization': 'token $token'
              else if (withSession && (sid ?? '').isNotEmpty) 'Cookie': 'sid=$sid',
            },
            body: _fields(args),
          )
          .timeout(const Duration(seconds: 30));
    } on Exception {
      throw const ApiException('Could not reach the server. Check your internet connection.');
    }
  }

  /// Calls a whitelisted method and returns its `message`.
  static Future<dynamic> call(String method, [Map<String, dynamic> args = const {}]) async {
    final res = await _post('/api/method/$method', args);
    if ((res.statusCode == 401 || res.statusCode == 403) && hasSession && !await _sessionAlive()) {
      await prefs.remove('sid');
      onSessionExpired?.call();
      throw const ApiException('Your session ended. Please sign in again.', status: 401);
    }
    return _parse(res);
  }

  static Future<bool> _sessionAlive() async {
    try {
      final res = await _post('/api/method/frappe.auth.get_logged_user', {});
      return res.statusCode == 200;
    } catch (_) {
      return true; // offline: don't sign the person out
    }
  }

  static dynamic _parse(http.Response res) {
    Map<String, dynamic>? body;
    try {
      final decoded = jsonDecode(utf8.decode(res.bodyBytes));
      if (decoded is Map<String, dynamic>) body = decoded;
    } catch (_) {}
    if (res.statusCode >= 200 && res.statusCode < 300) return body?['message'];
    final msg = _errorText(body) ?? 'Something went wrong (${res.statusCode}).';
    throw ApiException(msg, status: res.statusCode);
  }

  static String? _errorText(Map<String, dynamic>? body) {
    if (body == null) return null;
    final sm = body['_server_messages'];
    if (sm is String && sm.isNotEmpty) {
      try {
        final list = jsonDecode(sm) as List;
        final texts = list.map((e) {
          final d = e is String ? jsonDecode(e) : e;
          return (d is Map ? d['message'] : d).toString();
        }).toList();
        if (texts.isNotEmpty) return _strip(texts.join('\n'));
      } catch (_) {}
    }
    final exc = body['exception'];
    if (exc is String && exc.isNotEmpty) {
      final i = exc.indexOf(':');
      return _strip(i >= 0 ? exc.substring(i + 1).trim() : exc);
    }
    final m = body['message'];
    if (m is String && m.isNotEmpty) return _strip(m);
    return null;
  }

  static String _strip(String s) => s.replaceAll(RegExp(r'<[^>]*>'), '').trim();

  static Future<void> _saveSid(http.Response res) async {
    String? sid;
    final header = res.headers['set-cookie'];
    if (header != null) {
      final match = RegExp(r'(?:^|[;,]\s*)sid=([^;,\s]+)').firstMatch(header);
      if (match != null) sid = match.group(1);
    }
    if (sid == null || sid.isEmpty || sid == 'Guest') {
      throw const ApiException('Sign-in failed. Try again.');
    }
    await prefs.setString('sid', sid);
  }

  /// Password sign-in (email, or mobile if the site allows it).
  static Future<void> login(String user, String password) async {
    final res = await _post('/api/method/login', {'usr': user.trim(), 'pwd': password, 'device': 'mobile'},
        withSession: false);
    if (res.statusCode != 200) {
      Map<String, dynamic>? body;
      try {
        body = jsonDecode(res.body) as Map<String, dynamic>;
      } catch (_) {}
      throw ApiException(_errorText(body) ?? 'Wrong email or password.');
    }
    await _saveSid(res);
  }

  static Future<void> logout() async {
    try {
      if ((sid ?? '').isNotEmpty) await _post('/api/method/logout', {});
    } catch (_) {}
    token = null;
    await prefs.remove('sid');
  }

  static Future<void> forgotPassword(String email) async {
    final res = await _post('/api/method/frappe.core.doctype.user.user.reset_password', {'user': email.trim()},
        withSession: false);
    _parse(res);
  }

  /// Calls that work without signing in (public visitors).
  static Future<dynamic> guest(String method, [Map<String, dynamic> args = const {}]) async {
    final res = await _post('/api/method/sio_connect.api.public.$method', args, withSession: false);
    return _parse(res);
  }

  static Future<List<dynamic>> units() async {
    final res = await _post('/api/method/${a}units', {}, withSession: false);
    return (_parse(res) as List?) ?? [];
  }
}
