import 'package:material_ui/material_ui.dart';

import 'api.dart';
import 'app_state.dart';
import 'screens/auth_screens.dart';
import 'screens/public_screens.dart';
import 'screens/home_shell.dart';
import 'screens/social_screens.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Api.init();
  runApp(const SioApp());
  AppState.i.start();
}

class SioApp extends StatelessWidget {
  const SioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SIO Connect',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
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
              return AppState.i.socialView
                  ? AssociateShell(key: ValueKey('s${AppState.i.me['user']}'))
                  : HomeShell(key: ValueKey(AppState.i.me['user']));
          }
        },
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
