import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

abstract class TrainingEngineStateRepository {
  Future<Map<String, dynamic>?> load();
  Future<void> save(Map<String, dynamic> state);
  Future<void> clear();
}

class SharedPreferencesTrainingEngineStateRepository
    implements TrainingEngineStateRepository {
  SharedPreferencesTrainingEngineStateRepository(
    this._preferences, {
    String? accountId,
  }) : _storageKey =
           'training_engine_state_v2_${(accountId == null ? "guest" : "user_${Uri.encodeComponent(accountId)}")}';

  final String _storageKey;

  final SharedPreferences _preferences;

  @override
  Future<Map<String, dynamic>?> load() async {
    final raw = _preferences.getString(_storageKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    return jsonDecode(raw) as Map<String, dynamic>;
  }

  @override
  Future<void> save(Map<String, dynamic> state) async {
    await _preferences.setString(_storageKey, jsonEncode(state));
  }

  @override
  Future<void> clear() async {
    await _preferences.remove(_storageKey);
  }
}

class MemoryTrainingEngineStateRepository
    implements TrainingEngineStateRepository {
  MemoryTrainingEngineStateRepository({Map<String, dynamic>? initialState})
    : _state = _clone(initialState);

  Map<String, dynamic>? _state;

  Map<String, dynamic>? get state => _clone(_state);

  @override
  Future<Map<String, dynamic>?> load() async => _clone(_state);

  @override
  Future<void> save(Map<String, dynamic> state) async {
    _state = _clone(state);
  }

  @override
  Future<void> clear() async {
    _state = null;
  }

  static Map<String, dynamic>? _clone(Map<String, dynamic>? state) {
    if (state == null) {
      return null;
    }
    return jsonDecode(jsonEncode(state)) as Map<String, dynamic>;
  }
}
