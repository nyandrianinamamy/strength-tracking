import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:training_engine/training_engine.dart';

class _SaveFailsOnceTrainingEngineStateRepository
    implements TrainingEngineStateRepository {
  _SaveFailsOnceTrainingEngineStateRepository({
    required Map<String, dynamic> initialState,
  }) : _delegate = MemoryTrainingEngineStateRepository(
         initialState: initialState,
       );

  final MemoryTrainingEngineStateRepository _delegate;
  int saveAttempts = 0;

  Map<String, dynamic>? get state => _delegate.state;

  @override
  Future<void> clear() => _delegate.clear();

  @override
  Future<Map<String, dynamic>?> load() => _delegate.load();

  @override
  Future<void> save(Map<String, dynamic> state) async {
    saveAttempts += 1;
    if (saveAttempts == 1) {
      throw StateError('simulated training engine save failure');
    }
    await _delegate.save(state);
  }
}

Map<String, dynamic> _emptySavedEngineState() {
  final engine = TrainingEngine(
    registry: ExerciseRegistry.withDefaults(),
    profile: UserProfile(
      sex: Sex.male,
      age: 25,
      bodyWeightKg: 75,
      experience: ExperienceLevel.intermediate,
      goal: HypertrophyGoal.hypertrophy,
      availableDays: const [1, 3, 5],
      maxSessionDuration: const Duration(minutes: 60),
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );
  return engine.serializeState();
}

void main() {
  ProviderContainer buildContainer({
    AppState? initialState,
    TrainingEngineStateRepository? trainingEngineRepository,
  }) {
    final repository = MemoryAppStateRepository(
      initialState: initialState ?? DemoSeedData.initialState(),
    );

    return ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
        trainingEngineStateRepositoryProvider.overrideWithValue(
          trainingEngineRepository ?? MemoryTrainingEngineStateRepository(),
        ),
      ],
    );
  }

  test(
    'starting, logging, and completing a workout updates app state',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      final routines = container.read(appStateControllerProvider).routines;
      final routine = routines.firstWhere((item) => item.id == 'push_day');

      final started = container
          .read(routineControllerProvider)
          .startSession(routine.id);
      expect(started.routineId, routine.id);
      expect(
        container.read(appStateControllerProvider).activeSession?.id,
        started.id,
      );

      final updated = container
          .read(workoutControllerProvider)
          .logSet(weightKg: 100, reps: 6);
      expect(updated, isNotNull);
      expect(updated!.completedSets, hasLength(1));

      final completed = container
          .read(workoutControllerProvider)
          .completeSession(rpe: 8.5);
      await Future<void>.delayed(Duration.zero);
      expect(completed, isNotNull);
      expect(completed!.status.name, 'completed');
      expect(container.read(appStateControllerProvider).activeSession, isNull);
      expect(
        container
            .read(appStateControllerProvider)
            .completedSessions
            .any((session) => session.id == completed.id),
        isTrue,
      );
    },
  );

  test('archiving a routine preserves completed workout history', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final initialCompletedCount = container
        .read(appStateControllerProvider)
        .completedSessions
        .length;

    container.read(routineControllerProvider).archive('push_day');

    final state = container.read(appStateControllerProvider);
    expect(state.routineById('push_day')?.archived, isTrue);
    expect(state.completedSessions.length, initialCompletedCount);
    expect(
      state.completedSessions.any((session) => session.routineId == 'push_day'),
      isTrue,
    );
  });

  test('archiving a routine removes it from all routine groups', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    final groupBefore = container
        .read(appStateControllerProvider)
        .routineGroupById('ppl_split');
    expect(groupBefore!.routineIds, contains('push_day'));

    container.read(routineControllerProvider).archive('push_day');

    final groupAfter = container
        .read(appStateControllerProvider)
        .routineGroupById('ppl_split');
    expect(groupAfter!.routineIds, isNot(contains('push_day')));
  });

  test(
    'skipping a grouped routine advances the queue until it is completed',
    () async {
      final container = buildContainer();
      addTearDown(container.dispose);

      container
          .read(routineGroupControllerProvider)
          .skipNextInGroup('ppl_split');

      var group = container
          .read(appStateControllerProvider)
          .routineGroupById('ppl_split');
      expect(group, isNotNull);
      expect(group!.pendingRoutineIds, ['pull_day', 'leg_day', 'push_day']);

      container.read(routineControllerProvider).startSession('pull_day');
      container.read(workoutControllerProvider).completeSession(rpe: 8.0);
      await Future<void>.delayed(Duration.zero);

      group = container
          .read(appStateControllerProvider)
          .routineGroupById('ppl_split');
      expect(group, isNotNull);
      expect(group!.pendingRoutineIds, ['leg_day', 'push_day']);
    },
  );

  test('completing a workout persists training engine state', () async {
    final trainingEngineRepository = MemoryTrainingEngineStateRepository();
    final container = buildContainer(
      trainingEngineRepository: trainingEngineRepository,
    );
    addTearDown(container.dispose);

    final previousCompletedCount = container
        .read(appStateControllerProvider)
        .completedSessions
        .length;
    final routine = container
        .read(appStateControllerProvider)
        .routines
        .firstWhere((item) => item.id == 'push_day');

    container.read(routineControllerProvider).startSession(routine.id);
    container.read(workoutControllerProvider).logSet(weightKg: 100, reps: 8);
    final completed = container
        .read(workoutControllerProvider)
        .completeSession(rpe: 8.0);

    expect(completed, isNotNull);

    for (var i = 0; i < 10 && trainingEngineRepository.state == null; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    expect(trainingEngineRepository.state, isNotNull);
    expect(
      trainingEngineRepository.state?['sessionsIngested'],
      equals(previousCompletedCount + 1),
    );
  });

  test(
    'provider load repairs a completed workout after fire-and-forget engine save fails',
    () async {
      final trainingEngineRepository =
          _SaveFailsOnceTrainingEngineStateRepository(
            initialState: _emptySavedEngineState(),
          );
      final initialState = DemoSeedData.initialState().copyWith(sessions: []);
      final container = buildContainer(
        initialState: initialState,
        trainingEngineRepository: trainingEngineRepository,
      );
      addTearDown(container.dispose);

      final previousCompletedCount = container
          .read(appStateControllerProvider)
          .completedSessions
          .length;
      final routine = container
          .read(appStateControllerProvider)
          .routines
          .firstWhere((item) => item.id == 'push_day');

      container.read(routineControllerProvider).startSession(routine.id);
      container.read(workoutControllerProvider).logSet(weightKg: 100, reps: 8);
      final completed = container
          .read(workoutControllerProvider)
          .completeSession(rpe: 8.0);

      expect(completed, isNotNull);

      for (
        var i = 0;
        i < 10 && trainingEngineRepository.saveAttempts == 0;
        i++
      ) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(trainingEngineRepository.saveAttempts, 1);
      expect(trainingEngineRepository.state?['sessionsIngested'], 0);

      final repairedEngine = await container.read(
        trainingEngineProvider.future,
      );

      expect(repairedEngine.state.sessionsIngested, previousCompletedCount + 1);
      expect(repairedEngine.state.ingestedSessionIds, contains(completed!.id));
      expect(
        trainingEngineRepository.state?['sessionsIngested'],
        previousCompletedCount + 1,
      );
    },
  );

  test('logging a set stores per-set RPE in the active session', () {
    final container = buildContainer();
    addTearDown(container.dispose);

    container.read(routineControllerProvider).startSession('push_day');

    final updated = container
        .read(workoutControllerProvider)
        .logSet(weightKg: 100, reps: 6, rpe: 8.5);

    expect(updated, isNotNull);
    expect(updated!.completedSets.single.rpe, equals(8.5));
    expect(
      container
          .read(appStateControllerProvider)
          .activeSession
          ?.completedSets
          .single
          .rpe,
      equals(8.5),
    );
  });
}
