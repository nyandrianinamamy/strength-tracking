import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/features/settings/account_deletion_service.dart';

void main() {
  test('reauthenticates before deleting cloud, auth, and local data', () async {
    final events = <String>[];
    final service = AccountDeletionService<String>(
      reauthenticate: () async {
        events.add('reauthenticate');
        return 'backup';
      },
      deleteUserData: () async => events.add('delete-user-data'),
      deleteCurrentUser: () async => events.add('delete-current-user'),
      restoreUserData: (backup) async => events.add('restore-$backup'),
      clearLocalState: () => events.add('clear-local-state'),
    );

    await service.deleteAccount();

    expect(events, [
      'reauthenticate',
      'delete-user-data',
      'delete-current-user',
      'clear-local-state',
    ]);
  });

  test('cancellation leaves cloud, auth, and local data untouched', () async {
    final events = <String>[];
    final service = AccountDeletionService<String>(
      reauthenticate: () async => throw const AccountDeletionCancelled(),
      deleteUserData: () async => events.add('delete-user-data'),
      deleteCurrentUser: () async => events.add('delete-current-user'),
      restoreUserData: (_) async => events.add('restore-user-data'),
      clearLocalState: () => events.add('clear-local-state'),
    );

    await expectLater(
      service.deleteAccount(),
      throwsA(isA<AccountDeletionCancelled>()),
    );
    expect(events, isEmpty);
  });

  test('cloud deletion failure leaves auth and local data untouched', () async {
    final events = <String>[];
    final service = AccountDeletionService<String>(
      reauthenticate: () async => 'backup',
      deleteUserData: () async => throw StateError('cloud unavailable'),
      deleteCurrentUser: () async => events.add('delete-current-user'),
      restoreUserData: (_) async => events.add('restore-user-data'),
      clearLocalState: () => events.add('clear-local-state'),
    );

    await expectLater(service.deleteAccount(), throwsA(isA<StateError>()));
    expect(events, isEmpty);
  });

  test(
    'auth deletion failure restores cloud and preserves local data',
    () async {
      final events = <String>[];
      final service = AccountDeletionService<String>(
        reauthenticate: () async => 'backup',
        deleteUserData: () async => events.add('delete-user-data'),
        deleteCurrentUser: () async {
          events.add('delete-current-user');
          throw StateError('auth failure');
        },
        restoreUserData: (backup) async => events.add('restore-$backup'),
        clearLocalState: () => events.add('clear-local-state'),
      );

      await expectLater(service.deleteAccount(), throwsA(isA<StateError>()));
      expect(events, [
        'delete-user-data',
        'delete-current-user',
        'restore-backup',
      ]);
    },
  );

  test('reports both auth and rollback failures when recovery fails', () async {
    final service = AccountDeletionService<String>(
      reauthenticate: () async => 'backup',
      deleteUserData: () async {},
      deleteCurrentUser: () async => throw StateError('auth failure'),
      restoreUserData: (_) async => throw StateError('restore failure'),
      clearLocalState: () {},
    );

    await expectLater(
      service.deleteAccount(),
      throwsA(
        isA<AccountDeletionRollbackFailure>()
            .having((e) => e.authError, 'authError', isA<StateError>())
            .having((e) => e.rollbackError, 'rollbackError', isA<StateError>()),
      ),
    );
  });

  test('revokes provider token only after auth deletion succeeds', () async {
    final events = <String>[];
    final service = AccountDeletionService<String>(
      reauthenticate: () async => 'backup',
      deleteUserData: () async => events.add('delete-user-data'),
      deleteCurrentUser: () async => events.add('delete-current-user'),
      restoreUserData: (_) async => events.add('restore-user-data'),
      clearLocalState: () => events.add('clear-local-state'),
      finalizeProviderDeletion: () async => events.add('revoke-provider-token'),
    );

    await service.deleteAccount();

    expect(events, [
      'delete-user-data',
      'delete-current-user',
      'clear-local-state',
      'revoke-provider-token',
    ]);
  });

  test(
    'does not revoke provider token when auth deletion rolls back',
    () async {
      final events = <String>[];
      final service = AccountDeletionService<String>(
        reauthenticate: () async => 'backup',
        deleteUserData: () async => events.add('delete-user-data'),
        deleteCurrentUser: () async => throw StateError('auth failure'),
        restoreUserData: (_) async => events.add('restore-user-data'),
        clearLocalState: () => events.add('clear-local-state'),
        finalizeProviderDeletion: () async =>
            events.add('revoke-provider-token'),
      );

      await expectLater(service.deleteAccount(), throwsA(isA<StateError>()));
      expect(events, ['delete-user-data', 'restore-user-data']);
    },
  );

  test('returns provider cleanup warning after deletion is complete', () async {
    final events = <String>[];
    final service = AccountDeletionService<String>(
      reauthenticate: () async => 'backup',
      deleteUserData: () async {},
      deleteCurrentUser: () async {},
      restoreUserData: (_) async {},
      clearLocalState: () => events.add('clear-local-state'),
      finalizeProviderDeletion: () async => throw StateError('revoke failure'),
    );

    final result = await service.deleteAccount();

    expect(result.accountDeleted, isTrue);
    expect(result.providerCleanupError, isA<StateError>());
    expect(events, ['clear-local-state']);
  });
}
