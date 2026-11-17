import 'package:material_ui/material_ui.dart';

import '../api.dart';
import '../app_state.dart';
import '../biometric.dart';
import '../theme.dart';
import '../widgets.dart';
import '../location.dart';

const _logo = Image(image: AssetImage('assets/sio-logo.png'), width: 96, height: 96);

/// First screen: sign in, or register as an associate.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notice = AppState.i.notice;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: _logo),
              const SizedBox(height: 20),
              const Text(
                'SIO Connect',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
              const SizedBox(height: 6),
              const Text(
                'Meetings, events, collections and updates for every SIO member',
                textAlign: TextAlign.center,
                style: TextStyle(color: SioColors.textSecondary, fontSize: 15),
              ),
              const Spacer(),
              if (notice != null) ...[SioBanner(text: notice), const SizedBox(height: 16)],
              FilledButton(onPressed: () => push(context, const LoginScreen()), child: const Text('Sign in')),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => push(context, const RegisterScreen()),
                child: const Text('New here? Register as an associate'),
              ),
              const SizedBox(height: 16),
              const Text(
                'Powered by Hipersign ERP',
                textAlign: TextAlign.center,
                style: TextStyle(color: SioColors.textSecondary, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// After a password sign-in or sign-up: offer fingerprint sign-in, then open the app.
Future<void> finishSignIn(BuildContext context) async {
  final state = AppState.i;
  if (!state.biometricOn && await Biometric.available() && context.mounted) {
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.fingerprint, size: 40, color: SioColors.blue),
        title: const Text('Sign in with fingerprint?'),
        content: const Text('Next time, open the app with your fingerprint or face instead of typing your password.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Not now')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Turn on')),
        ],
      ),
    );
    if (yes == true && context.mounted) {
      await run(context, state.enableBiometric, done: 'Fingerprint sign-in is on.');
    }
  }
  if (context.mounted) Navigator.of(context).popUntil((r) => r.isFirst);
  state.enterApp();
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _user = TextEditingController(text: AppState.i.savedLogin ?? '');
  final _pass = TextEditingController();
  final _server = TextEditingController(text: Api.baseUrl);
  bool _hide = true;
  bool _busy = false;
  String? _error;

  Future<void> _submit() async {
    if (_user.text.trim().isEmpty || _pass.text.isEmpty) {
      setState(() => _error = 'Enter your email and password.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.setServer(_server.text);
      await AppState.i.passwordLogin(_user.text, _pass.text);
      if (mounted) await finishSignIn(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _forgot() async {
    final email = TextEditingController(text: _user.text.contains('@') ? _user.text : '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reset password'),
        content: TextField(
          controller: email,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Your email'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send link')),
        ],
      ),
    );
    if (ok == true && mounted) {
      await Api.setServer(_server.text);
      if (!mounted) return;
      await run(context, () => Api.forgotPassword(email.text), done: 'Check your email for the reset link.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Center(child: _logo),
          const SizedBox(height: 24),
          if (_error != null) ...[SioBanner(text: _error!, error: true), const SizedBox(height: 16)],
          TextField(
            controller: _user,
            keyboardType: TextInputType.emailAddress,
            autofillHints: const [AutofillHints.email],
            decoration: const InputDecoration(labelText: 'Email or mobile', prefixIcon: Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _pass,
            obscureText: _hide,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _hide ? 'Show password' : 'Hide password',
                icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                onPressed: () => setState(() => _hide = !_hide),
              ),
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(onPressed: _forgot, child: const Text('Forgot password?')),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Sign in'),
          ),
          const SizedBox(height: 24),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: const Text('Server', style: TextStyle(color: SioColors.textSecondary)),
            children: [
              TextField(
                controller: _server,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'ERP address'),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ],
      ),
    );
  }
}

