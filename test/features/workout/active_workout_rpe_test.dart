import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';
import 'package:training_engine/training_engine.dart';

Map<String, dynamic> _savedEngineState() {
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
      id: 'workout-suggestion-session',
      startedAt: DateTime.utc(2026, 4, 1, 17, 0),
      endedAt: DateTime.utc(2026, 4, 1, 18, 0),
      sets: [
        LoggedSet(
          exerciseId: 'barbell_bench_press',
          weightKg: 80,
          reps: 12,
          rpe: 8.0,
          completedAt: DateTime.utc(2026, 4, 1, 17, 15),
        ),
      ],
    ),
  );

  return engine.serializeState();
}

void main() {
  testWidgets('logging a strength set shows its per-set RPE in session history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repository = MemoryAppStateRepository(
      initialState: DemoSeedData.initialState(),
    );
    final container = ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
      ],
    );
    addTearDown(container.dispose);

    container.read(routineControllerProvider).startSession('push_day');

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

    await tester.enterText(
      find.byKey(const ValueKey('active-workout-weight-input')),
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('active-workout-reps-input')),
      '6',
    );
    await tester.enterText(
      find.byKey(const ValueKey('active-workout-rpe-input')),
      '8.5',
    );

    await tester.tap(find.byKey(const ValueKey('active-workout-log-set-button')));
    await tester.pump();

    expect(find.textContaining('RPE 8.5'), findsOneWidget);
  });

  testWidgets('shows an engine-backed load suggestion without app history', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final initialState = DemoSeedData.initialState().copyWith(
      sessions: const <WorkoutSession>[],
    );
    final repository = MemoryAppStateRepository(
      initialState: initialState,
    );
    final container = ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(repository),
        initialAppStateProvider.overrideWithValue(repository.state),
        trainingEngineStateRepositoryProvider.overrideWithValue(
          MemoryTrainingEngineStateRepository(
            initialState: _savedEngineState(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(routineControllerProvider).startSession('push_day');

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

    expect(find.textContaining('Suggested'), findsAtLeastNWidgets(1));
  });
}
