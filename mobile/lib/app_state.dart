import 'dart:convert';

import 'package:material_ui/material_ui.dart';

import 'package:google_sign_in/google_sign_in.dart';

import 'api.dart';
import 'biometric.dart';
import 'notify.dart';
import 'push.dart';
import 'widgets.dart';

enum Stage { loading, signedOut, locked, signedIn }

/// Who is signed in, what they may do, and the sign-in flow.
class AppState extends ChangeNotifier {
  AppState._();
  static final AppState i = AppState._();

  Stage stage = Stage.loading;
  Map<String, dynamic> me = {};
  String? notice; // shown once on the welcome/login screen

  /// Bumped after any change so open screens reload.
  final changes = ValueNotifier<int>(0);
  void refreshAll() => changes.value++;

  /// Tell listeners [me] changed (e.g. a new photo).
  void touch() => notifyListeners();

  bool can(String capability) => (me['capabilities'] as Map?)?[capability] == true;
  String get status => (me['status'] ?? '').toString();
  bool get pending => status == 'Pending Approval';
  String get firstName => callName('${me['full_name'] ?? ''}');

  /// The name friends actually use: skips Mohammed / Muhammed / Md and initials ("Mohammed Faheem T S" → Faheem).
  static String callName(String full) {
    final words = full.trim().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
    if (words.isEmpty) return '';
    const skip = {
      'mohammed',
      'mohammad',
      'muhammed',
      'muhammad',
      'mohamed',
      'muhamed',
      'mohd',
      'mohd.',
      'md',
      'md.',
      'mhd',
      'mhd.',
      'muhamad',
      'mohamad',
      'mohammedh',
      'muhammadh',
      'sayyid',
      'syed',
      'sheikh',
      'shaikh',
    };
    var i = 0;
    while (i < words.length - 1 && skip.contains(words[i].toLowerCase())) {
      i++;
    }
    final rest = words.sublist(i).where((w) => w.replaceAll('.', '').length > 1).toList();
    if (rest.isEmpty) return words.first;
    final w = rest.first;
    if ((w.toLowerCase() == 'abdul' || w.toLowerCase() == 'abdu') && rest.length > 1) return '$w ${rest[1]}';
    return w;
  }

  String get role => (me['member_role'] ?? '').toString();

  /// Leaders (anyone with management tools) get an "Admin dashboard" button in the app.
  bool get isLeader =>
      !pending &&
      (const [
        'mark_attendance',
        'collect',
        'manage_events',
        'approve_members',
        'view_members',
        'approve_funds',
        'view_collection_totals',
        'schedule_meeting',
        'send_notice',
      ].any(can));

  /// What this person sees: 'all' units, their 'area', or their 'unit'.
  String get level => (me['level'] ?? 'unit').toString();
  String? get area => me['area']?.toString();
  static const areaRoles = ['Area President', 'Area Secretary'];
  static const allRoles = [
    'Associate',
    'Worker',
    'Member',
    'Unit Secretary',
    'Unit President',
    'Area Secretary',
    'Area President',
    'Finance',
    'Area Admin',
  ];

  /// Roles this person may give: area admins any; area presidents / secretaries up to unit office bearers;
  /// unit presidents / secretaries Associate and Worker.
  List<String> get givableRoles {
    if (role == 'Area Admin' || (me['member'] == null && level == 'all')) return allRoles;
    if (level == 'area') return const ['Associate', 'Worker', 'Member', 'Unit Secretary', 'Unit President'];
    return const ['Associate', 'Worker'];
  }

  /// Keeps only the units this person may work with (area leaders: their area; unit leaders: their unit).
  List<dynamic> myUnits(List<dynamic> all) {
    if (level == 'all') return all;
    if (level == 'area') {
      return [
        for (final u in all)
          if (u['district'] == area) u,
      ];
    }
    return [
      for (final u in all)
        if (u['name'] == me['unit']) u,
    ];
  }

  bool get biometricOn => Api.prefs.getBool('biometric_on') ?? false;
  String? get savedLogin => Api.prefs.getString('last_login');

  void _set(Stage s) {
    stage = s;
    notifyListeners();
  }

  Future<void> start() async {
    Api.onSessionExpired = _expired;
    if (biometricOn && await Biometric.readToken() != null) {
      _set(Stage.locked);
      return;
    }
    final g = await Biometric.readGoogleToken();
    if (g != null && g.isNotEmpty) Api.token = g;
    if (Api.hasSession) {
      // open straight away with the saved profile; refresh it quietly (works offline too)
      final saved = Api.prefs.getString('me_cache');
      if (saved != null) {
        try {
          me = Map<String, dynamic>.from(jsonDecode(saved) as Map);
          _set(Stage.signedIn);
          loadMe().catchError((_) {});
          return;
        } catch (_) {}
      }
      try {
        await loadMe();
        _set(Stage.signedIn);
        return;
      } catch (_) {}
    }
    _set(Stage.signedOut);
  }

