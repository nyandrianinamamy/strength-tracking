import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/app_state_controller.dart';
import '../../data/models/app_state.dart';
import '../../data/repository/account_app_state_repository.dart';
import '../../data/repository/app_state_repository.dart';
import '../training_engine/training_engine_provider.dart';
import '../training_engine/training_engine_state_repository.dart';
import 'auth_service.dart';
import 'invite_access.dart';

final accountAccessAvailableProvider = StateProvider<bool>((ref) => false);
final boundAccountIdProvider = StateProvider<String?>((ref) => null);
final accountTransitionInProgressProvider = StateProvider<bool>((ref) => false);
final accountRepositoryFactoryProvider = Provider<AccountRepositoryFactory?>(
  (ref) => null,
);
final accountSessionControllerProvider = Provider<AccountSessionController>(
  AccountSessionController.new,
);

class AccountContext {
  const AccountContext({
    required this.repository,
    required this.engineRepository,
    required this.state,
    required this.accessAvailable,
  });
  final AccountAppStateRepository repository;
  final TrainingEngineStateRepository engineRepository;
  final AppState state;
  final bool accessAvailable;
}

class AccountRepositoryFactory {
  AccountRepositoryFactory({
    required this.preferences,
    this.auth,
    this.firestore,
  });
  final SharedPreferences preferences;
  final FirebaseAuth? auth;
  final FirebaseFirestore? firestore;
  final _repositories = <String?, AccountAppStateRepository>{};

  bool hasVerifiedAccess(AccountAppStateRepository repository) {
    final id = repository.accountId;
    return id != null &&
        auth?.currentUser?.uid == id &&
        repository.hasCache &&
        preferences.getBool(
              'account_invitation_verified_${Uri.encodeComponent(id)}',
            ) ==
            true;
  }

  /// Constructs the immutable account backend. Overridable by isolated tests;
  /// production backends always verify the current user's invitation.
  AppStateRepository createRemoteRepository(User user) {
    final id = user.uid;
    return auth == null || firestore == null
        ? const _UnavailableAccountRepository()
        : FirestoreAppStateRepository(
            auth: auth!,
            firestore: firestore,
            userId: id,
            verifyAccess: () => verifyAccountAccess(user),
          );
  }

  Future<void> verifyAccountAccess(User user) async {
    final admissionKey =
        'account_invitation_verified_${Uri.encodeComponent(user.uid)}';
    try {
      final current = auth?.currentUser;
      if (current == null || current.uid != user.uid) {
        throw StateError('Account ownership changed');
      }
      if (firestore == null) throw StateError('Account connection unavailable');
      await InviteAccessService(
        firestore: firestore,
      ).requireAllowed(current).timeout(const Duration(seconds: 8));
      if (auth?.currentUser?.uid != user.uid) {
        throw StateError('Account ownership changed');
      }
      await preferences.setBool(admissionKey, true);
    } on InviteAccessDeniedException {
      await preferences.remove(admissionKey);
      rethrow;
    } on FirebaseException catch (error) {
      if (error.code == 'permission-denied') {
        await preferences.remove(admissionKey);
        throw InviteAccessDeniedException(user.email ?? '');
      }
      rethrow;
    }
  }

  Future<AccountContext> open(User? user, {bool requireOnline = false}) async {
    // This derived cache has no owner, so retaining it could expose a previous
    // account's HealthKit readings. App history is retained and rebuilt instead.
    await preferences.remove('training_engine_state_v1');
    final id = user?.uid;
    var verifiedForThisOpen = false;
    if (requireOnline && user != null) {
      await verifyAccountAccess(user);
      verifiedForThisOpen = true;
    }
    var repository = _repositories[id];
    if (repository == null || repository.isRetired) {
      repository = _repositories[id] = AccountAppStateRepository(
        preferences: preferences,
        accountId: id,
        remote: user == null ? null : createRemoteRepository(user),
      );
    }
    final state = await repository.load();
    if (repository.isRetired) {
      throw StateError('Account storage owner was replaced');
    }
    if (repository.lastError is InviteAccessDeniedException) {
      throw repository.lastError!;
    }
    final canRecoverLocally =
        verifiedForThisOpen &&
        hasVerifiedAccess(repository) &&
        (repository.lastError is StateSyncConflict ||
            repository.lastError is StatePayloadTooLarge);
    if (requireOnline && repository.lastError != null && !canRecoverLocally) {
      throw repository.lastError!;
    }
    return AccountContext(
      repository: repository,
      engineRepository: SharedPreferencesTrainingEngineStateRepository(
        preferences,
        accountId: id,
      ),
      state: state,
      accessAvailable: hasVerifiedAccess(repository),
    );
  }

