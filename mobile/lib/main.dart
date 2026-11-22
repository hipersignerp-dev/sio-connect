import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'app_state.dart';
import 'screens/auth_screens.dart';
import 'screens/public_screens.dart';
import 'screens/social_screens.dart';
import 'bug_report.dart';
import 'error_report.dart';
import 'links.dart';
import 'look.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  ErrorReport.install();
  Look.apply();
  runApp(const SioApp());
  AppState.i.start();
  Links.start();
}

class SioApp extends StatefulWidget {
  const SioApp({super.key});

  @override
  State<SioApp> createState() => _SioAppState();
}

class _SioAppState extends State<SioApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (Look.mode == 'system') Look.set();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<int>(
      valueListenable: Look.changes,
      builder: (context, _, _) => MaterialApp(
        key: ValueKey('${SioColors.dark}'),
        title: 'SIO Connect',
        navigatorKey: navKey,
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        builder: (context, child) {
          final mq = MediaQuery.of(context);
          return MediaQuery(
            data: mq.copyWith(textScaler: TextScaler.linear(mq.textScaler.scale(1) * Look.textScale)),
            child: RepaintBoundary(key: BugReport.shotKey, child: child!),
          );
        },
        home: ListenableBuilder(
          listenable: AppState.i,
          builder: (context, _) {
            switch (AppState.i.stage) {
              case Stage.loading:
                return const _Splash();
              case Stage.locked:
                return const UnlockScreen();
              case Stage.signedOut:
                return const PublicScreen(landing: true);
              case Stage.signedIn:
                return AssociateShell(key: ValueKey(AppState.i.me['user']));
            }
          },
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: Image(image: AssetImage('assets/sio-logo.png'), width: 120)),
  );
}
