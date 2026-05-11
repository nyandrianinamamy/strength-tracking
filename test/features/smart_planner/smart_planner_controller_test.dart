// test/features/smart_planner/smart_planner_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:training_engine/training_engine.dart';

ProviderContainer _buildContainer() {
  return _buildContainerWithEngine(_engineWithFatigue(const {}));
}

ProviderContainer _buildContainerWithEngine(TrainingEngine engine) {
  final emptyState = AppState.empty();
  return ProviderContainer(
    overrides: [
      initialAppStateProvider.overrideWithValue(emptyState),
      appStateRepositoryProvider.overrideWithValue(
        MemoryAppStateRepository(initialState: emptyState),
      ),
      trainingEngineProvider.overrideWith((ref) async => engine),
    ],
  );
}

/// Minimal list of [Exercise] objects sufficient for plan generation.
/// Uses real muscle names so the registry adapter can resolve them.
List<Exercise> _sampleExercises() => const [];

TrainingEngine _engineWithFatigue(Map<String, double> fatigueByMuscle) {
  final engine = TrainingEngine(
    registry: ExerciseRegistry.withDefaults(),
    profile: UserProfile(
      sex: Sex.female,
      age: 30,
      bodyWeightKg: 70,
      experience: ExperienceLevel.intermediate,
      goal: HypertrophyGoal.hypertrophy,
      availableDays: const [1, 3, 5],
      maxSessionDuration: const Duration(minutes: 60),
      createdAt: DateTime(2026, 5, 11),
    ),
  );
  engine.restoreState(
    engine.state
        .copyWith(
          fatigueLog: {
            for (final entry in fatigueByMuscle.entries)
              entry.key: [
                FatigueImpulse(
                  muscleId: entry.key,
                  magnitude: entry.value,
                  timestamp: DateTime.now(),
                ),
              ],
          },
          sessionsIngested: 4,
        )
        .toJson(),
  );
  return engine;
}

