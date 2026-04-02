import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/dashboard/training_readiness_card.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

Widget _buildTestApp({
  AppState initialState = const AppState(
    exercises: [],
    routines: [],
    sessions: [],
  ),
  TrainingEngineStateRepository? engineRepository,
}) {
  return ProviderScope(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(
        MemoryAppStateRepository(initialState: initialState),
      ),
      initialAppStateProvider.overrideWithValue(initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(
        engineRepository ?? MemoryTrainingEngineStateRepository(),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: TrainingReadinessCard(),
      ),
    ),
  );
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
      id: 'dashboard-session',
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

  return engine.serializeState();
}

void main() {
  testWidgets('renders an empty state before any training engine data exists', (
    tester,
  ) async {
    await tester.pumpWidget(_buildTestApp());
    await tester.pumpAndSettle();

    expect(find.text('Adaptive Readiness'), findsOneWidget);
    expect(find.text('Complete a workout to unlock adaptive guidance.'), findsOneWidget);
  });

  testWidgets('renders readiness summary when saved engine data exists', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        engineRepository: MemoryTrainingEngineStateRepository(
          initialState: _savedEngineState(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Adaptive Readiness'), findsOneWidget);
    expect(find.textContaining('Readiness score'), findsOneWidget);
    expect(find.textContaining('/100'), findsOneWidget);
  });
}
