import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/firebase_options.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.repository,
    required this.trainingEngineStateRepository,
    required this.initialState,
    required this.auth,
  });
  final AppStateRepository repository;
  final TrainingEngineStateRepository trainingEngineStateRepository;
  final AppState initialState;
  final FirebaseAuth auth;
}

Future<AppBootstrapResult> initializeApp({
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
}) async {
  AppStateRepository repository;
  late TrainingEngineStateRepository trainingEngineStateRepository;
  AppState initialState;
  final injectedAuth = auth;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    final firebaseAuth = injectedAuth ?? FirebaseAuth.instance;

    // Set auth persistence explicitly for Safari compatibility
    // Only when using default auth (not injected for tests)
    if (kIsWeb && injectedAuth == null) {
      await firebaseAuth.setPersistence(Persistence.LOCAL);
    }

    // Sign in anonymously if no existing session
    if (firebaseAuth.currentUser == null) {
      await firebaseAuth.signInAnonymously();
    }

    final firestoreInstance = firestore ?? FirebaseFirestore.instance;
    repository = FirestoreAppStateRepository(
      auth: firebaseAuth,
      firestore: firestoreInstance,
    );

    // Migrate from SharedPreferences if data exists
    final preferences = await SharedPreferences.getInstance();
    trainingEngineStateRepository =
        SharedPreferencesTrainingEngineStateRepository(preferences);
    const migrationKey = 'strength_training_tracker_state_v1';
    final localData = preferences.getString(migrationKey);
    if (localData != null && localData.isNotEmpty) {
      final localRepo = SharedPreferencesAppStateRepository(preferences);
      final localState = await localRepo.load();
      // Only migrate if Firestore is empty (don't overwrite cloud data)
      final cloudState = await repository.load();
      if (cloudState.exercises.isEmpty && cloudState.routines.isEmpty) {
        await repository.save(localState);
      }
      await preferences.remove(migrationKey);
    }

    initialState = await repository.load();

    // Migrate old compound muscle names to specific 1:1 names
    final originalState = initialState;
    initialState = migrateMuscleNames(initialState);
    if (initialState.exercises != originalState.exercises) {
      await repository.save(initialState);
    }

    return AppBootstrapResult(
      repository: repository,
      trainingEngineStateRepository: trainingEngineStateRepository,
      initialState: initialState,
      auth: firebaseAuth,
    );
  } catch (e) {
    // Fallback to SharedPreferences if Firebase fails
    debugPrint('Firebase init failed, falling back to local storage: $e');
    final preferences = await SharedPreferences.getInstance();
    trainingEngineStateRepository =
        SharedPreferencesTrainingEngineStateRepository(preferences);
    repository = SharedPreferencesAppStateRepository(preferences);
    initialState = await repository.load();

    // Migrate old compound muscle names to specific 1:1 names
    final originalState = initialState;
    initialState = migrateMuscleNames(initialState);
    if (initialState.exercises != originalState.exercises) {
      await repository.save(initialState);
    }

    return AppBootstrapResult(
      repository: repository,
      trainingEngineStateRepository: trainingEngineStateRepository,
      initialState: initialState,
      auth: injectedAuth ?? FirebaseAuth.instance,
    );
  }
}

ProviderContainer buildContainer(AppBootstrapResult result) {
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(result.repository),
      initialAppStateProvider.overrideWithValue(result.initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(
        result.trainingEngineStateRepository,
      ),
      authServiceProvider.overrideWithValue(AuthService(result.auth)),
    ],
  );
}

AppState migrateMuscleNames(AppState state) {
  const migration = <String, List<String>>{
    'Back': ['Upper Back', 'Trapezius'],
    'Legs': ['Quadriceps', 'Hamstrings', 'Glutes'],
    'Arms': ['Biceps', 'Triceps'],
    'Shoulders': ['Deltoids'],
    'Quads': ['Quadriceps'],
    'Core': ['Abs', 'Obliques'],
    'Lats': ['Trapezius'],
  };

  bool changed = false;
  final updatedExercises = state.exercises.map((exercise) {
    final newPrimary = expandMuscles(exercise.primaryMuscles, migration);
    final newSecondary = expandMuscles(exercise.secondaryMuscles, migration);
    if (newPrimary != null || newSecondary != null) {
      changed = true;
      return exercise.copyWith(
        primaryMuscles: newPrimary ?? exercise.primaryMuscles,
        secondaryMuscles: newSecondary ?? exercise.secondaryMuscles,
      );
    }
    return exercise;
  }).toList();

  if (changed) {
    return state.copyWith(exercises: updatedExercises);
  }
  return state;
}

/// Returns expanded muscle list if any compound names found, null if no changes.
List<String>? expandMuscles(
  List<String> muscles,
  Map<String, List<String>> migration,
) {
  final hasCompound = muscles.any((m) => migration.containsKey(m));
  if (!hasCompound) return null;

  final expanded = <String>{};
  for (final muscle in muscles) {
    if (migration.containsKey(muscle)) {
      expanded.addAll(migration[muscle]!);
    } else {
      expanded.add(muscle);
    }
  }
  return expanded.toList();
}
