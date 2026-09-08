import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final deleteFirst in [false, true]) {
    test(
      'late retired account sync cannot overwrite replacement edits (delete=$deleteFirst)',
      () async {
        SharedPreferences.setMockInitialValues({});
        final preferences = await SharedPreferences.getInstance();
        final cloud = _DelayedAcknowledgement();
        final old = AccountAppStateRepository(
          preferences: preferences,
          accountId: 'A',
          remote: cloud,
        );
        await old.load();
        await old.save(AppState.empty().copyWith(age: 30));
        final oldSync = old.retry();
        await cloud.written.future;
        if (deleteFirst) await old.clearLocalData();
        final replacement = AccountAppStateRepository(
          preferences: preferences,
          accountId: 'A',
          remote: _UnavailableRepository(),
        );
        await replacement.load();
        await replacement.save(AppState.empty().copyWith(age: 40));
        cloud.acknowledge.complete();
        await oldSync;
        final persisted = await AccountAppStateRepository(
          preferences: preferences,
          accountId: 'A',
        ).load();
        expect(
          persisted.age,
          40,
          reason:
              'The old acknowledgement must not erase the replacement outbox.',
        );
      },
    );
  }

  test(
    'offline edits survive repository recreation and synchronize only their account',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final remote = _UnavailableRepository();
      final first = AccountAppStateRepository(
        preferences: preferences,
        accountId: 'A',
        remote: remote,
      );
      await first.load();
      await first.save(AppState.empty().copyWith(userName: 'Offline A'));
      await first.retry();
      final restarted = AccountAppStateRepository(
        preferences: preferences,
        accountId: 'A',
        remote: remote,
      );
      expect((await restarted.load()).userName, 'Offline A');
      final other = AccountAppStateRepository(
        preferences: preferences,
        accountId: 'B',
        remote: remote,
      );
      expect((await other.load()).userName, isEmpty);
    },
  );

  test(
    'reconnect after an uncached cold start loads the account instead of staying empty',
    () async {
      SharedPreferences.setMockInitialValues({});
      final remote = _SwitchableRepository(
        AppState.empty().copyWith(userName: 'Cloud A'),
      );
      final repository = AccountAppStateRepository(
        preferences: await SharedPreferences.getInstance(),
        accountId: 'A',
        remote: remote,
      );
      expect((await repository.load()).userName, isEmpty);
      remote.available = true;
      expect((await repository.retry()).userName, 'Cloud A');
    },
  );
  test(
    'uncached offline edits merge into a nonempty account without deleting either copy',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cloud = _SwitchableRepository(
        AppState.empty().copyWith(userName: 'Existing Account'),
      );
      final repo = AccountAppStateRepository(
        preferences: prefs,
        accountId: 'A',
        remote: cloud,
      );
      await repo.load();
      await repo.save(AppState.empty().copyWith(exercises: [_exercise]));
      cloud.available = true;
      final merged = await repo.retry();
      expect(merged.userName, 'Existing Account');
      expect(merged.exercises.single.id, 'offline-exercise');
      expect((await cloud.load()).exercises.single.id, 'offline-exercise');
      expect(repo.syncStatus, RepositorySyncStatus.synced);
    },
  );

  test(
    'conflicting edits retain both copies until an explicit recovery decision',
    () async {
      SharedPreferences.setMockInitialValues({});
      final cloud = MemoryAppStateRepository(
        initialState: AppState.empty().copyWith(age: 20),
      );
      final repo = AccountAppStateRepository(
        preferences: await SharedPreferences.getInstance(),
        accountId: 'A',
        remote: cloud,
      );
      final initial = await repo.load();
      await repo.save(initial.copyWith(age: 30));
      await cloud.save(initial.copyWith(age: 40));
      await repo.retry();
      expect(repo.syncStatus, RepositorySyncStatus.conflict);
      expect(repo.currentState.age, 30);
      expect((await cloud.load()).age, 40);
      expect((await repo.resolveConflict(keepDevice: false)).age, 40);
      expect(repo.hasRecoveryCopy, isTrue);
      expect((await repo.restoreRecoveryCopy()).age, 30);
    },
  );

  test(
    'a realistic embedded photo exceeding cloud capacity stays in the durable outbox',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cloud = _SizedRepository();
      final repo = AccountAppStateRepository(
        preferences: prefs,
        accountId: 'A',
        remote: cloud,
      );
      await repo.load();
      final photo = List.filled(1100000, 'A').join();
      await repo.save(
        AppState.empty().copyWith(
          exercises: [_exercise.copyWith(photoBase64: photo)],
        ),
      );
      await repo.retry();
      expect(repo.lastError, isA<StatePayloadTooLarge>());
      expect(repo.hasPendingChanges, isTrue);
      expect((await cloud.load()).exercises, isEmpty);
      final restarted = AccountAppStateRepository(
        preferences: prefs,
        accountId: 'A',
        remote: cloud,
      );
      expect((await restarted.load()).exercises.single.photoBase64, photo);
      await restarted.save(
        restarted.currentState.copyWith(exercises: [_exercise]),
      );
      await restarted.retry();
      expect(restarted.syncStatus, RepositorySyncStatus.synced);
      expect((await cloud.load()).exercises.single.photoBase64, isNull);
    },
  );
}

class _UnavailableRepository implements AppStateRepository {
  @override
  Future<AppState> load() async => throw StateError('offline');
  @override
  Future<void> save(AppState state) async => throw StateError('offline');
  @override
  Future<void> deleteUserData() async => throw StateError('offline');
}

class _SwitchableRepository extends MemoryAppStateRepository {
  _SwitchableRepository(AppState state) : super(initialState: state);
  bool available = false;
  @override
  Future<AppState> load() async {
    if (!available) throw StateError('offline');
    return super.load();
  }
}

const _exercise = Exercise(
  id: 'offline-exercise',
  name: 'Offline exercise',
  primaryMuscles: ['Chest'],
  equipment: [],
  instructions: '',
  archived: false,
);

class _SizedRepository extends MemoryAppStateRepository {
  _SizedRepository() : super(initialState: AppState.empty());
  @override
  Future<void> save(AppState state) async {
    FirestoreAppStateRepository.validatePayload(state);
    await super.save(state);
  }
}

class _DelayedAcknowledgement extends MemoryAppStateRepository
    implements MergingAppStateRepository {
  _DelayedAcknowledgement() : super(initialState: AppState.empty());
  final written = Completer<void>();
  final acknowledge = Completer<void>();
  @override
  Future<AppState> mergeAndSave(AppState base, AppState local) async {
    final merged = mergeAppStates(base, local, await super.load());
    await super.save(merged);
    written.complete();
    await acknowledge.future;
    return merged;
  }
}
