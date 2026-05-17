import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';
import 'package:training_engine/training_engine.dart';

const _benchExercise = Exercise(
  id: 'barbell_bench_press',
  name: 'Barbell Bench Press',
  primaryMuscles: ['Chest'],
  secondaryMuscles: ['Triceps'],
  equipment: ['Barbell'],
  instructions: '',
  archived: false,
);

const _squatExercise = Exercise(
  id: 'barbell_back_squat',
  name: 'Barbell Back Squat',
  primaryMuscles: ['Quadriceps'],
  secondaryMuscles: ['Glutes'],
  equipment: ['Barbell'],
  instructions: '',
  archived: false,
);

const _strengthRoutine = Routine(
  id: 'strength-bench',
  name: 'Strength Bench',
  category: 'strength',
  exercises: [
    RoutineExercise(
      exerciseId: 'barbell_bench_press',
      targetSets: 3,
      targetReps: 5,
      restSeconds: 180,
      order: 0,
    ),
  ],
  estimatedDurationMin: 30,
  archived: false,
);

WorkoutSession _completedSession({
  required String id,
  required String exerciseId,
  required double weightKg,
  required int reps,
  required DateTime completedAt,
}) {
  return WorkoutSession(
    id: id,
    routineId: 'history-routine',
    status: WorkoutSessionStatus.completed,
    startedAt: completedAt.subtract(const Duration(hours: 1)),
    endedAt: completedAt,
    lastActivityAt: completedAt,
    currentExerciseIndex: 0,
    completedSets: [
      CompletedSet(
        exerciseId: exerciseId,
        setNumber: 1,
        weightKg: weightKg,
        reps: reps,
        completedAt: completedAt,
        note: '',
        rpe: 8.0,
      ),
    ],
    sessionNote: '',
    rpe: 8.0,
  );
}

Map<String, dynamic> _savedBenchEngineState({
  required String sessionId,
  required DateTime completedAt,
}) {
  final engine = TrainingEngine(
    registry: ExerciseRegistry.withDefaults(),
    profile: UserProfile(
      sex: Sex.male,
      age: 32,
      bodyWeightKg: 84,
      experience: ExperienceLevel.intermediate,
      goal: HypertrophyGoal.strength,
      availableDays: const [1, 3, 5],
      maxSessionDuration: const Duration(minutes: 60),
      createdAt: DateTime.utc(2026, 1, 1),
    ),
  );

  engine.ingestSession(
    EngineSession(
      id: sessionId,
      startedAt: completedAt.subtract(const Duration(hours: 1)),
      endedAt: completedAt,
      sets: [
        LoggedSet(
          exerciseId: 'barbell_bench_press',
          weightKg: 100,
          reps: 6,
          rpe: 8.0,
          completedAt: completedAt.subtract(const Duration(minutes: 30)),
        ),
      ],
    ),
  );

  return engine.serializeState();
}

ProviderContainer _containerFor(
  AppState appState, {
  TrainingEngineStateRepository? engineRepository,
}) {
  final appRepository = MemoryAppStateRepository(initialState: appState);
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(appRepository),
      initialAppStateProvider.overrideWithValue(appRepository.state),
      trainingEngineStateRepositoryProvider.overrideWithValue(
        engineRepository ?? MemoryTrainingEngineStateRepository(),
      ),
    ],
  );
}

Future<void> _pumpActiveWorkout(
  WidgetTester tester,
  ProviderContainer container,
) async {
  tester.view.physicalSize = const Size(1200, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

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

String _weightInputText(WidgetTester tester) {
  final field = tester.widget<TextField>(
    find.byKey(const ValueKey('active-workout-weight-input')),
  );
  return field.controller!.text;
}

void main() {
  testWidgets('shows routine-target progression for a five-rep prescription', (
    tester,
  ) async {
    final completedAt = DateTime.now();
    final appState = AppState(
      exercises: const [_benchExercise],
      routines: const [_strengthRoutine],
      sessions: [
        _completedSession(
          id: 'bench-history',
          exerciseId: 'barbell_bench_press',
          weightKg: 100,
          reps: 6,
          completedAt: completedAt,
        ),
      ],
      sex: 'male',
    );
    final container = _containerFor(appState);
    addTearDown(container.dispose);

    container.read(routineControllerProvider).startSession('strength-bench');
    await _pumpActiveWorkout(tester, container);

    expect(find.textContaining('Suggested 102.5 kg'), findsOneWidget);
    expect(find.textContaining('up from last time'), findsOneWidget);
  });

  testWidgets(
    'prefills routine-aware engine suggestion after current and previous sets are absent',
    (tester) async {
      final completedAt = DateTime.now();
      final appState = AppState(
        exercises: const [_benchExercise, _squatExercise],
        routines: const [_strengthRoutine],
        sessions: [
          _completedSession(
            id: 'engine-history',
            exerciseId: 'barbell_back_squat',
            weightKg: 120,
            reps: 6,
            completedAt: completedAt,
          ),
        ],
        sex: 'male',
      );
      final container = _containerFor(
        appState,
        engineRepository: MemoryTrainingEngineStateRepository(
          initialState: _savedBenchEngineState(
            sessionId: 'engine-history',
            completedAt: completedAt,
          ),
        ),
      );
      addTearDown(container.dispose);

      container.read(routineControllerProvider).startSession('strength-bench');
      await _pumpActiveWorkout(tester, container);

      expect(_weightInputText(tester), isNotEmpty);
      expect(double.parse(_weightInputText(tester)), greaterThan(100));
    },
  );
}