  Future<void> clearAccount(String id) async {
    final cached = _repositories.remove(id);
    final repo = cached != null && !cached.isRetired
        ? cached
        : AccountAppStateRepository(preferences: preferences, accountId: id);
    await repo.clearLocalData();
    await SharedPreferencesTrainingEngineStateRepository(
      preferences,
      accountId: id,
    ).clear();
    await preferences.remove(
      'account_invitation_verified_${Uri.encodeComponent(id)}',
    );
    if (preferences.getString('legacy_state_recovery_owner') == id) {
      await preferences.remove('strength_training_tracker_state_v1');
      await preferences.remove('legacy_state_recovery_owner');
    }
  }
}

class AccountSessionController {
  AccountSessionController(this.ref);
  final Ref ref;
  AccountRepositoryFactory get _factory =>
      ref.read(accountRepositoryFactoryProvider) ??
      (throw StateError('Account persistence is unavailable'));
  AppStateController get _app => ref.read(appStateControllerProvider.notifier);

  Future<void> _bind(AccountContext context) async {
    await _app.flushLocal();
    final previousEngine = ref.read(accountTrainingEngineRepositoryProvider);
    final previousAccess = ref.read(accountAccessAvailableProvider);
    final previousId = ref.read(boundAccountIdProvider);
    try {
      ref.read(accountTrainingEngineRepositoryProvider.notifier).state =
          context.engineRepository;
      ref.read(accountAccessAvailableProvider.notifier).state =
          context.accessAvailable;
      ref.read(boundAccountIdProvider.notifier).state =
          context.repository.accountId;
      // No await between staging ownership and publishing the new app state.
      _app.commitRepositoryBinding(context.repository, context.state);
    } catch (_) {
      ref.read(accountTrainingEngineRepositoryProvider.notifier).state =
          previousEngine;
      ref.read(accountAccessAvailableProvider.notifier).state = previousAccess;
      ref.read(boundAccountIdProvider.notifier).state = previousId;
      rethrow;
    }
  }

  Future<void> _guest({bool clear = false}) async {
    final context = await _factory.open(null);
    if (clear) await context.repository.save(AppState.empty());
    await _bind(
      AccountContext(
        repository: context.repository,
        engineRepository: context.engineRepository,
        state: clear ? AppState.empty() : context.state,
        accessAvailable: false,
      ),
    );
  }

  Future<void> signIn(Future<User> Function() authenticate) async {
    if (ref.read(accountTransitionInProgressProvider)) {
      throw StateError('Account transition already running');
    }
    await _app.flushLocal();
    final auth = ref.read(authServiceProvider);
    final previousId = auth.currentUser?.uid;
    ref.read(accountTransitionInProgressProvider.notifier).state = true;
    try {
      final user = await authenticate();
      final context = await _factory.open(user, requireOnline: true);
      await _bind(context);
    } catch (error) {
      if (error is InviteAccessDeniedException ||
          auth.currentUser?.uid != previousId) {
        try {
          await auth.signOut();
        } finally {
          await _guest(clear: previousId != null);
        }
      }
      rethrow;
    } finally {
      ref.read(accountTransitionInProgressProvider.notifier).state = false;
    }
  }

  Future<void> signOut() async {
    await _app.flushLocal();
    ref.read(accountTransitionInProgressProvider.notifier).state = true;
    try {
      await ref.read(authServiceProvider).signOut();
      await _guest(clear: true);
    } catch (_) {
      if (ref.read(authServiceProvider).currentUser == null) {
        await _guest(clear: true);
      }
      rethrow;
    } finally {
      ref.read(accountTransitionInProgressProvider.notifier).state = false;
    }
  }

  Future<void> accountDeleted(String id) async {
    await _factory.clearAccount(id);
    await _guest(clear: true);
  }
}

class _UnavailableAccountRepository implements AppStateRepository {
  const _UnavailableAccountRepository();
  @override
  Future<AppState> load() async =>
      throw StateError('Account connection unavailable');
  @override
  Future<void> save(AppState state) async =>
      throw StateError('Account connection unavailable');
  @override
  Future<void> deleteUserData() async =>
      throw StateError('Account connection unavailable');
}