void main() {
  group('SmartPlannerController', () {
    test('1. initial state has empty days and default config', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final state = container.read(smartPlannerControllerProvider);

      expect(state.selectedDays, isEmpty);
      expect(state.goal, HypertrophyGoal.hypertrophy);
      expect(state.maxDurationMinutes, 60);
      expect(state.preferredExercises, isEmpty);
      expect(state.excludedExercises, isEmpty);
      expect(state.generatedPlan, isNull);
      expect(state.wizardStep, 0);
      expect(state.editedExerciseKeys, isEmpty);
    });

    test('2. toggleDay adds and removes days', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(smartPlannerControllerProvider.notifier);

      ctrl.toggleDay(1);
      expect(container.read(smartPlannerControllerProvider).selectedDays, {1});

      ctrl.toggleDay(3);
      expect(
        container.read(smartPlannerControllerProvider).selectedDays,
        containsAll([1, 3]),
      );

      // Toggle 1 again → removes it
      ctrl.toggleDay(1);
      expect(container.read(smartPlannerControllerProvider).selectedDays, {3});
    });

    test('3. setGoal updates goal', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(smartPlannerControllerProvider.notifier);
      ctrl.setGoal(HypertrophyGoal.strength);

      expect(
        container.read(smartPlannerControllerProvider).goal,
        HypertrophyGoal.strength,
      );
    });

    test('4. setMaxDuration updates duration', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(smartPlannerControllerProvider.notifier);
      ctrl.setMaxDuration(45);

      expect(
        container.read(smartPlannerControllerProvider).maxDurationMinutes,
        45,
      );
    });

    test('5. detectedSplit returns upperLower for 4 days', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(smartPlannerControllerProvider.notifier);
      ctrl.toggleDay(1);
      ctrl.toggleDay(2);
      ctrl.toggleDay(4);
      ctrl.toggleDay(6);

      final split = container
          .read(smartPlannerControllerProvider)
          .detectedSplit;
      expect(split, SplitType.upperLower);
    });

    test(
      '6. generatePlan produces a WeeklyPlan with 3 sessions for 3 days',
      () async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        final ctrl = container.read(smartPlannerControllerProvider.notifier);
        // Select 3 non-consecutive days (fullBody split)
        ctrl.toggleDay(1);
        ctrl.toggleDay(3);
        ctrl.toggleDay(5);

        await ctrl.generatePlan(_sampleExercises());

        final state = container.read(smartPlannerControllerProvider);
        expect(state.generatedPlan, isNotNull);
        expect(state.generatedPlan!.sessions, hasLength(3));
      },
    );

    test('7. updateExerciseSets modifies a planned exercise', () async {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(smartPlannerControllerProvider.notifier);
      ctrl.toggleDay(1);
      ctrl.toggleDay(3);
      ctrl.toggleDay(5);
      await ctrl.generatePlan(_sampleExercises());

      final stateBefore = container.read(smartPlannerControllerProvider);
      expect(stateBefore.generatedPlan, isNotNull);
      expect(stateBefore.generatedPlan!.sessions, isNotEmpty);
      expect(stateBefore.generatedPlan!.sessions.first.exercises, isNotEmpty);

      final originalSets =
          stateBefore.generatedPlan!.sessions.first.exercises.first.targetSets;
      final newSets = originalSets + 1;

      ctrl.updateExercise(
        sessionIndex: 0,
        exerciseIndex: 0,
        targetSets: newSets,
      );

      final stateAfter = container.read(smartPlannerControllerProvider);
      expect(
        stateAfter.generatedPlan!.sessions.first.exercises.first.targetSets,
        newSets,
      );
      expect(stateAfter.editedExerciseKeys, contains('0:0'));
    });

    test(
      '8. generatePlan reduces high-fatigue engine muscles and tags context',
      () async {
        final container = _buildContainerWithEngine(
          _engineWithFatigue({'pectorals': 86}),
        );
        addTearDown(container.dispose);

        final ctrl = container.read(smartPlannerControllerProvider.notifier);
        ctrl.toggleDay(1);
        ctrl.toggleDay(2);
        ctrl.toggleDay(3);

        await ctrl.generatePlan(_sampleExercises());

        final plan = container
            .read(smartPlannerControllerProvider)
            .generatedPlan;
        expect(plan, isNotNull);
        expect(plan!.engineContextApplied, isTrue);
        final pushSession = plan.sessions.firstWhere(
          (session) => session.focus == SessionFocus.push,
        );
        final adaptedChest = pushSession.exercises
            .where((exercise) => exercise.fatiguedMuscles.contains('pectorals'))
            .toList();

        expect(adaptedChest, isNotEmpty);
        expect(
          adaptedChest.map((exercise) => exercise.targetSets),
          everyElement(2),
        );
        expect(
          adaptedChest.map((exercise) => exercise.engineSessionsIngested),
          everyElement(4),
        );
      },
    );

    test(
      '9. adopted routines keep Smart Planner engine context metadata',
      () async {
        final container = _buildContainerWithEngine(
          _engineWithFatigue({'pectorals': 86}),
        );
        addTearDown(container.dispose);

        final ctrl = container.read(smartPlannerControllerProvider.notifier);
        ctrl.toggleDay(1);
        ctrl.toggleDay(2);
        ctrl.toggleDay(3);
        await ctrl.generatePlan(_sampleExercises());

        ctrl.adopt(container.read(appStateControllerProvider.notifier));

        final routines = container.read(appStateControllerProvider).routines;
        final metadata = routines
            .expand((routine) => routine.exercises)
            .map((exercise) => exercise.plannerMetadata)
            .where((metadata) => metadata['engineContextApplied'] == true)
            .toList();

        expect(metadata, isNotEmpty);
        expect(
          metadata.any(
            (entry) =>
                (entry['fatiguedMuscles'] as List).contains('pectorals') &&
                (entry['adaptationReasons'] as List).any(
                  (reason) => '$reason'.contains('pectorals fatigue'),
                ),
          ),
          isTrue,
        );
      },
    );
  });
}
