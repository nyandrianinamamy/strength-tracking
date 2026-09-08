import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/models/app_state.dart';
import '../data/repository/app_state_repository.dart';
import '../data/repository/account_app_state_repository.dart';

final initialAppStateProvider = Provider<AppState>(
  (ref) =>
      throw UnimplementedError('initialAppStateProvider must be overridden'),
);
final appStateRepositoryProvider = Provider<AppStateRepository>(
  (ref) =>
      throw UnimplementedError('appStateRepositoryProvider must be overridden'),
);

enum AppSaveStatus {
  saved,
  saving,
  local,
  pending,
  syncFailed,
  localFailed,
  conflict,
  capacityExceeded,
}

final appSaveStatusProvider = StateProvider<AppSaveStatus>(
  (ref) => AppSaveStatus.saved,
);
final appRepositoryDidSyncProvider =
    Provider<void Function(AppStateRepository)>((ref) => (_) {});
final appStateControllerProvider =
    NotifierProvider<AppStateController, AppState>(AppStateController.new);

class AppStateController extends Notifier<AppState> {
  late AppStateRepository _repository;
  AppStateRepository get repository => _repository;
  Future<void> _localWrites = Future.value();
  final _syncs = <AppStateRepository, Future<void>>{};
  Object? _localError;
  int _generation = 0;
  int _revision = 0;
  bool _disposed = false;
  bool _syncPaused = false;

  @override
  AppState build() {
    _repository = ref.watch(appStateRepositoryProvider);
    ref.onDispose(() => _disposed = true);
    return ref.watch(initialAppStateProvider);
  }

  void _status(AppSaveStatus value) {
    if (!_disposed) ref.read(appSaveStatusProvider.notifier).state = value;
  }

  AppSaveStatus get repositoryStatus {
    final repo = _repository;
    if (repo is! AccountAppStateRepository) return AppSaveStatus.saved;
    return switch (repo.syncStatus) {
      RepositorySyncStatus.local => AppSaveStatus.local,
      RepositorySyncStatus.synced => AppSaveStatus.saved,
      RepositorySyncStatus.pending => AppSaveStatus.pending,
      RepositorySyncStatus.failed =>
        repo.lastError is StatePayloadTooLarge
            ? AppSaveStatus.capacityExceeded
            : AppSaveStatus.syncFailed,
      RepositorySyncStatus.conflict => AppSaveStatus.conflict,
    };
  }

  void replaceState(AppState nextState) {
    state = nextState;
    _revision++;
    _status(AppSaveStatus.saving);
    final repository = _repository;
    final generation = _generation;
    _localWrites = _localWrites.catchError((Object _) {}).then((_) async {
      try {
        await repository.save(nextState);
        if (generation != _generation || _disposed) return;
        _localError = null;
        _status(repositoryStatus);
        unawaited(retrySave());
      } catch (error) {
        if (generation != _generation || _disposed) return;
        _localError = error;
        _status(AppSaveStatus.localFailed);
      }
    });
  }

  /// Account transitions wait for durable local writes, not network completion.
  Future<void> flushLocal() async {
    await _localWrites;
    if (_localError != null) {
      throw StateError('Local changes have not been saved');
    }
  }

  Future<void> bindRepository(
    AppStateRepository repository,
    AppState initialState,
  ) async {
    await flushLocal();
    commitRepositoryBinding(repository, initialState);
  }

  /// Called synchronously after flushLocal and after the account's companion
  /// bindings are staged, so app-state listeners cannot observe old ownership.
  void commitRepositoryBinding(
    AppStateRepository repository,
    AppState initialState,
  ) {
    if (_localError != null) {
      throw StateError('Local changes have not been saved');
    }
    _generation++;
    _revision++;
    _repository = repository;
    state = initialState;
    _status(repositoryStatus);
  }

  Future<void> retrySave() async {
    if (_disposed || _syncPaused) return;
    if (_localError != null) replaceState(state);
    await flushLocal().catchError((Object _) {});
    if (_localError != null || _disposed) return;
    final repository = _repository;
    if (repository is! AccountAppStateRepository) return;
    if (_syncs.containsKey(repository)) return _syncs[repository];
    final generation = _generation;
    final revision = _revision;
    final before = state;
    final operation = () async {
      final synchronized = await repository.retry();
      if (_disposed || generation != _generation) return;
      ref.read(appRepositoryDidSyncProvider)(repository);
      try {
        final updated = revision == _revision
            ? synchronized
            : mergeAppStates(before, state, synchronized);
        if (canonicalState(updated) != canonicalState(state)) {
          if (revision == _revision) {
            state = updated;
          } else {
            replaceState(updated);
          }
        }
        _status(repositoryStatus);
      } on StateSyncConflict {
        _status(AppSaveStatus.conflict);
      }
    }();
    _syncs[repository] = operation;
    try {
      await operation;
    } finally {
      _syncs.remove(repository);
      if (!_disposed &&
          generation == _generation &&
          !_syncPaused &&
          repository.hasPendingChanges &&
          repository.lastError == null) {
        unawaited(retrySave());
      }
    }
  }

  Future<void> pauseSync() async {
    _syncPaused = true;
    await flushLocal();
    await _syncs[_repository];
    final repo = _repository;
    if (repo is AccountAppStateRepository &&
        repo.remote is FirestoreAppStateRepository) {
      await (repo.remote as FirestoreAppStateRepository).waitForIdle();
    }
  }

  void resumeSync() {
    _syncPaused = false;
    unawaited(retrySave());
  }

  Future<void> resolveConflict({required bool keepDevice}) async {
    await flushLocal();
    final repo = _repository;
    if (repo is! AccountAppStateRepository) return;
    final generation = _generation;
    final resolved = await repo.resolveConflict(keepDevice: keepDevice);
    if (generation != _generation || _disposed) return;
    state = resolved;
    _revision++;
    _status(repositoryStatus);
  }

  Future<void> restoreRecoveryCopy() async {
    final repo = _repository;
    if (repo is! AccountAppStateRepository) return;
    final generation = _generation;
    final restored = await repo.restoreRecoveryCopy();
    if (_disposed || generation != _generation || !identical(repo, _repository)) {
      return;
    }
    replaceState(restored);
  }

  void clearLocal() {
    state = AppState.empty();
    _revision++;
  }

  void updateState(AppState Function(AppState) update) =>
      replaceState(update(state));
}
