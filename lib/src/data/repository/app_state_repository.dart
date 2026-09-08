import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'account_app_state_repository.dart';

abstract class AppStateRepository {
  Future<AppState> load();
  Future<void> save(AppState state);
  Future<void> deleteUserData();
}

class SharedPreferencesAppStateRepository implements AppStateRepository {
  SharedPreferencesAppStateRepository(this._preferences);

  static const _storageKey = 'strength_training_tracker_state_v1';
  final SharedPreferences _preferences;

  @override
  Future<AppState> load() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return AppState.empty();
    }

    return AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(AppState state) async {
    if (!await _preferences.setString(
      _storageKey,
      jsonEncode(state.toJson()),
    )) {
      throw StateError('Local state could not be saved');
    }
  }

  @override
  Future<void> deleteUserData() async {
    await _preferences.remove(_storageKey);
  }
}

class MemoryAppStateRepository implements AppStateRepository {
  MemoryAppStateRepository({AppState? initialState})
    : _state = initialState ?? DemoSeedData.initialState();

  AppState _state;

  @override
  Future<AppState> load() async => _state;

  @override
  Future<void> save(AppState state) async {
    _state = state;
  }

  @override
  Future<void> deleteUserData() async {
    _state = AppState.empty();
  }

  AppState get state => _state;
}

class StatePayloadTooLarge implements Exception {
  const StatePayloadTooLarge(this.bytes);
  final int bytes;
  @override
  String toString() =>
      'Account data exceeds the cloud document capacity ($bytes bytes)';
}

class FirestoreAppStateRepository
    implements AppStateRepository, MergingAppStateRepository {
  FirestoreAppStateRepository({
    required this.auth,
    FirebaseFirestore? firestore,
    String? userId,
    this.verifyAccess,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       userId =
           userId ??
           auth.currentUser?.uid ??
           (throw StateError('No authenticated user'));

  final FirebaseAuth auth;
  final FirebaseFirestore _firestore;
  final String userId;
  final Future<void> Function()? verifyAccess;
  final Set<Future<Object?>> _operations = {};

  Future<T> _track<T>(Future<T> operation) {
    _operations.add(operation);
    operation.then(
      (_) => _operations.remove(operation),
      onError: (Object _, StackTrace _) => _operations.remove(operation),
    );
    return operation.timeout(const Duration(seconds: 8));
  }

  Future<void> waitForIdle() async {
    await Future.wait(
      _operations.map(
        (operation) =>
            operation.then<void>((_) {}, onError: (Object _, StackTrace _) {}),
      ),
    ).timeout(const Duration(seconds: 8));
  }

  void _checkOwner() {
    if (auth.currentUser?.uid != userId) {
      throw StateError('Account ownership changed');
    }
  }

  DocumentReference<Map<String, dynamic>> get _doc {
    _checkOwner();
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('data')
        .doc('state');
  }

  @override
  Future<AppState> load() async {
    _checkOwner();
    await verifyAccess?.call();
    final snapshot = await _track(
      _doc.get(const GetOptions(source: Source.server)),
    );
    if (!snapshot.exists || snapshot.data() == null) {
      return AppState.empty();
    }
    return AppState.fromJson(snapshot.data()!);
  }

  @override
  Future<void> save(AppState state) async {
    _checkOwner();
    await verifyAccess?.call();
    validatePayload(state);
    await _track(_doc.set(state.toJson()));
  }

  static void validatePayload(AppState state) {
    final bytes = utf8.encode(jsonEncode(state.toJson())).length;
    // Keep room for field metadata below Firestore's 1 MiB document cap.
    if (bytes > 900 * 1024) throw StatePayloadTooLarge(bytes);
  }

  @override
  Future<AppState> mergeAndSave(AppState base, AppState local) async {
    _checkOwner();
    await verifyAccess?.call();
    final doc = _doc;
    return _track(
      _firestore.runTransaction<AppState>((transaction) async {
        _checkOwner();
        final current = await transaction.get(doc);
        final cloud = current.exists
            ? AppState.fromJson(current.data()!)
            : AppState.empty();
        final merged = mergeAppStates(base, local, cloud);
        validatePayload(merged);
        _checkOwner();
        transaction.set(doc, merged.toJson());
        return merged;
      }),
    );
  }

  @override
  Future<void> deleteUserData() async {
    await verifyAccess?.call();
    await _doc.delete();
  }
}
