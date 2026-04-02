import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_debug_screen.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

Widget _buildDebugScreenApp({Map<String, dynamic>? savedEngineState}) {
  const initialState = AppState(exercises: [], routines: [], sessions: []);

  return ProviderScope(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(
        MemoryAppStateRepository(initialState: initialState),
      ),
      initialAppStateProvider.overrideWithValue(initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(
        MemoryTrainingEngineStateRepository(initialState: savedEngineState),
      ),
    ],
    child: const MaterialApp(home: TrainingEngineDebugScreen()),
  );
}

Map<String, dynamic> _savedEngineState() {
  final savedEngine = TrainingEngine(
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
  savedEngine.ingestSession(
    EngineSession(
      id: 'debug-session',
      startedAt: DateTime.utc(2026, 4, 1, 17, 0),
      endedAt: DateTime.utc(2026, 4, 1, 18, 0),
      sets: [
        LoggedSet(
          exerciseId: 'barbell_back_squat',
          weightKg: 100,
          reps: 8,
          rpe: 8.0,
          completedAt: DateTime.utc(2026, 4, 1, 17, 15),
        ),
      ],
    ),
  );
  return savedEngine.serializeState();
}

void main() {
  testWidgets(
    'debug screen renders status and readiness sections with engine data',
    (tester) async {
      await tester.pumpWidget(
        _buildDebugScreenApp(savedEngineState: _savedEngineState()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Training Engine Debug'), findsOneWidget);
      expect(find.text('Engine Status'), findsOneWidget);
      expect(find.text('Readiness Breakdown'), findsOneWidget);
      expect(find.textContaining('sessions ingested'), findsOneWidget);
      expect(find.textContaining('confidence'), findsOneWidget);
    },
  );

  testWidgets('dashboard shows engine debug button and opens debug screen', (
    tester,
  ) async {
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

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StrengthTrainingApp(),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Engine Debug'), findsOneWidget);

    await tester.tap(find.text('Engine Debug'));
    await tester.pumpAndSettle();

    expect(find.text('Training Engine Debug'), findsOneWidget);
  });
}
