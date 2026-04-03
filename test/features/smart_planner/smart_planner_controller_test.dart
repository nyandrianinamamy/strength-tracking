// test/features/smart_planner/smart_planner_controller_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_controller.dart';
import 'package:training_engine/training_engine.dart';

ProviderContainer _buildContainer() {
  return ProviderContainer();
}

/// Minimal list of [Exercise] objects sufficient for plan generation.
/// Uses real muscle names so the registry adapter can resolve them.
List<Exercise> _sampleExercises() => const [];

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
      expect(container.read(smartPlannerControllerProvider).selectedDays, [1]);

      ctrl.toggleDay(3);
      expect(
        container.read(smartPlannerControllerProvider).selectedDays,
        containsAll([1, 3]),
      );

      // Toggle 1 again → removes it
      ctrl.toggleDay(1);
      expect(
        container.read(smartPlannerControllerProvider).selectedDays,
        [3],
      );
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

      final split =
          container.read(smartPlannerControllerProvider).detectedSplit;
      expect(split, SplitType.upperLower);
    });

    test('6. generatePlan produces a WeeklyPlan with 3 sessions for 3 days',
        () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(smartPlannerControllerProvider.notifier);
      // Select 3 non-consecutive days (fullBody split)
      ctrl.toggleDay(1);
      ctrl.toggleDay(3);
      ctrl.toggleDay(5);

      ctrl.generatePlan(_sampleExercises());

      final state = container.read(smartPlannerControllerProvider);
      expect(state.generatedPlan, isNotNull);
      expect(state.generatedPlan!.sessions, hasLength(3));
    });

    test('7. updateExerciseSets modifies a planned exercise', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final ctrl = container.read(smartPlannerControllerProvider.notifier);
      ctrl.toggleDay(1);
      ctrl.toggleDay(3);
      ctrl.toggleDay(5);
      ctrl.generatePlan(_sampleExercises());

      final stateBefore = container.read(smartPlannerControllerProvider);
      expect(stateBefore.generatedPlan, isNotNull);
      expect(stateBefore.generatedPlan!.sessions, isNotEmpty);
      expect(
        stateBefore.generatedPlan!.sessions.first.exercises,
        isNotEmpty,
      );

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
    });
  });
}
