// test/features/smart_planner/smart_planner_adoption_test.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/smart_planner/smart_planner_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:training_engine/training_engine.dart';

ProviderContainer _buildContainer() {
  final emptyState = AppState.empty();
  final repo = MemoryAppStateRepository(initialState: emptyState);

  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(repo),
      initialAppStateProvider.overrideWithValue(emptyState),
      trainingEngineProvider.overrideWith(
        (ref) async => _neutralTrainingEngine(),
      ),
    ],
  );
}

TrainingEngine _neutralTrainingEngine() {
  return TrainingEngine(
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
}

void main() {
  group('SmartPlannerController.adopt()', () {
    test('1. adopt() does nothing when no plan has been generated', () {
      final container = _buildContainer();
      addTearDown(container.dispose);

      final planner = container.read(smartPlannerControllerProvider.notifier);
      final appState = container.read(appStateControllerProvider.notifier);

      // No plan generated — adopt should be a no-op
      planner.adopt(appState);

      final state = container.read(appStateControllerProvider);
      expect(state.routines, isEmpty);
      expect(state.routineGroups, isEmpty);
      expect(state.activeRoutineGroupId, isNull);
    });

    test(
      '2. adopt() with 3 days creates 3 routines, 1 group, sets activeRoutineGroupId',
      () async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        final planner = container.read(smartPlannerControllerProvider.notifier);
        final appStateCtrl = container.read(
          appStateControllerProvider.notifier,
        );

        // Select 3 non-consecutive days → fullBody split
        planner.toggleDay(1); // Mon
        planner.toggleDay(3); // Wed
        planner.toggleDay(5); // Fri
        await planner.generatePlan([]);

        // Verify plan was generated with 3 sessions
        final plannerState = container.read(smartPlannerControllerProvider);
        expect(plannerState.generatedPlan, isNotNull);
        expect(plannerState.generatedPlan!.sessions, hasLength(3));

        // Adopt the plan
        planner.adopt(appStateCtrl);

        final appState = container.read(appStateControllerProvider);

        // 3 routines created
        expect(appState.routines, hasLength(3));

        // 1 routine group created
        expect(appState.routineGroups, hasLength(1));

        final group = appState.routineGroups.first;

        // Group references all 3 routines
        expect(group.routineIds, hasLength(3));
        expect(group.pendingRoutineIds, hasLength(3));
        expect(
          group.routineIds,
          containsAll(appState.routines.map((r) => r.id)),
        );
        expect(
          group.pendingRoutineIds,
          containsAll(appState.routines.map((r) => r.id)),
        );

        // activeRoutineGroupId is set to the new group's id
        expect(appState.activeRoutineGroupId, equals(group.id));

        // Each routine has exercises (or at least a category)
        for (final routine in appState.routines) {
          expect(routine.id, isNotEmpty);
          expect(routine.name, isNotEmpty);
          expect(routine.category, isNotEmpty);
        }
      },
    );

    test(
      '3. adopt() routines have correct category and day-based names',
      () async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        final planner = container.read(smartPlannerControllerProvider.notifier);
        final appStateCtrl = container.read(
          appStateControllerProvider.notifier,
        );

        // 3 consecutive days → pushPullLegs split
        planner.toggleDay(1); // Mon
        planner.toggleDay(2); // Tue
        planner.toggleDay(3); // Wed
        await planner.generatePlan([]);

        planner.adopt(appStateCtrl);

        final appState = container.read(appStateControllerProvider);
        expect(appState.routines, hasLength(3));

        // All routines should have non-localized category key
        for (final routine in appState.routines) {
          expect(routine.category, equals('strength'));
        }

        // Group name should contain split label and "Week of"
        final group = appState.routineGroups.first;
        expect(group.name, contains('Push/Pull/Legs'));
        expect(group.name, contains('Week of'));
      },
    );

    test(
      '4. each adopted routine maps exercises with correct fields',
      () async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        final planner = container.read(smartPlannerControllerProvider.notifier);
        final appStateCtrl = container.read(
          appStateControllerProvider.notifier,
        );

        planner.toggleDay(1);
        planner.toggleDay(3);
        planner.toggleDay(5);
        await planner.generatePlan([]);

        final plannerState = container.read(smartPlannerControllerProvider);
        final sessions = plannerState.generatedPlan!.sessions;

        planner.adopt(appStateCtrl);

        final appState = container.read(appStateControllerProvider);

        // Verify exercise mapping for each routine
        for (int i = 0; i < appState.routines.length; i++) {
          final routine = appState.routines[i];
          final session = sessions[i];

          expect(routine.exercises, hasLength(session.exercises.length));
          expect(
            routine.estimatedDurationMin,
            equals(session.estimatedDuration.inMinutes),
          );

          for (int j = 0; j < routine.exercises.length; j++) {
            final re = routine.exercises[j];
            final pe = session.exercises[j];

            expect(re.exerciseId, equals(pe.exerciseId));
            expect(re.targetSets, equals(pe.targetSets));
            expect(re.targetReps, equals(pe.targetReps));
            expect(re.restSeconds, equals(pe.restSeconds));
            expect(re.order, equals(j));
          }
        }
      },
    );

    test(
      '5. adopt() appends to existing routines without overwriting',
      () async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        final planner = container.read(smartPlannerControllerProvider.notifier);
        final appStateCtrl = container.read(
          appStateControllerProvider.notifier,
        );

        // Generate and adopt once
        planner.toggleDay(1);
        planner.toggleDay(3);
        planner.toggleDay(5);
        await planner.generatePlan([]);
        planner.adopt(appStateCtrl);

        final firstState = container.read(appStateControllerProvider);
        expect(firstState.routines, hasLength(3));
        expect(firstState.routineGroups, hasLength(1));

        // Generate and adopt a second time
        await planner.generatePlan([]);
        planner.adopt(appStateCtrl);

        final secondState = container.read(appStateControllerProvider);
        expect(secondState.routines, hasLength(6));
        expect(secondState.routineGroups, hasLength(2));
      },
    );

    test(
      '6. adopt() creates Exercise records for engine-default exercise IDs',
      () async {
        final container = _buildContainer();
        addTearDown(container.dispose);

        final planner = container.read(smartPlannerControllerProvider.notifier);
        final appStateCtrl = container.read(
          appStateControllerProvider.notifier,
        );

        // Start with empty exercises — planner will use engine defaults
        planner.toggleDay(1);
        await planner.generatePlan([]);

        final plannerState = container.read(smartPlannerControllerProvider);
        final plannedExerciseIds = plannerState.generatedPlan!.sessions
            .expand((s) => s.exercises)
            .map((e) => e.exerciseId)
            .toSet();

        planner.adopt(appStateCtrl);

        final appState = container.read(appStateControllerProvider);

        // Every exercise ID used in routines should be resolvable
        for (final routine in appState.routines) {
          for (final re in routine.exercises) {
            final found = appState.exerciseById(re.exerciseId);
            expect(
              found,
              isNotNull,
              reason: 'Exercise ${re.exerciseId} should exist in AppState',
            );
          }
        }

        // New Exercise records should have been created
        expect(appState.exercises, isNotEmpty);
        expect(
          appState.exercises.map((e) => e.id).toSet(),
          containsAll(plannedExerciseIds),
        );
      },
    );
  });
}
