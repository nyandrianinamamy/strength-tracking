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
import 'package:strength_training_tracker/src/features/dashboard/dashboard_screen.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';

void main() {
  testWidgets(
    'dashboard treadmill workout cards show duration, not zero volume',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final endedAt = DateTime.now().subtract(const Duration(hours: 1));
      final treadmill = Exercise(
        id: 'treadmill',
        name: 'Treadmill',
        primaryMuscles: const ['Quads'],
        secondaryMuscles: const [],
        equipment: const ['Machine'],
        instructions: '',
        exerciseType: 'timed',
        archived: false,
      );
      final routine = Routine(
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
      final session = WorkoutSession(
        id: 'treadmill-session',
        routineId: routine.id,
        status: WorkoutSessionStatus.completed,
        startedAt: endedAt.subtract(const Duration(minutes: 12)),
        endedAt: endedAt,
        lastActivityAt: endedAt,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: treadmill.id,
            setNumber: 1,
            weightKg: 0,
            reps: 0,
            durationSeconds: 720,
            rpe: 7.5,
            completedAt: endedAt,
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: 7.5,
      );
      final initialState = AppState(
        exercises: [treadmill],
        routines: [routine],
        sessions: [session],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateRepositoryProvider.overrideWithValue(
              MemoryAppStateRepository(initialState: initialState),
            ),
            initialAppStateProvider.overrideWithValue(initialState),
            trainingEngineStateRepositoryProvider.overrideWithValue(
              MemoryTrainingEngineStateRepository(),
            ),
            dashboardSnapshotProvider.overrideWith((ref) async {
              return ProgressService().dashboardSnapshot(
                initialState,
                currentE1rmsByExercise: const {},
              );
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: DashboardScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -900));
      await tester.pumpAndSettle();

    expect(find.text('Treadmill Day'), findsWidgets);
      expect(find.text('12m'), findsAtLeastNWidgets(1));
      expect(find.text('Time'), findsAtLeastNWidgets(1));
      expect(find.text('0 kg'), findsNothing);
    },
  );
}
