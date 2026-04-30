import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/features/settings/account_deletion_service.dart';

void main() {
  test('deletes stored user data before deleting the auth account', () async {
    final events = <String>[];
    final service = AccountDeletionService(
      deleteUserData: () async => events.add('delete-user-data'),
      deleteCurrentUser: () async => events.add('delete-current-user'),
      clearLocalState: () => events.add('clear-local-state'),
      signInAnonymously: () async => events.add('sign-in-anonymously'),
    );

    await service.deleteAccount();

    expect(events, [
      'delete-user-data',
      'delete-current-user',
      'clear-local-state',
      'sign-in-anonymously',
    ]);
  });

  test('does not clear local state when remote deletion fails', () async {
    final events = <String>[];
    final service = AccountDeletionService(
      deleteUserData: () async => events.add('delete-user-data'),
      deleteCurrentUser: () async {
        events.add('delete-current-user');
        throw StateError('requires recent login');
      },
      clearLocalState: () => events.add('clear-local-state'),
      signInAnonymously: () async => events.add('sign-in-anonymously'),
    );

    await expectLater(
      service.deleteAccount(),
      throwsA(isA<StateError>()),
    );

    expect(events, ['delete-user-data', 'delete-current-user']);
  });
}