  Future<void> loadMe() async {
    me = Map<String, dynamic>.from(await Api.call('${Api.m}me') as Map);
    await Api.prefs.setString('me_cache', jsonEncode(me));
    notifyListeners();
  }

  void _expired() {
    if (stage != Stage.signedIn) return;
    Api.token = null;
    Biometric.clearGoogleToken();
    if (biometricOn) {
      _set(Stage.locked);
    } else {
      notice = 'Your session ended. Please sign in again.';
      _set(Stage.signedOut);
    }
  }

  /// Fingerprint unlock. Returns an error message, or null when signed in.
  Future<String?> unlock() async {
    final ok = await Biometric.check('Sign in to SIO Connect');
    if (!ok) return 'Fingerprint not recognised. Try again or use your password.';
    final token = await Biometric.readToken();
    if (token == null) {
      await _turnOffBiometricLocally();
      _set(Stage.signedOut);
      return 'Sign in with your password.';
    }
    Api.token = token;
    try {
      await loadMe();
      _set(Stage.signedIn);
      return null;
    } on ApiException catch (e) {
      if (e.status == 401 || e.status == 403) {
        Api.token = null;
        await _turnOffBiometricLocally();
        notice = 'Fingerprint sign-in was turned off for this phone. Sign in with your password.';
        _set(Stage.signedOut);
      }
      return e.message;
    }
  }

  static const googleWebClient = '280665319397-ggctdep18o9afufgc2a7nr3serc2bll0.apps.googleusercontent.com';
  static bool _googleReady = false;

  /// Asks Google who this is. Returns the ID token, or null if the person closed the picker.
  static Future<String?> googleIdToken() async {
    final g = GoogleSignIn.instance;
    if (!_googleReady) {
      await g.initialize(serverClientId: googleWebClient);
      _googleReady = true;
    }
    try {
      final acct = await g.authenticate();
      return acct.authentication.idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      throw ApiException('Google sign-in failed: ${e.description ?? e.code.name}');
    }
  }

  /// Continue with Google. Returns null when signed in, the Google details for a new person (to finish
  /// signing up), or {'cancelled': true}.
  Future<Map<String, dynamic>?> googleSignIn() async {
    final idToken = await googleIdToken();
    if (idToken == null) return {'cancelled': true};
    final r = Map<String, dynamic>.from(
      await Api.call('${Api.a}google_login', {'id_token': idToken, 'device_name': await Biometric.deviceName()}) as Map,
    );
    if (r['new'] == 1 || r['new'] == true) return {...r, 'id_token': idToken};
    await useGoogleToken('${r['token']}');
    return null;
  }

  Future<void> useGoogleToken(String token) async {
    await Biometric.saveGoogleToken(token);
    Api.token = token;
    await loadMe();
  }

  Future<bool> get googleSession async => (await Biometric.readGoogleToken() ?? '').isNotEmpty;

  Future<void> passwordLogin(String user, String password) async {
    await Api.login(user, password);
    await Api.prefs.setString('last_login', user.trim());
    await loadMe();
  }

  /// After a password sign-in: the screen calls this, then [enterApp].
  void enterApp() {
    notice = null;
    _set(Stage.signedIn);
  }

  Future<void> enableBiometric() async {
    if (!await Biometric.check('Confirm to use fingerprint sign-in')) {
      throw const ApiException('Fingerprint not confirmed.');
    }
    final res = await Api.call('${Api.a}enable_biometric', {'device_name': await Biometric.deviceName()}) as Map;
    await Biometric.saveToken('${res['api_key']}:${res['api_secret']}');
    // the new secret replaces the old one; keep a Google sign-in on this phone working
    if (await googleSession) {
      await Biometric.saveGoogleToken('${res['api_key']}:${res['api_secret']}');
      Api.token = '${res['api_key']}:${res['api_secret']}';
    }
    await Api.prefs.setBool('biometric_on', true);
    notifyListeners();
  }

  Future<void> disableBiometric() async {
    try {
      await Api.call('${Api.a}disable_biometric');
    } catch (_) {}
    await _turnOffBiometricLocally();
    notifyListeners();
  }

  Future<void> _turnOffBiometricLocally() async {
    await Biometric.clear();
    await Api.prefs.setBool('biometric_on', false);
  }

  Future<void> signOut() async {
    await Notify.stop();
    await Push.stop();
    await Biometric.clearGoogleToken();
    try {
      await GoogleSignIn.instance.signOut();
    } catch (_) {}
    await disableBiometric();
    await ScreenCache.clear();
    await Api.prefs.remove('me_cache');
    await Api.logout();
    me = {};
    _set(Stage.signedOut);
  }

  Future<void> usePasswordInstead() async {
    Api.token = null;
    await Biometric.clearGoogleToken();
    _set(Stage.signedOut);
  }
}
