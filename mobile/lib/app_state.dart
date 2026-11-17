import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'biometric.dart';
import 'notify.dart';

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
  String get firstName => (me['full_name'] ?? '').toString().trim().split(' ').first;
  String get role => (me['member_role'] ?? '').toString();

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
    if (Api.hasSession) {
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
    notifyListeners();
  }

  void _expired() {
    if (stage != Stage.signedIn) return;
    Api.token = null;
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
    await disableBiometric();
    await Api.logout();
    me = {};
    _set(Stage.signedOut);
  }

  Future<void> usePasswordInstead() async {
    Api.token = null;
    _set(Stage.signedOut);
  }
}
