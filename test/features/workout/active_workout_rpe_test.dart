import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:strength_training_tracker/src/features/workout/workout_summary_screen.dart';
import 'package:training_engine/training_engine.dart';

Future<void> _pumpFrames(
  WidgetTester tester, {
  int count = 10,
  Duration step = const Duration(milliseconds: 100),
}) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(step);
  }
}

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
  testWidgets(
    'finishing from confirmation sheet closes the sheet before summary navigation',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = MemoryAppStateRepository(
        initialState: DemoSeedData.initialState(),
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

      container.read(routineControllerProvider).startSession('push_day');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ActiveWorkoutScreen(),
          ),
          GoRoute(
            path: '/workout/:sessionId/summary',
            builder: (context, state) => WorkoutSummaryScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await _pumpFrames(tester);

      await tester.tap(find.text('FINISH').last);
      await _pumpFrames(tester);

      expect(find.text('Finish & Save'), findsOneWidget);

      await tester.tap(find.text('Finish & Save'));
      await _pumpFrames(tester);

      expect(find.text('Workout Complete'), findsOneWidget);
      expect(find.text('Push Day'), findsOneWidget);
      expect(find.text('Finish & Save'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'finish sheet still routes to summary if active session clears before tap',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repository = MemoryAppStateRepository(
        initialState: DemoSeedData.initialState(),
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

      final active = container
          .read(routineControllerProvider)
          .startSession('push_day');
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const ActiveWorkoutScreen(),
          ),
          GoRoute(
            path: '/workout/:sessionId/summary',
            builder: (context, state) => WorkoutSummaryScreen(
              sessionId: state.pathParameters['sessionId']!,
            ),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      );
      await _pumpFrames(tester);

      await tester.tap(find.text('FINISH').last);
      await _pumpFrames(tester);
      expect(find.text('Finish & Save'), findsOneWidget);

      container.read(workoutControllerProvider).completeSession(rpe: 8);
      await _pumpFrames(tester);

      await tester.tap(find.text('Finish & Save'));
      await _pumpFrames(tester);

      expect(find.text('Workout Complete'), findsOneWidget);
      expect(find.text('Push Day'), findsOneWidget);
      expect(
        router.routeInformationProvider.value.uri.path,
        '/workout/${active.id}/summary',
      );
      expect(find.text('Finish & Save'), findsNothing);
      expect(find.byType(BottomSheet), findsNothing);
    },
  );

  testWidgets(
    'logging strength sets shows newest set first in session history',
    (tester) async {
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
      // Tap Log — RPE modal should appear
      await tester.tap(
        find.byKey(const ValueKey('active-workout-log-set-button')),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // The RPE modal is shown
      expect(find.text('Log Set RPE'), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);

      for (var i = 0; i < 3; i++) {
        if (i > 0) {
          await tester.tap(
            find.byKey(const ValueKey('active-workout-log-set-button')),
          );
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 500));
        }

        await tester.tap(find.text('Save & Log Set'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 500));
      }

      expect(find.textContaining('RPE 8.0'), findsWidgets);
      final set3 = find.text('Set 3: 100 kg x 6 • RPE 8.0');
      final set2 = find.text('Set 2: 100 kg x 6 • RPE 8.0');
      final set1 = find.text('Set 1: 100 kg x 6 • RPE 8.0');
      expect(set3, findsOneWidget);
      expect(set2, findsOneWidget);
      expect(set1, findsOneWidget);
      expect(tester.getTopLeft(set3).dy, lessThan(tester.getTopLeft(set2).dy));
      expect(tester.getTopLeft(set2).dy, lessThan(tester.getTopLeft(set1).dy));
    },
  );

  testWidgets('RPE modal only allows the engine-supported 5 to 10 range', (
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

    await tester.tap(
      find.byKey(const ValueKey('active-workout-log-set-button')),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    final slider = tester.widget<Slider>(find.byType(Slider));
    expect(slider.min, 5.0);
    expect(slider.max, 10.0);
    expect(slider.divisions, 10);
  });

  testWidgets(
    'shows an engine-backed load suggestion from reconciled history',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final completedAt = DateTime.utc(2026, 4, 1, 18, 0);
      final completedSession = WorkoutSession(
        id: 'workout-suggestion-session',
        routineId: 'push_day',
        status: WorkoutSessionStatus.completed,
        startedAt: DateTime.utc(2026, 4, 1, 17, 0),
        endedAt: completedAt,
        lastActivityAt: completedAt,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_bench_press',
            weightKg: 80,
            reps: 12,
            rpe: 8.0,
            completedAt: DateTime.utc(2026, 4, 1, 17, 15),
            note: '',
            setNumber: 1,
          ),
        ],
        sessionNote: '',
        rpe: 8.0,
      );
      final initialState = DemoSeedData.initialState().copyWith(
        sessions: [completedSession],
      );
      final repository = MemoryAppStateRepository(initialState: initialState);
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
      expect(find.textContaining('RPE 8.0'), findsOneWidget);
    },
  );

  testWidgets('timed previous performance is shown in minutes', (tester) async {
    tester.view.physicalSize = const Size(1200, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final completedAt = DateTime.utc(2026, 5, 1, 18, 0);
    final treadmillRoutine = Routine(
      id: 'treadmill_day',
      name: 'Treadmill Day',
      category: 'cardio',
      estimatedDurationMin: 30,
      archived: false,
      exercises: const [
        RoutineExercise(
          exerciseId: 'treadmill',
          targetSets: 1,
          targetReps: 1,
          restSeconds: 60,
          order: 0,
          targetDurationSeconds: 720,
        ),
      ],
    );
    final completedSession = WorkoutSession(
      id: 'previous-treadmill-session',
      routineId: treadmillRoutine.id,
      status: WorkoutSessionStatus.completed,
      startedAt: DateTime.utc(2026, 5, 1, 17, 30),
      endedAt: completedAt,
      lastActivityAt: completedAt,
      currentExerciseIndex: 0,
      completedSets: [
        CompletedSet(
          exerciseId: 'treadmill',
          setNumber: 1,
          weightKg: 0,
          reps: 1,
          durationSeconds: 720,
          rpe: 7.5,
          completedAt: DateTime.utc(2026, 5, 1, 17, 45),
          note: '',
        ),
      ],
      sessionNote: '',
      rpe: 7.5,
    );
    final baseState = DemoSeedData.initialState();
    final initialState = baseState.copyWith(
      routines: [treadmillRoutine, ...baseState.routines],
      sessions: [completedSession],
    );
    final repository = MemoryAppStateRepository(initialState: initialState);
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

    container.read(routineControllerProvider).startSession(treadmillRoutine.id);

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
    await _pumpFrames(tester);

    expect(find.text('12 min'), findsOneWidget);
    expect(find.text('720s'), findsNothing);
    expect(find.textContaining('RPE 7.5'), findsOneWidget);
  });
}
