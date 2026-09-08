import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/features/auth/invite_access.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<_Factory> factory() async {
    SharedPreferences.setMockInitialValues({});
    return _Factory(await SharedPreferences.getInstance(), _Auth());
  }

  for (final error in [
    const StateSyncConflict('state.age'),
    const StatePayloadTooLarge(1100000),
  ]) {
    test(
      'verified sign-in retains recovery for ${error.runtimeType}',
      () async {
        final f = await factory();
        final user = f.identity.user = _User('A');
        final prior = await f.open(user);
        await prior.repository.save(prior.state.copyWith(age: 30));
        f.cloud('A').syncError = error;
        await f.identity.signOut();
        final guest = await f.open(null);
        final container = ProviderContainer(
          overrides: [
            appStateRepositoryProvider.overrideWithValue(guest.repository),
            initialAppStateProvider.overrideWithValue(guest.state),
            trainingEngineStateRepositoryProvider.overrideWithValue(
              guest.engineRepository,
            ),
            accountRepositoryFactoryProvider.overrideWithValue(f),
            authServiceProvider.overrideWithValue(AuthService(f.identity)),
          ],
        );
        addTearDown(container.dispose);
        await container
            .read(accountSessionControllerProvider)
            .signIn(() async => f.identity.user = user);
        expect(f.identity.currentUser?.uid, 'A');
        expect(container.read(accountAccessAvailableProvider), isTrue);
        expect(container.read(appStateControllerProvider).age, 30);
        expect(
          container.read(appStateControllerProvider.notifier).repository,
          same(prior.repository),
        );
        expect(
          container.read(appSaveStatusProvider),
          error is StateSyncConflict
              ? AppSaveStatus.conflict
              : AppSaveStatus.capacityExceeded,
        );
        expect(prior.repository.hasPendingChanges, isTrue);
      },
    );
  }

  test(
    'a prior admission never permits requireOnline when verification is offline',
    () async {
      final f = await factory();
      final user = f.identity.user = _User('A');
      final context = await f.open(user);
      expect(context.accessAvailable, isTrue);
      f.online = false;
      await expectLater(f.open(user, requireOnline: true), throwsStateError);
      expect(f.identity.currentUser?.uid, 'A');
      expect(context.repository.hasCache, isTrue);
      expect(context.repository.isRetired, isFalse);
      await context.repository.save(context.state.copyWith(age: 41));
      f.online = true;
      expect((await context.repository.retry()).age, 41);
    },
  );

  test(
    'factory deletion retires pending sync before the account reopens',
    () async {
      final f = await factory();
      final user = f.identity.user = _User('A');
      final before = await f.open(user);
      await before.repository.save(before.state.copyWith(age: 30));
      final acknowledgement = f.cloud('A').acknowledgement = Completer<void>();
      final pending = before.repository.retry();
      await f.cloud('A').written.future;
      await f.clearAccount('A');
      expect(before.repository.isRetired, isTrue);
      // Account deletion removed cloud data before this local cleanup call.
      await f.cloud('A').save(AppState.empty());
      final after = await f.open(user, requireOnline: true);
      expect(after.repository, isNot(same(before.repository)));
      await after.repository.save(after.state.copyWith(age: 40));
      acknowledgement.complete();
      await pending;
      final fresh = _Factory(f.preferences, f.identity)..online = false;
      expect((await fresh.open(user)).state.age, 40);
    },
  );

  test('same UID and A to B to A use one live outbox owner', () async {
    final f = await factory();
    final a = f.identity.user = _User('A');
    final first = await f.open(a);
    final sameContext = await f.open(a, requireOnline: true);
    expect(sameContext.repository, same(first.repository));
    await first.repository.save(first.state.copyWith(age: 30));
    final acknowledgement = f.cloud('A').acknowledgement = Completer<void>();
    final pending = first.repository.retry();
    await f.cloud('A').written.future;
    await f.open(f.identity.user = _User('B'));
    f.identity.user = a;
    final returning = f.open(a, requireOnline: true);
    await Future<void>.delayed(Duration.zero);
    await first.repository.save(
      first.repository.currentState.copyWith(age: 40),
    );
    acknowledgement.complete();
    await pending;
    final returned = await returning;
    expect(returned.repository, same(first.repository));
    expect(returned.state.age, 40);
    expect(returned.repository.hasPendingChanges, isTrue);
    final fresh = _Factory(f.preferences, f.identity);
    fresh.online = false;
    expect((await fresh.open(a)).state.age, 40);
  });

  test(
    'reopening checks admission even when it can join an older sync',
    () async {
      final f = await factory();
      final user = f.identity.user = _User('A');
      final context = await f.open(user);
      await context.repository.save(context.state.copyWith(age: 30));
      final acknowledgement = f.cloud('A').acknowledgement = Completer<void>();
      final pending = context.repository.retry();
      await f.cloud('A').written.future;
      f.online = false;
      await expectLater(f.open(user, requireOnline: true), throwsStateError);
      acknowledgement.complete();
      await pending;
    },
  );
}

class _Auth implements FirebaseAuth {
  User? user;
  @override
  User? get currentUser => user;
  @override
  Future<void> signOut() async => user = null;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String get email => '$uid@example.invalid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Factory extends AccountRepositoryFactory {
  _Factory(SharedPreferences preferences, this.identity)
    : super(preferences: preferences, auth: identity);
  final _Auth identity;
  bool online = true;
  final _clouds = <String, _Cloud>{};
  _Cloud cloud(String id) => _clouds.putIfAbsent(
    id,
    () => _Cloud(() => verifyAccountAccess(_User(id))),
  );
  @override
  AppStateRepository createRemoteRepository(User user) => cloud(user.uid);
  @override
  Future<void> verifyAccountAccess(User user) async {
    if (!online) throw StateError('offline verification');
    if (identity.currentUser?.uid != user.uid) {
      throw InviteAccessDeniedException(user.email!);
    }
    await preferences.setBool('account_invitation_verified_${user.uid}', true);
  }
}

class _Cloud extends MemoryAppStateRepository
    implements MergingAppStateRepository {
  _Cloud(this.verify) : super(initialState: AppState.empty());
  final Future<void> Function() verify;
  Object? syncError;
  Completer<void>? acknowledgement;
  final written = Completer<void>();
  @override
  Future<AppState> load() async {
    await verify();
    return super.load();
  }

  @override
  Future<AppState> mergeAndSave(AppState base, AppState local) async {
    await verify();
    if (syncError != null) throw syncError!;
    final merged = mergeAppStates(base, local, await super.load());
    await super.save(merged);
    if (!written.isCompleted) written.complete();
    await acknowledgement?.future;
    return merged;
  }
}
