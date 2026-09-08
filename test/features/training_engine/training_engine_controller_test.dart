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
  test('refresh persists canonical session data and is idempotent', () async {
    final repository = MemoryTrainingEngineStateRepository();
    final container = _buildContainer(
      initialState: _appStateWithControllerSession(),
      engineRepository: repository,
    );
    addTearDown(container.dispose);
    final controller = container.read(trainingEngineControllerProvider);
    await controller.refreshFromAppHistory();
    await controller.refreshFromAppHistory();
    final refreshed = await container.read(trainingEngineProvider.future);
    expect(refreshed.state.ingestedSessionIds, {'controller-session'});
    expect(refreshed.state.e1rmHistory['barbell_back_squat'], hasLength(1));
    expect(repository.state?['sessionsIngested'], 1);
    expect(repository.state?['historyFingerprint'], isNotEmpty);
  });

  test(
    'refresh reconstructs an edited set without changing its session ID',
    () async {
      final repository = MemoryTrainingEngineStateRepository();
      final initial = _appStateWithControllerSession();
      final container = _buildContainer(
        initialState: initial,
        engineRepository: repository,
      );
      addTearDown(container.dispose);
      final controller = container.read(trainingEngineControllerProvider);
      final before = await controller.refreshFromAppHistory();
      final original = initial.sessions.single;
      container
          .read(appStateControllerProvider.notifier)
          .updateState(
            (state) => state.copyWith(
              sessions: [
                original.copyWith(
                  completedSets: [
                    original.completedSets.single.copyWith(weightKg: 120),
                  ],
                ),
              ],
            ),
          );
      final after = await controller.refreshFromAppHistory();
      expect(after.state.ingestedSessionIds, before.state.ingestedSessionIds);
      expect(after.state.lastTopSets['barbell_back_squat']!.weightKg, 120);
      expect(
        after.currentE1rm('barbell_back_squat'),
        greaterThan(before.currentE1rm('barbell_back_squat')!),
      );
      expect(after.state.e1rmHistory['barbell_back_squat'], hasLength(1));
    },
  );
}
