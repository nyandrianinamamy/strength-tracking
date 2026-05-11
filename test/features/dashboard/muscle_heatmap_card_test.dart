import 'package:flutter/material.dart';
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_card.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

Map<String, dynamic> _savedEngineState() {
  final endedAt = DateTime.now().subtract(const Duration(hours: 2));
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
      id: 'heatmap-session',
      startedAt: endedAt.subtract(const Duration(hours: 1)),
      endedAt: endedAt,
      sets: [
        LoggedSet(
          exerciseId: 'barbell_bench_press',
          weightKg: 100,
          reps: 10,
          rpe: 8.5,
          completedAt: endedAt,
        ),
      ],
    ),
  );

  return engine.serializeState();
}

WorkoutSession _completedWorkoutSession() {
  final endedAt = DateTime.now().subtract(const Duration(hours: 2));
  return WorkoutSession(
    id: 'heatmap-session',
    routineId: 'heatmap-routine',
    status: WorkoutSessionStatus.completed,
    startedAt: endedAt.subtract(const Duration(hours: 1)),
    endedAt: endedAt,
    lastActivityAt: endedAt,
    currentExerciseIndex: 0,
    completedSets: [
      CompletedSet(
        exerciseId: 'barbell_bench_press',
        setNumber: 1,
        weightKg: 100,
        reps: 10,
        rpe: 8.5,
        completedAt: endedAt,
        note: '',
      ),
    ],
    sessionNote: '',
    rpe: 8.5,
  );
}

void main() {
  testWidgets('renders engine-backed fatigue on the dashboard heatmap', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final initialState = AppState(
      exercises: [],
      routines: [],
      routineGroups: [],
      sessions: [_completedWorkoutSession()],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(
            MemoryAppStateRepository(initialState: initialState),
          ),
          initialAppStateProvider.overrideWithValue(initialState),
          trainingEngineStateRepositoryProvider.overrideWithValue(
            MemoryTrainingEngineStateRepository(
              initialState: _savedEngineState(),
            ),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: MuscleHeatmapCard()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final heatmap = tester.widget<BodyHeatmap>(find.byType(BodyHeatmap).first);
    expect(heatmap.data[Muscle.chest]?.intensity, greaterThan(0));
  });
}
