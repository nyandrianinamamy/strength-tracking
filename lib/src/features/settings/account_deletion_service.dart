class AccountDeletionService {
  const AccountDeletionService({
    required this.deleteUserData,
    required this.deleteCurrentUser,
    required this.clearLocalState,
    required this.signInAnonymously,
  });

  final Future<void> Function() deleteUserData;
  final Future<void> Function() deleteCurrentUser;
  final void Function() clearLocalState;
  final Future<void> Function() signInAnonymously;

  Future<void> deleteAccount() async {
    await deleteUserData();
    await deleteCurrentUser();
    clearLocalState();
    await signInAnonymously();
  }
}
