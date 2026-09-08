import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('cold Firebase failure boots without touching an unavailable auth singleton', () async {
    SharedPreferences.setMockInitialValues({'strength_training_tracker_state_v1': '{"userName":"Unowned legacy data"}'});
    final preferences = await SharedPreferences.getInstance();
    final result = await initializeApp(preferences: preferences,
      firebaseInitializer: () async => throw StateError('native Firebase initialization failed'));
    expect(result.auth, isNull);
    expect(result.initialState.userName, isEmpty);
    expect(result.repository, isA<AccountAppStateRepository>());
    expect(preferences.containsKey('strength_training_tracker_state_v1'), isTrue);
    final container = buildContainer(result);
    addTearDown(container.dispose);
    expect(container.read(authServiceProvider).currentUser, isNull);
    expect(await container.read(authServiceProvider).authStateChanges().first, isNull);
  });
}
