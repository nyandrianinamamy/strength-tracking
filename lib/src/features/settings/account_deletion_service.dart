class AccountDeletionService {
  const AccountDeletionService({
    required this.deleteUserData,
    required this.deleteCurrentUser,
    required this.clearLocalState,
    this.revokeAppleToken,
  });

  final Future<void> Function() deleteUserData;
  final Future<void> Function() deleteCurrentUser;
  final void Function() clearLocalState;
  final Future<void> Function(String authorizationCode)? revokeAppleToken;

  Future<void> deleteAccount({String? appleAuthorizationCode}) async {
    if (appleAuthorizationCode != null && revokeAppleToken != null) {
      await revokeAppleToken!(appleAuthorizationCode);
    }
    await deleteUserData();
    await deleteCurrentUser();
    clearLocalState();
  }
}
