import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/dashboard/training_readiness_card.dart';
import 'package:strength_training_tracker/src/features/training_engine/healthkit_data_source.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

class _FakeHealthKitDataSource extends HealthKitDataSource {
  const _FakeHealthKitDataSource();

  @override
  Future<List<SleepRecord>> fetchRecentSleep({int days = 14}) async => [];

  @override
  Future<List<HrvRecord>> fetchRecentHrv({int days = 14}) async => [];
}

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
      healthKitDataSourceProvider.overrideWithValue(
        const _FakeHealthKitDataSource(),
      ),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(
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

    expect(find.text('Training Readiness'), findsOneWidget);
    expect(
      find.text(
        'Complete a workout and sync HealthKit to unlock your readiness score.',
      ),
      findsOneWidget,
    );
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

    expect(find.text('TRAINING READINESS'), findsOneWidget);
    expect(find.textContaining('FATIGUE'), findsOneWidget);
  });
}
