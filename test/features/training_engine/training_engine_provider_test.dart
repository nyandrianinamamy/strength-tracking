import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

AppState _appStateWithCompletedSession() {
  final completedAt = DateTime.utc(2026, 3, 1, 18, 0);
  return AppState(
    exercises: const [
      Exercise(
        id: 'barbell_back_squat',
        name: 'Barbell Back Squat',
        primaryMuscles: ['Quadriceps'],
        secondaryMuscles: ['Glutes'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      ),
    ],
    routines: const [],
    sessions: [
      WorkoutSession(
        id: 'completed-session-1',
        routineId: 'routine-1',
        status: WorkoutSessionStatus.completed,
        startedAt: completedAt.subtract(const Duration(hours: 1)),
        endedAt: completedAt,
        lastActivityAt: completedAt,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 1,
            weightKg: 110.0,
            reps: 8,
            completedAt: completedAt,
            note: '',
            rpe: 8.0,
          ),
        ],
        sessionNote: '',
        rpe: 8.0,
      ),
    ],
    bodyGender: 'male',
  );
}

ProviderContainer _buildContainer({
  required AppState initialState,
  required AppStateRepository appRepository,
  required TrainingEngineStateRepository engineRepository,
}) {
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(appRepository),
      initialAppStateProvider.overrideWithValue(initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(engineRepository),
    ],
  );
}

void main() {
  group('trainingEngineProvider', () {
    test('bootstraps from completed app sessions when no saved engine state exists', () async {
      final appState = _appStateWithCompletedSession();
      final appRepository = MemoryAppStateRepository(initialState: appState);
      final engineRepository = MemoryTrainingEngineStateRepository();
      final container = _buildContainer(
        initialState: appState,
        appRepository: appRepository,
        engineRepository: engineRepository,
      );
      addTearDown(container.dispose);

      final engine = await container.read(trainingEngineProvider.future);

      expect(engine.state.sessionsIngested, 1);
      expect(engine.state.e1rmHistory['barbell_back_squat'], isNotEmpty);
      expect(engineRepository.state, isNotNull);
    });

    test('restores saved engine state without bootstrapping app sessions again', () async {
      final appState = _appStateWithCompletedSession();
      final appRepository = MemoryAppStateRepository(initialState: appState);

      final savedEngine = TrainingEngine(
        registry: ExerciseRegistry.withDefaults(),
        profile: UserProfile(
          sex: Sex.male,
          age: 30,
          bodyWeightKg: 82,
          experience: ExperienceLevel.intermediate,
          goal: HypertrophyGoal.hypertrophy,
          availableDays: const [1, 3, 5],
          maxSessionDuration: const Duration(minutes: 60),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      savedEngine.ingestSession(
        EngineSession(
          id: 'saved-session',
          startedAt: DateTime.utc(2026, 2, 1, 17, 0),
          endedAt: DateTime.utc(2026, 2, 1, 18, 0),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_bench_press',
              weightKg: 80,
              reps: 8,
              rpe: 8.0,
              completedAt: DateTime.utc(2026, 2, 1, 17, 10),
            ),
          ],
        ),
      );

      final engineRepository = MemoryTrainingEngineStateRepository(
        initialState: savedEngine.serializeState(),
      );
      final container = _buildContainer(
        initialState: appState,
        appRepository: appRepository,
        engineRepository: engineRepository,
      );
      addTearDown(container.dispose);

      final engine = await container.read(trainingEngineProvider.future);

      expect(engine.state.sessionsIngested, 1);
      expect(engine.state.e1rmHistory['barbell_bench_press'], isNotEmpty);
      expect(engine.state.e1rmHistory['barbell_back_squat'], isNull);
    });
  });

  group('SharedPreferencesTrainingEngineStateRepository', () {
    test('persists and reloads serialized engine state', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesTrainingEngineStateRepository(
        preferences,
      );

      final engine = TrainingEngine(
        registry: ExerciseRegistry.withDefaults(),
        profile: UserProfile(
          sex: Sex.male,
          age: 28,
          bodyWeightKg: 80,
          experience: ExperienceLevel.intermediate,
          goal: HypertrophyGoal.hypertrophy,
          availableDays: const [1, 3, 5],
          maxSessionDuration: const Duration(minutes: 60),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      engine.ingestSession(
        EngineSession(
          id: 'persisted-session',
          startedAt: DateTime.utc(2026, 3, 1, 17, 0),
          endedAt: DateTime.utc(2026, 3, 1, 18, 0),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_back_squat',
              weightKg: 100,
              reps: 8,
              rpe: 8.0,
              completedAt: DateTime.utc(2026, 3, 1, 17, 15),
            ),
          ],
        ),
      );

      await repository.save(engine.serializeState());
      final restored = await repository.load();

      expect(restored, isNotNull);
      expect(restored!['sessionsIngested'], 1);
      expect(restored['e1rmHistory'], isNotEmpty);
    });
  });
}
