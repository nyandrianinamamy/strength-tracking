import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';

void main() {
  testWidgets('timed countdown survives active workout view recreation', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(430, 932);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MemoryAppStateRepository(
      initialState: _activeTimedWorkoutState(),
    );
    final container = ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
        trainingEngineStateRepositoryProvider.overrideWithValue(
          MemoryTrainingEngineStateRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _pumpActiveWorkout(tester, container);
    expect(find.text('01:00'), findsOneWidget);

    container
        .read(workoutControllerProvider)
        .startTimedExerciseTimer(
          exerciseId: 'treadmill',
          durationSeconds: 60,
          now: DateTime.now().subtract(const Duration(seconds: 2)),
        );
    await tester.pump();
    expect(find.text('01:00'), findsNothing);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(home: SizedBox.shrink()),
      ),
    );
    await tester.pump();
    await _pumpActiveWorkout(tester, container);

    expect(find.text('01:00'), findsNothing);
  });
}

Future<void> _pumpActiveWorkout(
  WidgetTester tester,
  ProviderContainer container,
) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const ActiveWorkoutScreen(),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
  await tester.pump(const Duration(milliseconds: 200));
}

AppState _activeTimedWorkoutState() {
  final now = DateTime.now();
  return AppState(
    exercises: const [
      Exercise(
        id: 'treadmill',
        name: 'Treadmill',
        primaryMuscles: ['Quads', 'Glutes', 'Calves'],
        equipment: ['Machine'],
        instructions: 'Run at a steady pace.',
        archived: false,
        exerciseType: 'timed',
      ),
    ],
    routines: const [
      Routine(
        id: 'cardio_day',
        name: 'Cardio Day',
        category: 'strength',
        exercises: [
          RoutineExercise(
            exerciseId: 'treadmill',
            targetSets: 1,
            targetReps: 1,
            restSeconds: 30,
            order: 0,
            targetDurationSeconds: 60,
          ),
        ],
        estimatedDurationMin: 10,
        archived: false,
      ),
    ],
    sessions: [
      WorkoutSession(
        id: 'active-cardio-session',
        routineId: 'cardio_day',
        status: WorkoutSessionStatus.active,
        startedAt: now,
        endedAt: null,
        lastActivityAt: now,
        currentExerciseIndex: 0,
        completedSets: const [],
        sessionNote: '',
        rpe: null,
      ),
    ],
  );
}
