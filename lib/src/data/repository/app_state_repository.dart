import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';

abstract class AppStateRepository {
  Future<AppState> load();
  Future<void> save(AppState state);
}

class SharedPreferencesAppStateRepository implements AppStateRepository {
  SharedPreferencesAppStateRepository(this._preferences);

  static const _storageKey = 'strength_training_tracker_state_v1';
  final SharedPreferences _preferences;

  @override
  Future<AppState> load() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return DemoSeedData.initialState();
    }

    return AppState.fromJson(jsonDecode(raw) as Map<String, dynamic>);
  }

  @override
  Future<void> save(AppState state) async {
    await _preferences.setString(_storageKey, jsonEncode(state.toJson()));
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

  AppState get state => _state;
}

class FirestoreAppStateRepository implements AppStateRepository {
  FirestoreAppStateRepository({
    required this.userId,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String userId;
  final FirebaseFirestore _firestore;

  DocumentReference<Map<String, dynamic>> get _doc =>
      _firestore.collection('users').doc(userId).collection('data').doc('state');

  @override
  Future<AppState> load() async {
    final snapshot = await _doc.get();
    if (!snapshot.exists || snapshot.data() == null) {
      return AppState.empty();
    }
    return AppState.fromJson(snapshot.data()!);
  }

  @override
  Future<void> save(AppState state) async {
    await _doc.set(state.toJson());
  }
}
