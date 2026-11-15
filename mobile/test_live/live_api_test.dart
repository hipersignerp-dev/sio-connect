// Runs the app's real API client against a live site. Not part of CI.
//   flutter test test_live --dart-define=SIO_PASSWORD=...
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sio_connect/api.dart';

void main() {
  const password = String.fromEnvironment('SIO_PASSWORD');
  setUpAll(() async {
    HttpOverrides.global = null; // real network
    SharedPreferences.setMockInitialValues({});
    await Api.init();
  });

  test('units, password sign-in, me, home, collection, token sign-in', () async {
    final units = await Api.units();
    expect(units.map((u) => u['name']), contains('Feroke'));

    await Api.login('sio.test.president@example.com', password);
    expect(Api.hasSession, isTrue);
    final me = await Api.call('${Api.m}me') as Map;
    expect(me['member_role'], 'Unit President');
    expect((me['capabilities'] as Map)['mark_attendance'], isTrue);

    final home = await Api.call('${Api.m}home') as Map;
    expect((home['campaign'] as Map)['collected'], greaterThan(0));
    final col = await Api.call('${Api.m}collection') as Map;
    expect((col['entries'] as List), isNotEmpty);

    // a refused action comes back as a readable message
    try {
      await Api.call('${Api.m}set_expense_status', {'name': 'x', 'status': 'Approved'});
      fail('should be refused');
    } on ApiException catch (e) {
      expect(e.message, contains('not allowed'));
    }

    // fingerprint: keys, then calls with the token only
    final keys = await Api.call('${Api.a}enable_biometric', {'device_name': 'Live test'}) as Map;
    await Api.logout();
    Api.token = '${keys['api_key']}:${keys['api_secret']}';
    final me2 = await Api.call('${Api.m}me') as Map;
    expect(me2['user'], 'sio.test.president@example.com');
    await Api.call('${Api.a}disable_biometric');
    Api.token = null;
  });
}
