import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'ios_app_test.dart' as app;
import 'ios_invite_auth_test.dart' as auth;
import 'ios_startup_test.dart' as startup;
import 'native_runtime_wiring_test.dart' as native;

/// One simulator build for suites that do not require a host driver or a new
/// process. Group scopes keep each suite's setup and teardown isolated.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setPrefix('kotrana_ios_acceptance.');
  group('app UI', () => app.registerTests(configurePreferences: false));
  group('native wiring', native.main);
  if (const bool.fromEnvironment('E2E_WITH_AUTH')) {
    group(
      'invite and auth',
      () => auth.registerTests(configurePreferences: false),
    );
    group('startup', () => startup.registerTests(configurePreferences: false));
  }
}
