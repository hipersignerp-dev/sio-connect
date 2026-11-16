import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sio_connect/api.dart';
import 'package:sio_connect/app_state.dart';
import 'package:sio_connect/screens/auth_screens.dart';
import 'package:sio_connect/screens/home_shell.dart';
import 'package:sio_connect/screens/more_screen.dart';
import 'package:sio_connect/theme.dart';

Widget wrap(Widget w) => MaterialApp(theme: buildTheme(), home: w);

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await Api.init();
  });

  testWidgets('welcome screen offers sign in and associate registration', (tester) async {
    await tester.pumpWidget(wrap(const WelcomeScreen()));
    expect(find.text('Sign in'), findsOneWidget);
    expect(find.text('New here? Register as an associate'), findsOneWidget);
  });

  testWidgets('register screen has the sign-up fields', (tester) async {
    await tester.pumpWidget(wrap(const RegisterScreen()));
    expect(find.text('Full name'), findsOneWidget);
    expect(find.text('Mobile number'), findsOneWidget);
    expect(find.text('Register as associate'), findsOneWidget);
  });

  testWidgets('associate gets Events tab and Give, no Meetings', (tester) async {
    AppState.i.me = {
      'full_name': 'Sinan Ali',
      'status': 'Pending Approval',
      'capabilities': {'register_events': true, 'offer': true},
    };
    await tester.pumpWidget(wrap(const HomeShell()));
    expect(find.text('Events'), findsWidgets);
    expect(find.text('Give'), findsOneWidget);
    expect(find.text('Meetings'), findsNothing);
  });

  testWidgets('unit admin gets Meetings and Collection tabs and admin actions on +', (tester) async {
    AppState.i.me = {
      'full_name': 'Shibili K',
      'status': 'Active',
      'member_role': 'Unit President',
      'capabilities': {
        'rsvp': true, 'collect': true, 'offer': true, 'mark_attendance': true, 'schedule_meeting': true,
        'view_members': true, 'send_notice': true, 'claim_expense': true, 'view_collection_totals': true,
      },
    };
    await tester.pumpWidget(wrap(const HomeShell()));
    expect(find.text('Meetings'), findsWidgets);
    expect(find.text('Collection'), findsWidgets);
    await tester.tap(find.byTooltip('Add new'));
    await tester.pumpAndSettle();
    // a unit president's four most-used actions are up front...
    expect(find.text('Attendance'), findsOneWidget);
    expect(find.text('Collection entry'), findsOneWidget);
    expect(find.text('Expense claim'), findsOneWidget);
    expect(find.text('New meeting'), findsOneWidget);
    // ...the rest wait under More
    expect(find.text('Send update'), findsNothing);
    await tester.tap(find.widgetWithText(TextButton, 'More'));
    await tester.pumpAndSettle();
    expect(find.text('Send update'), findsOneWidget);
    expect(find.text('Give an offer'), findsOneWidget);
  });

  testWidgets('an associate\'s + opens Give an offer straight away', (tester) async {
    AppState.i.me = {
      'full_name': 'Sinan Ali',
      'status': 'Active',
      'member_role': 'Associate',
      'capabilities': {'offer': true, 'register_events': true},
    };
    await tester.pumpWidget(wrap(const HomeShell()));
    await tester.tap(find.byTooltip('Add new'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Give an offer'), findsWidgets);
    expect(find.text('Collection entry'), findsNothing);
  });

  testWidgets('More has Check for updates', (tester) async {
    AppState.i.me = {'full_name': 'Sinan Ali', 'status': 'Active', 'capabilities': {}};
    await tester.pumpWidget(wrap(const MoreScreen()));
    await tester.scrollUntilVisible(find.text('Check for updates'), 200);
    expect(find.text('Check for updates'), findsOneWidget);
    expect(find.text('Development build'), findsOneWidget);
  });
}
