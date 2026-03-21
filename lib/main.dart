import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/firebase_options.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/live_activity/workout_live_activity_service.dart';
import 'package:strength_training_tracker/src/features/watch/watch_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppStateRepository repository;
  AppState initialState;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Set auth persistence explicitly for Safari compatibility
    if (kIsWeb) {
      await FirebaseAuth.instance.setPersistence(Persistence.LOCAL);
    }

    // Sign in (anonymously if no existing session)
    User user;
    if (FirebaseAuth.instance.currentUser != null) {
      user = FirebaseAuth.instance.currentUser!;
    } else {
      final credential = await FirebaseAuth.instance.signInAnonymously();
      user = credential.user!;
    }

    repository = FirestoreAppStateRepository(userId: user.uid);

    // Migrate from SharedPreferences if data exists
    final preferences = await SharedPreferences.getInstance();
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
    initialState = _migrateMuscleNames(initialState);
    if (initialState.exercises != originalState.exercises) {
      await repository.save(initialState);
    }
  } catch (e) {
    // Fallback to SharedPreferences if Firebase fails
    debugPrint('Firebase init failed, falling back to local storage: $e');
    final preferences = await SharedPreferences.getInstance();
    repository = SharedPreferencesAppStateRepository(preferences);
    initialState = await repository.load();

    // Migrate old compound muscle names to specific 1:1 names
    final originalState = initialState;
    initialState = _migrateMuscleNames(initialState);
    if (initialState.exercises != originalState.exercises) {
      await repository.save(initialState);
    }
  }

  final container = ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(repository),
      initialAppStateProvider.overrideWithValue(initialState),
    ],
  );

  // Initialize Watch sync on iOS only
  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      container.read(workoutLiveActivityServiceProvider).initialize();
    } catch (e) {
      debugPrint('Live Activity initialization failed: $e');
    }

    try {
      container.read(watchSyncServiceProvider).initialize();
    } catch (e) {
      debugPrint('Watch sync initialization failed: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StrengthTrainingApp(),
    ),
  );
}

AppState _migrateMuscleNames(AppState state) {
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
    final newPrimary = _expandMuscles(exercise.primaryMuscles, migration);
    final newSecondary = _expandMuscles(exercise.secondaryMuscles, migration);
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
List<String>? _expandMuscles(
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