/// Self sign-up as an associate. The unit admin approves later.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _name = TextEditingController();
  final _mobile = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _campus = TextEditingController();
  final _course = TextEditingController();
  final _town = TextEditingController();
  GeoPoint? _loc;
  String? _unit;
  String? _area;
  String? _year;
  bool _agree = false;
  bool _busy = false;
  bool _hide = true;
  String? _error;
  List<dynamic> _units = [];

  static const years = [
    '1st Year',
    '2nd Year',
    '3rd Year',
    '4th Year',
    '5th Year',
    'PG 1st Year',
    'PG 2nd Year',
    'Research',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    Api.units()
        .then((u) {
          if (mounted) setState(() => _units = u);
        })
        .catchError((_) {});
  }

  Future<void> _submit() async {
    String? err;
    if (_name.text.trim().length < 3) err = 'Enter your full name.';
    if (err == null && _mobile.text.replaceAll(RegExp(r'\D'), '').length < 10) err = 'Enter a valid mobile number.';
    if (err == null && !_email.text.contains('@')) err = 'Enter a valid email.';
    if (err == null && _pass.text.length < 8) err = 'Password needs at least 8 characters.';
    if (err == null && _unit == null && _units.isNotEmpty) err = 'Pick your unit.';
    if (err == null && !_agree) err = 'Please agree to share your details with SIO.';
    if (err != null) {
      setState(() => _error = err);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await Api.call('${Api.a}register', {
        'full_name': _name.text.trim(),
        'mobile': _mobile.text.trim(),
        'email': _email.text.trim(),
        'password': _pass.text,
        'unit': _unit,
        'campus': _campus.text.trim(),
        'course': _course.text.trim(),
        'year_of_study': _year,
        'home_town': _town.text.trim(),
        'latitude': _loc?.lat,
        'longitude': _loc?.lng,
      });
      await AppState.i.passwordLogin(_email.text, _pass.text);
      if (mounted) await finishSignIn(context);
    } on ApiException catch (e) {
      setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(
    TextEditingController c,
    String label, {
    TextInputType? type,
    IconData? icon,
    List<String>? hints,
    TextCapitalization cap = TextCapitalization.none,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      keyboardType: type,
      autofillHints: hints,
      textCapitalization: cap,
      decoration: InputDecoration(labelText: label, prefixIcon: icon == null ? null : Icon(icon)),
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register as associate')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          const SioBanner(
            text: 'You join as an associate. Your unit approves you as a member later; until then you can see events, updates and give an offer.',
          ),
          const SizedBox(height: 16),
          if (_error != null) ...[SioBanner(text: _error!, error: true), const SizedBox(height: 16)],
          _field(
            _name,
            'Full name',
            icon: Icons.person_outline,
            hints: const [AutofillHints.name],
            cap: TextCapitalization.words,
          ),
          _field(
            _mobile,
            'Mobile number',
            type: TextInputType.phone,
            icon: Icons.phone_outlined,
            hints: const [AutofillHints.telephoneNumber],
          ),
          _field(_email, 'Email', type: TextInputType.emailAddress, icon: Icons.mail_outline, hints: const [AutofillHints.email]),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: TextField(
              controller: _pass,
              obscureText: _hide,
              autofillHints: const [AutofillHints.newPassword],
              decoration: InputDecoration(
                labelText: 'Create a password (8+ characters)',
                prefixIcon: const Icon(Icons.lock_outline),
                suffixIcon: IconButton(
                  tooltip: _hide ? 'Show password' : 'Hide password',
                  icon: Icon(_hide ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _hide = !_hide),
                ),
              ),
            ),
          ),
          const SectionTitle('Your area, unit and studies'),
          Builder(
            builder: (context) {
              final areas = {
                for (final u in _units)
                  if ('${u['district'] ?? ''}'.isNotEmpty) '${u['district']}',
              }.toList()..sort();
              final area = _area ?? (areas.length == 1 ? areas.first : null);
              final units = [
                for (final u in _units)
                  if (area == null || u['district'] == area) u['name'].toString(),
              ];
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      initialValue: areas.contains(area) ? area : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Area', prefixIcon: Icon(Icons.hub_outlined)),
                      items: [for (final a in areas) DropdownMenuItem(value: a, child: Text(a))],
                      onChanged: (v) => setState(() {
                        _area = v;
                        _unit = null;
                      }),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: DropdownButtonFormField<String>(
                      key: ValueKey('unit-$area'),
                      initialValue: units.contains(_unit) ? _unit : null,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Unit', prefixIcon: Icon(Icons.groups_outlined)),
                      hint: Text(area == null ? 'Pick your area first' : 'Pick your unit'),
                      items: [
                        for (final u in units)
                          DropdownMenuItem(
                            value: u,
                            child: Text(u, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: area == null ? null : (v) => setState(() => _unit = v),
                    ),
                  ),
                ],
              );
            },
          ),
          _field(_campus, 'College / campus', icon: Icons.school_outlined, cap: TextCapitalization.words),
          _field(_course, 'Course', icon: Icons.menu_book_outlined, cap: TextCapitalization.words),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: DropdownButtonFormField<String>(
              initialValue: _year,
              decoration: const InputDecoration(labelText: 'Year', prefixIcon: Icon(Icons.calendar_today_outlined)),
              items: [for (final y in years) DropdownMenuItem(value: y, child: Text(y))],
              onChanged: (v) => setState(() => _year = v),
            ),
          ),
          _field(_town, 'Home town', icon: Icons.home_outlined, cap: TextCapitalization.words),
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: LocationField(
              value: _loc,
              hint: 'Optional. At home? Tap the button to add it.',
              onChanged: (g) => setState(() => _loc = g),
            ),
          ),
          CheckboxListTile(
            value: _agree,
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (v) => setState(() => _agree = v ?? false),
            title: const Text('I agree to share these details with SIO for membership and updates.'),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white))
                : const Text('Register'),
          ),
        ],
      ),
    );
  }
}

/// Shown when the app opens and fingerprint sign-in is on.
class UnlockScreen extends StatefulWidget {
  const UnlockScreen({super.key});

  @override
  State<UnlockScreen> createState() => _UnlockScreenState();
}

class _UnlockScreenState extends State<UnlockScreen> {
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final err = await AppState.i.unlock();
    if (mounted) {
      setState(() {
        _busy = false;
        _error = err;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final who = AppState.i.savedLogin;
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              const Center(child: _logo),
              const SizedBox(height: 16),
              const Text(
                'SIO Connect',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: SioColors.ink),
              ),
              if (who != null)
                Text(
                  who,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: SioColors.textSecondary),
                ),
              const Spacer(),
              if (_error != null) ...[SioBanner(text: _error!, error: true), const SizedBox(height: 16)],
              Center(
                child: InkResponse(
                  onTap: _busy ? null : _unlock,
                  radius: 56,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(color: SioColors.cardHigh, shape: BoxShape.circle),
                    child: _busy
                        ? const Padding(padding: EdgeInsets.all(30), child: CircularProgressIndicator())
                        : const Icon(
                            Icons.fingerprint,
                            size: 56,
                            color: SioColors.blue,
                            semanticLabel: 'Unlock with fingerprint',
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Touch to unlock',
                textAlign: TextAlign.center,
                style: TextStyle(color: SioColors.textSecondary),
              ),
              const SizedBox(height: 32),
              TextButton(onPressed: AppState.i.usePasswordInstead, child: const Text('Use password instead')),
            ],
          ),
        ),
      ),
    );
  }
}
