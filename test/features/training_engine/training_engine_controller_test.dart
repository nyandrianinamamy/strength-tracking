import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

ProviderContainer _buildContainer({
  AppState initialState = const AppState(
    exercises: [],
    routines: [],
    sessions: [],
  ),
  TrainingEngineStateRepository? engineRepository,
}) {
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(
        MemoryAppStateRepository(initialState: initialState),
      ),
      initialAppStateProvider.overrideWithValue(initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(
        engineRepository ?? MemoryTrainingEngineStateRepository(),
      ),
    ],
  );
}

AppState _appStateWithControllerSession() {
  final completedAt = DateTime.utc(2026, 4, 2, 18, 0);
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
        id: 'controller-session',
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
            weightKg: 100,
            reps: 8,
            completedAt: DateTime.utc(2026, 4, 2, 17, 15),
            note: '',
            rpe: 8,
          ),
        ],
        sessionNote: '',
        rpe: 8,
      ),
    ],
  );
}

void main() {
  group('TrainingEngineController', () {
    test(
      'ingestSession persists engine state and refreshes provider reads',
      () async {
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: _appStateWithControllerSession(),
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final initialEngine = await container.read(
          trainingEngineProvider.future,
        );
        expect(initialEngine.state.sessionsIngested, 1);

        await container
            .read(trainingEngineControllerProvider)
            .ingestSession(
              EngineSession(
                id: 'controller-session',
                startedAt: DateTime.utc(2026, 4, 2, 17, 0),
                endedAt: DateTime.utc(2026, 4, 2, 18, 0),
                sets: [
                  LoggedSet(
                    exerciseId: 'barbell_back_squat',
                    weightKg: 100,
                    reps: 8,
                    rpe: 8.0,
                    completedAt: DateTime.utc(2026, 4, 2, 17, 15),
                  ),
                ],
              ),
            );

        expect(engineRepository.state?['sessionsIngested'], 1);

        final refreshedEngine = await container.read(
          trainingEngineProvider.future,
        );
        expect(refreshedEngine.state.sessionsIngested, 1);
        expect(
          refreshedEngine.state.e1rmHistory['barbell_back_squat'],
          isNotEmpty,
        );
      },
    );

    test('ingestSession is idempotent for duplicate session ids', () async {
      final engineRepository = MemoryTrainingEngineStateRepository();
      final container = _buildContainer(
        initialState: _appStateWithControllerSession(),
        engineRepository: engineRepository,
      );
      addTearDown(container.dispose);

      final session = EngineSession(
        id: 'controller-session',
        startedAt: DateTime.utc(2026, 4, 2, 17, 0),
        endedAt: DateTime.utc(2026, 4, 2, 18, 0),
        sets: [
          LoggedSet(
            exerciseId: 'barbell_back_squat',
            weightKg: 100,
            reps: 8,
            rpe: 8.0,
            completedAt: DateTime.utc(2026, 4, 2, 17, 15),
          ),
        ],
      );

      await container
          .read(trainingEngineControllerProvider)
          .ingestSession(session);
      await container
          .read(trainingEngineControllerProvider)
          .ingestSession(session);

      final refreshedEngine = await container.read(
        trainingEngineProvider.future,
      );
      expect(refreshedEngine.state.sessionsIngested, 1);
      expect(refreshedEngine.state.ingestedSessionIds, {'controller-session'});
      expect(
        refreshedEngine.state.e1rmHistory['barbell_back_squat'],
        hasLength(1),
      );
    });

    test('ingestSleep persists readiness inputs', () async {
      final engineRepository = MemoryTrainingEngineStateRepository();
      final container = _buildContainer(engineRepository: engineRepository);
      addTearDown(container.dispose);

      await container.read(trainingEngineProvider.future);

      await container
          .read(trainingEngineControllerProvider)
          .ingestSleep(
            SleepRecord(
              date: DateTime.utc(2026, 4, 2),
              totalSleep: const Duration(hours: 8),
              deepSleep: const Duration(hours: 1, minutes: 20),
              remSleep: const Duration(hours: 1, minutes: 40),
              coreSleep: const Duration(hours: 5),
            ),
          );

      final refreshedEngine = await container.read(
        trainingEngineProvider.future,
      );
      expect(refreshedEngine.state.sleepHistory, hasLength(1));
      expect(engineRepository.state?['sleepHistory'], isNotEmpty);
    });
  });
}
