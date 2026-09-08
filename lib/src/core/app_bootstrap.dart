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
import 'package:strength_training_tracker/src/features/auth/invite_access.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';

class AppBootstrapResult {
  const AppBootstrapResult({
    required this.repository,
    required this.trainingEngineStateRepository,
    required this.initialState,
    required this.auth,
    this.accountFactory,
    this.accessAvailable = false,
  });
  final AppStateRepository repository;
  final TrainingEngineStateRepository trainingEngineStateRepository;
  final AppState initialState;
  final FirebaseAuth? auth;
  final AccountRepositoryFactory? accountFactory;
  final bool accessAvailable;
}

Future<AppBootstrapResult> initializeApp({
  FirebaseFirestore? firestore,
  FirebaseAuth? auth,
  FirebaseOptions? firebaseOptions,
  Future<void> Function()? firebaseInitializer,
  SharedPreferences? preferences,
}) async {
  final local = preferences ?? await SharedPreferences.getInstance();
  FirebaseAuth? availableAuth = auth;
  FirebaseFirestore? availableFirestore = firestore;
  try {
    if (firebaseInitializer != null) {
      await firebaseInitializer();
    } else {
      await Firebase.initializeApp(
        options: firebaseOptions ?? DefaultFirebaseOptions.currentPlatform,
      );
    }
    availableAuth ??= FirebaseAuth.instance;
    availableFirestore ??= FirebaseFirestore.instance;
  } catch (_) {
    // Do not touch Firebase singletons again after an initialization failure.
    // Existing local account data is retained; unknown legacy ownership is
    // never assigned to whichever account happens to sign in next.
  }
  final factory = AccountRepositoryFactory(
    preferences: local,
    auth: availableAuth,
    firestore: availableFirestore,
  );
  AccountContext context;
  try {
    context = await factory.open(availableAuth?.currentUser);
  } on InviteAccessDeniedException {
    await availableAuth?.signOut();
    context = await factory.open(null);
  }
  final migrated = migrateMuscleNames(context.state);
  if (migrated.exercises != context.state.exercises) {
    await context.repository.save(migrated);
  }
  return AppBootstrapResult(
    repository: context.repository,
    trainingEngineStateRepository: context.engineRepository,
    initialState: migrated,
    auth: availableAuth,
    accountFactory: factory,
    accessAvailable: context.accessAvailable,
  );
}

@visibleForTesting
AppStateRepository buildUnauthenticatedRepositoryForTest() =>
    MemoryAppStateRepository(initialState: AppState.empty());

ProviderContainer buildContainer(AppBootstrapResult result) {
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(result.repository),
      initialAppStateProvider.overrideWithValue(result.initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(
        result.trainingEngineStateRepository,
      ),
      authServiceProvider.overrideWithValue(AuthService(result.auth)),
      accountRepositoryFactoryProvider.overrideWithValue(result.accountFactory),
      appRepositoryDidSyncProvider.overrideWith(
        (ref) => (repository) {
          if (repository is AccountAppStateRepository) {
            ref.read(accountAccessAvailableProvider.notifier).state =
                result.accountFactory?.hasVerifiedAccess(repository) ?? false;
          }
        },
      ),
      accountAccessAvailableProvider.overrideWith(
        (ref) => result.accessAvailable,
      ),
      boundAccountIdProvider.overrideWith(
        (ref) => result.repository is AccountAppStateRepository
            ? (result.repository as AccountAppStateRepository).accountId
            : null,
      ),
      appSaveStatusProvider.overrideWith(
        (ref) => result.repository is AccountAppStateRepository
            ? switch ((result.repository as AccountAppStateRepository)
                  .syncStatus) {
                RepositorySyncStatus.local => AppSaveStatus.local,
                RepositorySyncStatus.synced => AppSaveStatus.saved,
                RepositorySyncStatus.pending => AppSaveStatus.pending,
                RepositorySyncStatus.failed =>
                  (result.repository as AccountAppStateRepository).lastError
                          is StatePayloadTooLarge
                      ? AppSaveStatus.capacityExceeded
                      : AppSaveStatus.syncFailed,
                RepositorySyncStatus.conflict => AppSaveStatus.conflict,
              }
            : AppSaveStatus.saved,
      ),
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
