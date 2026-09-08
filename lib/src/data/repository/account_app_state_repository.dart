import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../models/app_state.dart';
import 'app_state_repository.dart';

enum RepositorySyncStatus { local, synced, pending, failed, conflict }

class StateSyncConflict implements Exception {
  const StateSyncConflict(this.field);
  final String field;
  @override
  String toString() => 'Both account copies changed $field';
}

/// Cloud implementations make the read/merge/write atomic. Test/local stores
/// can use the same public repository contract without a Firebase dependency.
abstract interface class MergingAppStateRepository {
  Future<AppState> mergeAndSave(AppState base, AppState local);
}

String canonicalState(AppState state) => jsonEncode(_canonical(state.toJson()));

Object? _canonical(Object? value) {
  if (value is Map) {
    return {
      for (final key in value.keys.cast<String>().toList()..sort())
        key: _canonical(value[key]),
    };
  }
  if (value is List) return value.map(_canonical).toList();
  return value;
}

bool _same(Object? a, Object? b) =>
    jsonEncode(_canonical(a)) == jsonEncode(_canonical(b));

/// Preserve independent edits. Conflicting edits to the same field or record
/// require a user decision; neither copy is silently overwritten.
AppState mergeAppStates(AppState base, AppState local, AppState remote) {
  Object? merge(Object? before, Object? ours, Object? theirs, String path) {
    if (_same(ours, before)) return theirs;
    if (_same(theirs, before) || _same(ours, theirs)) return ours;
    if (before is Map && ours is Map && theirs is Map) {
      return {
        for (final key in {...before.keys, ...ours.keys, ...theirs.keys})
          key: merge(before[key], ours[key], theirs[key], '$path.$key'),
      };
    }
    if (before is List &&
        ours is List &&
        theirs is List &&
        [
          ...before,
          ...ours,
          ...theirs,
        ].every((e) => e is Map && e['id'] is String)) {
      final original = {for (final e in before) e['id'] as String: e};
      final current = {for (final e in ours) e['id'] as String: e};
      final cloud = {for (final e in theirs) e['id'] as String: e};
      return [
        for (final id in {...current.keys, ...cloud.keys, ...original.keys})
          if (merge(original[id], current[id], cloud[id], '$path[$id]')
              case final Object item)
            item,
      ];
    }
    throw StateSyncConflict(path);
  }

  return AppState.fromJson(
    Map<String, dynamic>.from(
      merge(base.toJson(), local.toJson(), remote.toJson(), 'state') as Map,
    ),
  );
}

class _AccountStorage {
  AccountAppStateRepository? owner;
  Future<void> writes = Future.value();

  Future<void> enqueue(Future<void> Function() action) {
    final next = writes.catchError((Object _) {}).then((_) => action());
    // A failed old operation must not poison a replacement owner's queue.
    // Its own caller still receives the failure through next.
    writes = next.catchError((Object _) {});
    return next;
  }
}

/// A durable outbox with an immutable account backend and a single local owner.
/// Replacement owners retire delayed callbacks before they can persist.
class AccountAppStateRepository implements AppStateRepository {
  AccountAppStateRepository({
    required this.preferences,
    required this.accountId,
    this.remote,
  }) {
    final accounts = _storageByPreferences[preferences] ??= {};
    _storage = accounts.putIfAbsent(storageKey, _AccountStorage.new);
    _storage.owner = this;
  }

  // SharedPreferences is a singleton within an app process. Weak keys prevent
  // owners from surviving a replaced preferences instance in isolated tests.
  static final _storageByPreferences = Expando<Map<String, _AccountStorage>>();
  late final _AccountStorage _storage;
  bool get isRetired => !identical(_storage.owner, this);
  void _ensureOwner() {
    if (isRetired) throw StateError('Account storage owner was replaced');
  }

  final SharedPreferences preferences;
  final String? accountId;
  final AppStateRepository? remote;
  String get storageKey =>
      'account_state_v2_${(accountId == null ? "guest" : "user_${Uri.encodeComponent(accountId!)}")}';
  String get _recoveryKey => '${storageKey}_recovery';
  AppState _state = AppState.empty();
  AppState? _base;
  bool _pending = false;
  int _revision = 0;
  Future<void> get _writes => _storage.writes;
  bool _loaded = false;
  Future<AppState>? _loading;
  Future<AppState>? _sync;
  bool hasCache = false;
  Object? lastError;
  RepositorySyncStatus syncStatus = RepositorySyncStatus.local;
  AppState get currentState => _state;
  bool get hasPendingChanges => _pending;
  bool get hasRecoveryCopy =>
      preferences.containsKey(_recoveryKey) ||
      preferences.containsKey('strength_training_tracker_state_v1');

  Future<void> _serialized(Future<void> Function() action) {
    return _storage.enqueue(() async {
      _ensureOwner();
      await action();
    });
  }

  Future<void> _persist() async {
    _ensureOwner();
    final ok = await preferences.setString(
      storageKey,
      jsonEncode({
        'state': _state.toJson(),
        'base': _base?.toJson(),
        'pending': _pending,
      }),
    );
    if (!ok) throw StateError('Local state could not be saved');
    hasCache = true;
  }

