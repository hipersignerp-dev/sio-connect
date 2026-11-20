import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Checks GitHub for a newer SIO Connect build and installs it from inside the app
/// (same as the HiperTracker app).
///
/// Every push to main builds an APK and publishes it as a GitHub release tagged `build-<number>`
/// (.github/workflows/build-apk.yml). The running app's build number is baked in with
/// --dart-define=BUILD_NUMBER. Android installs the update over the app only when both are signed
/// with the same release key (repository secrets ANDROID_KEYSTORE_*).
class UpdateService {
  static const String repo = String.fromEnvironment('UPDATE_REPO', defaultValue: 'hipersignerp-dev/sio-connect');
  static const int buildNumber = int.fromEnvironment('BUILD_NUMBER', defaultValue: 0);

  /// The Google Play build updates through the Play Store, never by itself.
  static const bool playStore = bool.fromEnvironment('PLAY_STORE');
  static const String apkName = 'SIO-Connect.apk';
  static const _channel = MethodChannel('com.hipersign.sio_connect/updater');
  static const _checkEvery = Duration(hours: 3);

  static DateTime? _lastCheck;
  static bool _busy = false;
  static int? _skippedBuild;

  static String get versionLabel => buildNumber > 0 ? 'Build $buildNumber' : 'Development build';

  /// Safe to call often (app start, app resume): only checks every few hours unless [force].
  static Future<void> check(BuildContext context, {bool force = false}) async {
    if (!Platform.isAndroid || _busy || playStore) return;
    if (buildNumber == 0) {
      if (force) _toast(context, 'This is a development build; updates come with the released app.');
      return;
    }
    final now = DateTime.now();
    if (!force && _lastCheck != null && now.difference(_lastCheck!) < _checkEvery) return;
    _lastCheck = now;
    _busy = true;
    try {
      if (force) _toast(context, 'Checking for updates…');
      final release = await _latestRelease();
      if (!context.mounted) return;
      if (release == null) {
        if (force) _toast(context, 'Could not check for updates. Check the internet connection.');
        return;
      }
      if (release.build <= buildNumber) {
        if (force) _toast(context, 'You have the latest version of SIO Connect.');
        return;
      }
      if (!force && _skippedBuild == release.build) return;
      await _offer(context, release);
    } finally {
      _busy = false;
    }
  }

  static void _toast(BuildContext context, String text) {
    final m = ScaffoldMessenger.maybeOf(context);
    m?.hideCurrentSnackBar();
    m?.showSnackBar(SnackBar(content: Text(text)));
  }

  static Future<_Release?> _latestRelease() async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 10);
    try {
      final request = await client.getUrl(Uri.parse('https://api.github.com/repos/$repo/releases/latest'));
      request.headers.set(HttpHeaders.acceptHeader, 'application/vnd.github+json');
      request.headers.set(HttpHeaders.userAgentHeader, 'SIO-Connect-App');
      final response = await request.close().timeout(const Duration(seconds: 15));
      if (response.statusCode != 200) return null;
      final json = jsonDecode(await response.transform(utf8.decoder).join()) as Map<String, dynamic>;
      final tag = (json['tag_name'] ?? '').toString();
      final build = int.tryParse(RegExp(r'(\d+)$').firstMatch(tag)?.group(1) ?? '');
      if (build == null) return null;
      final assets = (json['assets'] as List?) ?? const [];
      // the small APK made for this phone's processor when there is one, else the universal one
      final v = Platform.version;
      final want = v.contains('android_arm64')
          ? 'sio-connect-arm64.apk'
          : v.contains('android_arm')
          ? 'sio-connect-arm32.apk'
          : 'sio-connect.apk';
      final list = assets.cast<Map<String, dynamic>>();
      final apk = list.firstWhere(
        (a) => (a['name'] ?? '').toString().toLowerCase() == want,
        orElse: () => list.firstWhere((a) => (a['name'] ?? '').toString().toLowerCase().endsWith('.apk'), orElse: () => const {}),
      );
      final url = apk['browser_download_url']?.toString();
      if (url == null || url.isEmpty) return null;
      return _Release(
        build: build,
        name: (json['name'] ?? tag).toString(),
        notes: (json['body'] ?? '').toString().trim(),
        url: url,
      );
    } catch (error) {
      developer.log('Update check failed', error: error);
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<void> _offer(BuildContext context, _Release release) async {
    final update = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: const Icon(Icons.system_update, size: 36),
        title: const Text('New version available'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('You have build $buildNumber. The new build is ${release.build}.'),
              if (release.notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                const Text("What's new", style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 4),
                Text(release.notes.split('\n').first, style: Theme.of(context).textTheme.bodySmall),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Later')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Update')),
        ],
      ),
    );
    if (update != true) {
      _skippedBuild = release.build;
      return;
    }
    if (context.mounted) await _install(context, release);
  }

  static Future<void> _install(BuildContext context, _Release release) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 3)),
              SizedBox(width: 16),
              Expanded(child: Text('Downloading update…')),
            ],
          ),
        ),
      ),
    );
    String result;
    try {
      result = await _channel.invokeMethod<String>('install', {'url': release.url, 'name': apkName}) ?? 'error';
    } on PlatformException catch (e) {
      developer.log('Update install failed', error: e);
      result = 'error';
    } on MissingPluginException {
      result = 'error';
    }
    navigator.pop();
    switch (result) {
      case 'installing':
        break; // Android's installer is open
      case 'permission':
        messenger?.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text('Allow SIO Connect to install apps, then come back and tap Check for updates again.'),
          ),
        );
        _skippedBuild = null;
        _lastCheck = null;
      default:
        messenger?.showSnackBar(
          const SnackBar(
            duration: Duration(seconds: 8),
            content: Text('Could not download the update. Check the internet connection and try again.'),
          ),
        );
        _skippedBuild = null;
        _lastCheck = null;
    }
  }
}

class _Release {
  const _Release({required this.build, required this.name, required this.notes, required this.url});
  final int build;
  final String name;
  final String notes;
  final String url;
}
