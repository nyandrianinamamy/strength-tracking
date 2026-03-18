import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/firebase_options.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  AppStateRepository repository;
  AppState initialState;

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

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

    // If Firestore returned empty, seed with demo data
    if (initialState.exercises.isEmpty && initialState.routines.isEmpty) {
      initialState = DemoSeedData.initialState();
      await repository.save(initialState);
    }
  } catch (e) {
    // Fallback to SharedPreferences if Firebase fails
    debugPrint('Firebase init failed, falling back to local storage: $e');
    final preferences = await SharedPreferences.getInstance();
    repository = SharedPreferencesAppStateRepository(preferences);
    initialState = await repository.load();
  }

  runApp(
    ProviderScope(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(initialState),
      ],
      child: const StrengthTrainingApp(),
    ),
  );
}