  @override
  Future<AppState> load() {
    if (_loading != null) return _loading!;
    if (_loaded) return retry();
    return _loading = _loadInitial().whenComplete(() => _loading = null);
  }

  Future<AppState> _loadInitial() async {
    await _writes;
    _ensureOwner();
    final raw = preferences.getString(storageKey);
    if (raw != null) {
      final value = jsonDecode(raw) as Map<String, dynamic>;
      _state = AppState.fromJson(value['state'] as Map<String, dynamic>);
      final base = value['base'];
      _base = base == null
          ? null
          : AppState.fromJson(base as Map<String, dynamic>);
      _pending = value['pending'] as bool? ?? false;
      hasCache = true;
    }
    _loaded = true;
    if (remote == null) {
      syncStatus = RepositorySyncStatus.local;
      return _state;
    }
    return retry();
  }

  @override
  Future<void> save(AppState state) => _serialized(() => _saveState(state));

  Future<void> _saveState(AppState state) async {
    _loaded = true;
    _state = state;
    _pending = remote != null;
    _revision++;
    await _persist();
    syncStatus = remote == null
        ? RepositorySyncStatus.local
        : RepositorySyncStatus.pending;
  }

  Future<AppState> retry() =>
      _sync ??= _retry().whenComplete(() => _sync = null);

  Future<AppState> _retry() async {
    await _writes;
    if (isRetired) return _state;
    final cloud = remote;
    if (cloud == null) return _state;
    if (!_pending) {
      try {
        final refreshed = await cloud.load();
        await _serialized(() async {
          // An edit may have arrived while the server read was in flight.
          if (!_pending) {
            _state = refreshed;
            _base = refreshed;
            await _persist();
          }
        });
        lastError = null;
        syncStatus = _pending
            ? RepositorySyncStatus.pending
            : RepositorySyncStatus.synced;
      } catch (error) {
        lastError = error;
        syncStatus = RepositorySyncStatus.failed;
      }
      return _state;
    }
    final local = _state;
    final base = _base ?? AppState.empty();
    final revision = _revision;
    try {
      final AppState merged;
      if (cloud is MergingAppStateRepository) {
        merged = await (cloud as MergingAppStateRepository).mergeAndSave(
          base,
          local,
        );
      } else {
        merged = mergeAppStates(base, local, await cloud.load());
        await cloud.save(merged);
      }
      await _serialized(() async {
        _state = revision == _revision
            ? merged
            : mergeAppStates(local, _state, merged);
        _base = merged;
        _pending = revision != _revision;
        await _persist();
      });
      lastError = null;
      syncStatus = _pending
          ? RepositorySyncStatus.pending
          : RepositorySyncStatus.synced;
    } catch (error) {
      lastError = error;
      syncStatus = error is StateSyncConflict
          ? RepositorySyncStatus.conflict
          : RepositorySyncStatus.failed;
    }
    return _state;
  }

  Future<AppState> resolveConflict({required bool keepDevice}) async {
    await _writes;
    _ensureOwner();
    final cloud = remote;
    if (cloud == null) return _state;
    final latest = await cloud.load();
    await _serialized(() async {
      final recovery = keepDevice ? latest : _state;
      if (!await preferences.setString(
        _recoveryKey,
        jsonEncode(recovery.toJson()),
      )) {
        throw StateError('Recovery copy could not be saved');
      }
      _base = latest;
      if (!keepDevice) _state = latest;
      _pending = keepDevice;
      _revision++;
      await _persist();
    });
    lastError = null;
    syncStatus = keepDevice
        ? RepositorySyncStatus.pending
        : RepositorySyncStatus.synced;
    return keepDevice ? retry() : _state;
  }

  Future<AppState> restoreRecoveryCopy() async {
    await _serialized(() async {
      final ownRecovery = preferences.getString(_recoveryKey);
      final raw =
          ownRecovery ??
          preferences.getString('strength_training_tracker_state_v1');
      if (raw == null) return;
      final restored = AppState.fromJson(
        jsonDecode(raw) as Map<String, dynamic>,
      );
      if (!await preferences.setString(
        _recoveryKey,
        jsonEncode(_state.toJson()),
      )) {
        throw StateError(
          'Current state could not be retained as a recovery copy',
        );
      }
      _ensureOwner();
      if (ownRecovery == null && accountId != null) {
        await preferences.setString('legacy_state_recovery_owner', accountId!);
      }
      await _saveState(restored);
    });
    return _state;
  }

  /// Local copies are removed only after account deletion has fully succeeded.
  Future<void> clearLocalData() async {
    _ensureOwner();
    // Retire before awaiting anything so a delayed remote acknowledgement can
    // never repopulate the deleted envelope or a subsequently reopened account.
    _storage.owner = null;
    await _storage.enqueue(() async {
      await preferences.remove(storageKey);
      await preferences.remove(_recoveryKey);
      _state = AppState.empty();
      _base = null;
      _pending = false;
      hasCache = false;
    });
  }

  @override
  Future<void> deleteUserData() async {
    await _writes;
    _ensureOwner();
    if (remote != null) await remote!.deleteUserData();
    // Keep local state as a recovery copy until authentication deletion succeeds.
  }
}
