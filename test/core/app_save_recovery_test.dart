import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';

void main() {
  test(
    'a failed local write remains visible and retry saves the latest state',
    () async {
      final repository = _FailsOnce();
      final container = ProviderContainer(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(repository),
          initialAppStateProvider.overrideWithValue(AppState.empty()),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(appStateControllerProvider.notifier);
      controller.updateState((state) => state.copyWith(userName: 'Keep me'));
      await expectLater(controller.flushLocal(), throwsStateError);
      expect(container.read(appSaveStatusProvider), AppSaveStatus.localFailed);
      expect(container.read(appStateControllerProvider).userName, 'Keep me');
      await controller.retrySave();
      expect(repository.state.userName, 'Keep me');
      expect(container.read(appSaveStatusProvider), AppSaveStatus.saved);
    },
  );

  test(
    'account switching waits for the old local write and never sends it to the new repository',
    () async {
      final first = _DelayedSave();
      final second = MemoryAppStateRepository(initialState: AppState.empty());
      final container = ProviderContainer(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(first),
          initialAppStateProvider.overrideWithValue(AppState.empty()),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(appStateControllerProvider.notifier);
      controller.updateState(
        (state) => state.copyWith(userName: 'First account'),
      );
      final switchAccount = controller.bindRepository(
        second,
        AppState.empty().copyWith(userName: 'Second account'),
      );
      await Future<void>.delayed(Duration.zero);
      expect(controller.repository, same(first));
      first.release.complete();
      await switchAccount;
      expect(first.state.userName, 'First account');
      expect(second.state.userName, isEmpty);
      expect(
        container.read(appStateControllerProvider).userName,
        'Second account',
      );
      controller.updateState((state) => state.copyWith(age: 45));
      await controller.flushLocal();
      expect(second.state.age, 45);
      expect(first.state.age, isNull);
    },
  );
  test(
    'a delayed recovery from account A cannot replace or save account B',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final first = _DelayedRecovery(await SharedPreferences.getInstance());
      final secondState = AppState.empty().copyWith(userName: 'Account B');
      final second = MemoryAppStateRepository(initialState: secondState);
      final container = ProviderContainer(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(first),
          initialAppStateProvider.overrideWithValue(
            AppState.empty().copyWith(userName: 'Account A'),
          ),
        ],
      );
      addTearDown(container.dispose);
      final controller = container.read(appStateControllerProvider.notifier);
      final recovery = controller.restoreRecoveryCopy();
      await controller.bindRepository(second, secondState);
      first.release.complete(
        AppState.empty().copyWith(userName: 'A private recovery'),
      );
      await recovery;
      await controller.flushLocal();
      expect(container.read(appStateControllerProvider).userName, 'Account B');
      expect(second.state.userName, 'Account B');
    },
  );
}

class _FailsOnce extends MemoryAppStateRepository {
  _FailsOnce() : super(initialState: AppState.empty());
  bool fail = true;
  @override
  Future<void> save(AppState state) async {
    if (fail) {
      fail = false;
      throw StateError('disk unavailable');
    }
    await super.save(state);
  }
}

class _DelayedSave extends MemoryAppStateRepository {
  _DelayedSave() : super(initialState: AppState.empty());
  final release = Completer<void>();
  @override
  Future<void> save(AppState state) async {
    await release.future;
    await super.save(state);
  }
}

class _DelayedRecovery extends AccountAppStateRepository {
  _DelayedRecovery(SharedPreferences preferences)
    : super(preferences: preferences, accountId: 'A');
  final release = Completer<AppState>();
  @override
  Future<AppState> restoreRecoveryCopy() => release.future;
}
