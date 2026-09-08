import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';

void main() {
  test(
    'optional auth reports a signed-out state when Firebase is unavailable',
    () async {
      final service = AuthService(null);

      expect(service.currentUser, isNull);
      expect(await service.authStateChanges().first, isNull);
    },
  );

  test('operations requiring Firebase fail through the auth guard', () async {
    final service = AuthService(null);

    expect(() => service.currentProviderId, throwsA(isA<StateError>()));
    await expectLater(service.deleteCurrentUser(), throwsA(isA<StateError>()));
    await expectLater(
      service.revokeAppleToken('unused-test-code'),
      throwsA(isA<StateError>()),
    );
  });
}
