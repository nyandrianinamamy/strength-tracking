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

Widget _buildDebugScreenApp({
  Map<String, dynamic>? savedEngineState,
  TrainingEngineStateRepository? trainingEngineRepository,
}) {
  const initialState = AppState(exercises: [], routines: [], sessions: []);

  return ProviderScope(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(
        MemoryAppStateRepository(initialState: initialState),
      ),
      initialAppStateProvider.overrideWithValue(initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(
        trainingEngineRepository ??
            MemoryTrainingEngineStateRepository(initialState: savedEngineState),
      ),
    ],
    child: const MaterialApp(home: TrainingEngineDebugScreen()),
  );
}

class _ThrowingTrainingEngineStateRepository
    implements TrainingEngineStateRepository {
  @override
  Future<void> clear() async {}

  @override
  Future<Map<String, dynamic>?> load() async {
    throw const FormatException('corrupted engine state');
  }

  @override
  Future<void> save(Map<String, dynamic> state) async {
    throw const FormatException('corrupted engine state');
  }
}

TrainingEngineStateRepository _throwingTrainingEngineRepository() {
  return _ThrowingTrainingEngineStateRepository();
}

void _expectRow(String label, String value) {
  final row = find.widgetWithText(Row, label);
  expect(row, findsOneWidget);
  expect(find.descendant(of: row, matching: find.text(value)), findsOneWidget);
}

void _expectRowContaining(String label, String valueFragment) {
  final row = find.widgetWithText(Row, label);
  expect(row, findsOneWidget);
  expect(
    find.descendant(of: row, matching: find.textContaining(valueFragment)),
    findsOneWidget,
  );
}

void _expectRowInSection(String sectionTitle, String label, String value) {
  final section = find.widgetWithText(Card, sectionTitle);
  expect(section, findsOneWidget);
  final row = find.descendant(
    of: section,
    matching: find.widgetWithText(Row, label),
  );
  expect(row, findsOneWidget);
  expect(find.descendant(of: row, matching: find.text(value)), findsOneWidget);
}

Map<String, dynamic> _savedEngineState() {
  final now = DateTime.now();
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
      startedAt: now.subtract(const Duration(hours: 1)),
      endedAt: now,
      sets: [
        LoggedSet(
          exerciseId: 'barbell_back_squat',
          weightKg: 100,
          reps: 8,
          rpe: 8.0,
          completedAt: now.subtract(const Duration(minutes: 45)),
        ),
      ],
    ),
  );
  savedEngine.ingestSleep(
    SleepRecord(
      date: now.subtract(const Duration(days: 1)),
      totalSleep: const Duration(hours: 8),
      deepSleep: const Duration(minutes: 72),
      remSleep: const Duration(minutes: 96),
      coreSleep: const Duration(hours: 4, minutes: 48),
    ),
  );
  savedEngine.ingestSleep(
    SleepRecord(
      date: now.subtract(const Duration(days: 2)),
      totalSleep: const Duration(hours: 8),
      deepSleep: const Duration(minutes: 72),
      remSleep: const Duration(minutes: 96),
      coreSleep: const Duration(hours: 4, minutes: 48),
    ),
  );
  savedEngine.ingestHrv(
    HrvRecord(
      date: now.subtract(const Duration(days: 2)),
      sdnn: 60.0,
      restingHeartRate: 60.0,
    ),
  );
  savedEngine.ingestHrv(
    HrvRecord(
      date: now.subtract(const Duration(days: 1)),
      sdnn: 60.0,
      restingHeartRate: 60.0,
    ),
  );
  savedEngine.ingestHrv(
    HrvRecord(date: now, sdnn: 60.0, restingHeartRate: 60.0),
  );

  final snapshot = savedEngine.serializeState();
  snapshot['lastUpdated'] = DateTime(2026, 4, 1, 18, 0).toIso8601String();
  return snapshot;
}

