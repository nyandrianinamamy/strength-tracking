import 'dart:async';

class AccountDeletionCancelled implements Exception {
  const AccountDeletionCancelled();
}

class AccountDeletionRollbackFailure implements Exception {
  const AccountDeletionRollbackFailure({
    required this.authError,
    required this.rollbackError,
  });

  final Object authError;
  final Object rollbackError;

  @override
  String toString() =>
      'Account deletion failed and cloud data recovery also failed. '
      'Authentication error: $authError. Recovery error: $rollbackError';
}

class AccountDeletionResult {
  const AccountDeletionResult({this.providerCleanupError});
  final Object? providerCleanupError;
  bool get accountDeleted => true;
}

class AccountDeletionService<T> {
  const AccountDeletionService({
    required this.reauthenticate,
    required this.deleteUserData,
    required this.deleteCurrentUser,
    required this.restoreUserData,
    required this.clearLocalState,
    this.finalizeProviderDeletion,
  });

  /// Reauthenticates the current provider and returns a cloud-state snapshot.
  final Future<T> Function() reauthenticate;
  final Future<void> Function() deleteUserData;
  final Future<void> Function() deleteCurrentUser;
  final Future<void> Function(T backup) restoreUserData;
  final FutureOr<void> Function() clearLocalState;
  final Future<void> Function()? finalizeProviderDeletion;

  Future<AccountDeletionResult> deleteAccount() async {
    final backup = await reauthenticate();
    await deleteUserData();
    try {
      await deleteCurrentUser();
    } catch (authError) {
      try {
        await restoreUserData(backup);
      } catch (rollbackError) {
        throw AccountDeletionRollbackFailure(
          authError: authError,
          rollbackError: rollbackError,
        );
      }
      rethrow;
    }
    await clearLocalState();
    try {
      await finalizeProviderDeletion?.call();
      return const AccountDeletionResult();
    } catch (error) {
      return AccountDeletionResult(providerCleanupError: error);
    }
  }
}
