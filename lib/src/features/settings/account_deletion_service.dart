class AccountDeletionService {
  const AccountDeletionService({
    required this.deleteUserData,
    required this.deleteCurrentUser,
    required this.clearLocalState,
  });

  final Future<void> Function() deleteUserData;
  final Future<void> Function() deleteCurrentUser;
  final void Function() clearLocalState;

  Future<void> deleteAccount() async {
    await deleteUserData();
    await deleteCurrentUser();
    clearLocalState();
  }
}