Map<String, dynamic> _savedEngineStateWithBenchAndSquatData() {
  final now = DateTime.now();
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
      id: 'debug-session-1',
      startedAt: now.subtract(const Duration(hours: 1)),
      endedAt: now,
      sets: [
        LoggedSet(
          exerciseId: 'barbell_bench_press',
          weightKg: 90,
          reps: 6,
          rpe: 8.0,
          completedAt: now.subtract(const Duration(minutes: 50)),
        ),
        LoggedSet(
          exerciseId: 'barbell_back_squat',
          weightKg: 120,
          reps: 5,
          rpe: 8.5,
          completedAt: now.subtract(const Duration(minutes: 35)),
        ),
      ],
    ),
  );
  savedEngine.ingestSleep(
    SleepRecord(
      date: now.subtract(const Duration(days: 1)),
      totalSleep: const Duration(hours: 8),
      deepSleep: const Duration(minutes: 72),
      remSleep: const Duration(minutes: 96),
      coreSleep: const Duration(hours: 4, minutes: 48),
    ),
  );
  savedEngine.ingestSleep(
    SleepRecord(
      date: now.subtract(const Duration(days: 2)),
      totalSleep: const Duration(hours: 8),
      deepSleep: const Duration(minutes: 72),
      remSleep: const Duration(minutes: 96),
      coreSleep: const Duration(hours: 4, minutes: 48),
    ),
  );
  savedEngine.ingestHrv(
    HrvRecord(
      date: now.subtract(const Duration(days: 2)),
      sdnn: 60.0,
      restingHeartRate: 60.0,
    ),
  );
  savedEngine.ingestHrv(
    HrvRecord(
      date: now.subtract(const Duration(days: 1)),
      sdnn: 60.0,
      restingHeartRate: 60.0,
    ),
  );
  savedEngine.ingestHrv(
    HrvRecord(date: now, sdnn: 60.0, restingHeartRate: 60.0),
  );

  final snapshot = savedEngine.serializeState();
  snapshot['lastUpdated'] = DateTime(2026, 4, 1, 18, 0).toIso8601String();
  return snapshot;
}

void main() {
  testWidgets(
    'debug screen shows useful error text when engine loading fails',
    (tester) async {
      await tester.pumpWidget(
        _buildDebugScreenApp(
          trainingEngineRepository: _throwingTrainingEngineRepository(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Engine Status'), findsOneWidget);
      expect(find.textContaining('corrupted engine state'), findsWidgets);
    },
  );

  testWidgets(
    'debug screen remains useful with no ingested sessions',
    (tester) async {
      await tester.pumpWidget(_buildDebugScreenApp());
      await tester.pumpAndSettle();

      expect(find.text('Engine Status'), findsOneWidget);
      expect(find.textContaining('0'), findsWidgets);
      expect(find.text('Fatigue Breakdown'), findsOneWidget);
    },
  );

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
      _expectRowInSection('Engine Status', 'sessions ingested', '1');
      _expectRowContaining('Last updated', '2026-04-01T18:00:00');
      _expectRowInSection('Engine Status', 'Sleep records', '2');
      _expectRowInSection('Engine Status', 'HRV records', '3');
      _expectRowInSection('Engine Status', 'Daily loads', '1');

      _expectRow('Readiness score', '82.8/100');
      _expectRow('confidence', 'high');
      _expectRow('Tier', 'full');
      _expectRow('Flags', 'None');
      _expectRow('acwr', '92.5');
      _expectRow('sleep', '70.0');
      _expectRow('hrv', '85.0');
    },
  );

  testWidgets(
    'debug screen renders fatigue, recommendation, and raw snapshot sections',
    (tester) async {
      final savedEngineState = _savedEngineStateWithBenchAndSquatData();
      final container = ProviderContainer(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(
            MemoryAppStateRepository(
              initialState: const AppState(
                exercises: [],
                routines: [],
                sessions: [],
              ),
            ),
          ),
          initialAppStateProvider.overrideWithValue(
            const AppState(exercises: [], routines: [], sessions: []),
          ),
          trainingEngineStateRepositoryProvider.overrideWithValue(
            MemoryTrainingEngineStateRepository(initialState: savedEngineState),
          ),
        ],
      );
      addTearDown(container.dispose);

      expect(
        await container.read(engineDebugFatigueRowsProvider.future),
        isNotEmpty,
      );
      expect(
        await container.read(engineDebugRecommendationRowsProvider.future),
        isNotEmpty,
      );
      expect(
        await container.read(engineDebugRawSnapshotProvider.future),
        contains('barbell_back_squat'),
      );

      await tester.pumpWidget(
        _buildDebugScreenApp(savedEngineState: savedEngineState),
      );
      await tester.pumpAndSettle();

      await tester.scrollUntilVisible(
        find.text('Raw Snapshot'),
        400,
        scrollable: find.byType(Scrollable),
      );
      await tester.pumpAndSettle();

      expect(find.text('Fatigue Breakdown'), findsOneWidget);
      expect(find.text('Heatmap Payload'), findsOneWidget);
      expect(find.text('Recommendation Breakdown'), findsOneWidget);
      expect(find.text('Persisted State Summary'), findsOneWidget);
      expect(find.text('Raw Snapshot'), findsOneWidget);
      expect(find.textContaining('barbell_back_squat'), findsWidgets);
      expect(find.textContaining('barbell_bench_press'), findsWidgets);

      await tester.tap(find.text('Raw Snapshot'));
      await tester.pumpAndSettle();
      expect(find.textContaining('barbell_back_squat'), findsWidgets);
      expect(find.textContaining('lastTopSets'), findsWidgets);
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
