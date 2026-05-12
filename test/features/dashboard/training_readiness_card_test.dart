import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/dashboard/training_readiness_card.dart';
import 'package:strength_training_tracker/src/features/training_engine/healthkit_data_source.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

class _FakeHealthKitDataSource extends HealthKitDataSource {
  const _FakeHealthKitDataSource({
    this.status = HealthKitFetchStatus.noSamples,
  });

  @override
  Future<HealthKitFetchResult<SleepRecord>> fetchRecentSleepResult({
    int days = 14,
  }) async {
    return HealthKitFetchResult<SleepRecord>(status: status, records: const []);
  }

  @override
  Future<HealthKitFetchResult<HrvRecord>> fetchRecentHrvResult({
    int days = 14,
  }) async {
    return HealthKitFetchResult<HrvRecord>(status: status, records: const []);
  }

  final HealthKitFetchStatus status;
}

Widget _buildTestApp({
  AppState initialState = const AppState(
    exercises: [],
    routines: [],
    sessions: [],
  ),
  TrainingEngineStateRepository? engineRepository,
  HealthKitDataSource healthKit = const _FakeHealthKitDataSource(),
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
      healthKitDataSourceProvider.overrideWithValue(healthKit),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: TrainingReadinessCard()),
    ),
  );
}

Map<String, dynamic> _savedEngineState({
  bool acuteSleepDeprivation = false,
  bool risingRestingHeartRate = false,
}) {
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

  final now = DateTime.now().toUtc();
  if (acuteSleepDeprivation) {
    engine.ingestSleep(
      SleepRecord(
        date: now,
        totalSleep: const Duration(hours: 4, minutes: 30),
        deepSleep: const Duration(minutes: 40),
        remSleep: const Duration(minutes: 50),
        coreSleep: const Duration(hours: 3),
      ),
    );
  }

  if (risingRestingHeartRate) {
    for (var i = 0; i < 7; i++) {
      engine.ingestHrv(
        HrvRecord(
          date: now.subtract(Duration(days: 6 - i)),
          sdnn: 60.0,
          restingHeartRate: 55.0 + i * 1.2,
        ),
      );
    }
  }

  return engine.serializeState();
}

AppState _appStateWithDashboardSession({bool healthKitEnabled = false}) {
  return AppState(
    exercises: const [],
    routines: const [],
    sessions: [
      WorkoutSession(
        id: 'dashboard-session',
        routineId: 'routine-1',
        status: WorkoutSessionStatus.completed,
        startedAt: DateTime.utc(2026, 4, 1, 17, 0),
        endedAt: DateTime.utc(2026, 4, 1, 18, 0),
        lastActivityAt: DateTime.utc(2026, 4, 1, 18, 0),
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 1,
            weightKg: 100,
            reps: 8,
            rpe: 8.0,
            completedAt: DateTime.utc(2026, 4, 1, 17, 15),
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: 8.0,
      ),
    ],
    healthKitEnabled: healthKitEnabled,
  );
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
        initialState: _appStateWithDashboardSession(),
        engineRepository: MemoryTrainingEngineStateRepository(
          initialState: _savedEngineState(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('TRAINING READINESS'), findsOneWidget);
    expect(find.textContaining('FATIGUE'), findsOneWidget);
  });

  testWidgets(
    'renders limited-data state without demo recovery values after denied HealthKit fetch',
    (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          initialState: _appStateWithDashboardSession(healthKitEnabled: true),
          healthKit: const _FakeHealthKitDataSource(
            status: HealthKitFetchStatus.denied,
          ),
          engineRepository: MemoryTrainingEngineStateRepository(
            initialState: _savedEngineState(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('TRAINING READINESS'), findsOneWidget);
      expect(find.text('Limited data'), findsOneWidget);
      expect(find.text('No data'), findsNWidgets(2));
      expect(find.textContaining('8h'), findsNothing);
      expect(find.textContaining('ms'), findsNothing);
    },
  );

  testWidgets('renders an acute sleep flag without medical overclaiming', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialState: _appStateWithDashboardSession(),
        engineRepository: MemoryTrainingEngineStateRepository(
          initialState: _savedEngineState(acuteSleepDeprivation: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Short sleep detected'), findsOneWidget);
    expect(find.textContaining('diagnosis'), findsNothing);
  });

  testWidgets('renders a rising resting heart rate flag as a trend signal', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildTestApp(
        initialState: _appStateWithDashboardSession(),
        engineRepository: MemoryTrainingEngineStateRepository(
          initialState: _savedEngineState(risingRestingHeartRate: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Resting heart rate trending up'), findsOneWidget);
    expect(find.textContaining('diagnosis'), findsNothing);
  });
}
