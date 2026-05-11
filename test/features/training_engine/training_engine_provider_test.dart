import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/healthkit_data_source.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_adapter.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:training_engine/training_engine.dart';

AppState _appStateWithCompletedSession() {
  final completedAt = DateTime.utc(2026, 3, 1, 18, 0);
  return AppState(
    exercises: const [
      Exercise(
        id: 'barbell_back_squat',
        name: 'Barbell Back Squat',
        primaryMuscles: ['Quadriceps'],
        secondaryMuscles: ['Glutes'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      ),
    ],
    routines: const [],
    sessions: [
      WorkoutSession(
        id: 'completed-session-1',
        routineId: 'routine-1',
        status: WorkoutSessionStatus.completed,
        startedAt: completedAt.subtract(const Duration(hours: 1)),
        endedAt: completedAt,
        lastActivityAt: completedAt,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 1,
            weightKg: 110.0,
            reps: 8,
            completedAt: completedAt,
            note: '',
            rpe: 8.0,
          ),
        ],
        sessionNote: '',
        rpe: 8.0,
      ),
    ],
    sex: 'male',
  );
}

WorkoutSession _completedSession({
  required String id,
  required DateTime completedAt,
  String exerciseId = 'barbell_back_squat',
  double weightKg = 110.0,
}) {
  return WorkoutSession(
    id: id,
    routineId: 'routine-1',
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
        reps: 8,
        completedAt: completedAt,
        note: '',
        rpe: 8.0,
      ),
    ],
    sessionNote: '',
    rpe: 8.0,
  );
}

AppState _appStateWithCompletedSessions(List<WorkoutSession> sessions) {
  return AppState(
    exercises: const [
      Exercise(
        id: 'barbell_back_squat',
        name: 'Barbell Back Squat',
        primaryMuscles: ['Quadriceps'],
        secondaryMuscles: ['Glutes'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      ),
      Exercise(
        id: 'barbell_bench_press',
        name: 'Barbell Bench Press',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Triceps'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      ),
    ],
    routines: const [],
    sessions: sessions,
    sex: 'male',
  );
}

AppState _appStateWithTimedOnlyCompletedSession() {
  final completedAt = DateTime.utc(2026, 3, 2, 18, 0);
  return AppState(
    exercises: const [
      Exercise(
        id: 'plank',
        name: 'Plank',
        primaryMuscles: ['Abs'],
        secondaryMuscles: ['Obliques'],
        equipment: ['Bodyweight'],
        instructions: '',
        archived: false,
      ),
    ],
    routines: const [],
    sessions: [
      WorkoutSession(
        id: 'completed-timed-session-1',
        routineId: 'routine-core',
        status: WorkoutSessionStatus.completed,
        startedAt: completedAt.subtract(const Duration(minutes: 20)),
        endedAt: completedAt,
        lastActivityAt: completedAt,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'plank',
            setNumber: 1,
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            completedAt: completedAt,
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: 7.0,
      ),
    ],
    sex: 'male',
  );
}

ProviderContainer _buildContainer({
  required AppState initialState,
  required AppStateRepository appRepository,
  required TrainingEngineStateRepository engineRepository,
  HealthKitDataSource healthKit = const HealthKitDataSource(),
}) {
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(appRepository),
      initialAppStateProvider.overrideWithValue(initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(engineRepository),
      healthKitDataSourceProvider.overrideWithValue(healthKit),
    ],
  );
}

class _FakeHealthKitDataSource extends HealthKitDataSource {
  const _FakeHealthKitDataSource({
    this.sleepRecords = const [],
    this.hrvRecords = const [],
    this.sleepStatus = HealthKitFetchStatus.success,
    this.hrvStatus = HealthKitFetchStatus.success,
  });

  final List<SleepRecord> sleepRecords;
  final List<HrvRecord> hrvRecords;
  final HealthKitFetchStatus sleepStatus;
  final HealthKitFetchStatus hrvStatus;

  @override
  Future<HealthKitFetchResult<SleepRecord>> fetchRecentSleepResult({
    int days = 14,
  }) async {
    return HealthKitFetchResult(status: sleepStatus, records: sleepRecords);
  }

  @override
  Future<HealthKitFetchResult<HrvRecord>> fetchRecentHrvResult({
    int days = 14,
  }) async {
    return HealthKitFetchResult(status: hrvStatus, records: hrvRecords);
  }
}

Map<String, dynamic> _savedEngineStateWithBenchAndSquatData() {
  final now = DateTime.utc(2026, 4, 1, 18, 0);
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
      id: 'completed-session-1',
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

  final snapshot = savedEngine.serializeState();
  snapshot['lastUpdated'] = now.toIso8601String();
  return snapshot;
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
  Future<void> save(Map<String, dynamic> state) async {}
}

Map<String, dynamic> _savedStateForSessions(List<WorkoutSession> sessions) {
  final appState = _appStateWithCompletedSessions(sessions);
  final adapter = const TrainingEngineAdapter();
  final registry = ExerciseRegistry.withDefaults();
  for (final exercise in appState.exercises) {
    final engineExercise = adapter.toEngineExercise(exercise, registry);
    if (engineExercise != null) {
      registry.addCustom(engineExercise);
    }
  }
  final engine = TrainingEngine(
    registry: registry,
    profile: adapter.toUserProfile(appState),
  );
  engine.bootstrapFromHistory(
    sessions.map(adapter.toEngineSession).whereType<EngineSession>().toList(),
  );
  return engine.serializeState();
}

void main() {
  group('trainingEngineProvider', () {
    test(
      'bootstraps from completed app sessions when no saved engine state exists',
      () async {
        final appState = _appStateWithCompletedSession();
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sessionsIngested, 1);
        expect(engine.state.e1rmHistory['barbell_back_squat'], isNotEmpty);
        expect(engineRepository.state, isNotNull);
      },
    );

    test(
      'restores saved engine state without bootstrapping app sessions again',
      () async {
        final appState = _appStateWithCompletedSession();
        final appRepository = MemoryAppStateRepository(initialState: appState);

        final savedEngine = TrainingEngine(
          registry: ExerciseRegistry.withDefaults(),
          profile: UserProfile(
            sex: Sex.male,
            age: 30,
            bodyWeightKg: 82,
            experience: ExperienceLevel.intermediate,
            goal: HypertrophyGoal.hypertrophy,
            availableDays: const [1, 3, 5],
            maxSessionDuration: const Duration(minutes: 60),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        savedEngine.ingestSession(
          EngineSession(
            id: 'completed-session-1',
            startedAt: DateTime.utc(2026, 2, 1, 17, 0),
            endedAt: DateTime.utc(2026, 2, 1, 18, 0),
            sets: [
              LoggedSet(
                exerciseId: 'barbell_bench_press',
                weightKg: 80,
                reps: 8,
                rpe: 8.0,
                completedAt: DateTime.utc(2026, 2, 1, 17, 10),
              ),
            ],
          ),
        );

        final engineRepository = MemoryTrainingEngineStateRepository(
          initialState: savedEngine.serializeState(),
        );
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sessionsIngested, 1);
        expect(engine.state.e1rmHistory['barbell_bench_press'], isNotEmpty);
        expect(engine.state.e1rmHistory['barbell_back_squat'], isNull);
      },
    );

    test(
      'refreshes restored profile demographics without dropping saved training facts',
      () async {
        final appState = _appStateWithCompletedSession().copyWith(
          sex: 'female',
          age: 44,
          weight: 68.5,
          fitnessGoal: 'strength',
        );
        final appRepository = MemoryAppStateRepository(initialState: appState);

        final savedEngine = TrainingEngine(
          registry: ExerciseRegistry.withDefaults(),
          profile: UserProfile(
            sex: Sex.male,
            age: 30,
            bodyWeightKg: 82,
            experience: ExperienceLevel.intermediate,
            goal: HypertrophyGoal.hypertrophy,
            availableDays: const [1, 3, 5],
            maxSessionDuration: const Duration(minutes: 60),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        savedEngine.ingestSession(
          EngineSession(
            id: 'completed-session-1',
            startedAt: DateTime.utc(2026, 2, 1, 17, 0),
            endedAt: DateTime.utc(2026, 2, 1, 18, 0),
            sets: [
              LoggedSet(
                exerciseId: 'barbell_bench_press',
                weightKg: 80,
                reps: 8,
                rpe: 8.0,
                completedAt: DateTime.utc(2026, 2, 1, 17, 10),
              ),
            ],
          ),
        );
        final engineRepository = MemoryTrainingEngineStateRepository(
          initialState: savedEngine.serializeState(),
        );
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.profile.sex, Sex.female);
        expect(engine.state.profile.age, 44);
        expect(engine.state.profile.bodyWeightKg, 68.5);
        expect(engine.state.profile.goal, HypertrophyGoal.strength);
        expect(engine.state.sessionsIngested, 1);
        expect(engine.state.e1rmHistory['barbell_bench_press'], isNotEmpty);
        expect(engine.state.lastTopSets['barbell_bench_press'], isNotNull);
        expect(engineRepository.state?['profile']['age'], 44);
      },
    );

    test(
      'rebuilds when saved state is missing a completed app session',
      () async {
        final first = _completedSession(
          id: 'completed-session-1',
          completedAt: DateTime.utc(2026, 3, 1, 18, 0),
          exerciseId: 'barbell_back_squat',
          weightKg: 110,
        );
        final second = _completedSession(
          id: 'completed-session-2',
          completedAt: DateTime.utc(2026, 3, 2, 18, 0),
          exerciseId: 'barbell_bench_press',
          weightKg: 90,
        );
        final appState = _appStateWithCompletedSessions([first, second]);
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository(
          initialState: _savedStateForSessions([first]),
        );
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sessionsIngested, 2);
        expect(
          engine.state.ingestedSessionIds,
          equals({'completed-session-1', 'completed-session-2'}),
        );
        expect(engine.state.e1rmHistory['barbell_back_squat'], isNotEmpty);
        expect(engine.state.e1rmHistory['barbell_bench_press'], isNotEmpty);
        expect(
          engineRepository.state?['ingestedSessionIds'],
          unorderedEquals(['completed-session-1', 'completed-session-2']),
        );
      },
    );

    test(
      'rebuilds when saved state contains a completed session deleted from app history',
      () async {
        final deleted = _completedSession(
          id: 'deleted-session',
          completedAt: DateTime.utc(2026, 3, 1, 18, 0),
          exerciseId: 'barbell_back_squat',
          weightKg: 110,
        );
        final remaining = _completedSession(
          id: 'remaining-session',
          completedAt: DateTime.utc(2026, 3, 2, 18, 0),
          exerciseId: 'barbell_bench_press',
          weightKg: 90,
        );
        final appState = _appStateWithCompletedSessions([remaining]);
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository(
          initialState: _savedStateForSessions([deleted, remaining]),
        );
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sessionsIngested, 1);
        expect(engine.state.ingestedSessionIds, equals({'remaining-session'}));
        expect(engine.state.e1rmHistory['barbell_back_squat'], isNull);
        expect(engine.state.e1rmHistory['barbell_bench_press'], isNotEmpty);
      },
    );

    test('ignores timed-only legacy sessions during bootstrap', () async {
      final appState = _appStateWithTimedOnlyCompletedSession();
      final appRepository = MemoryAppStateRepository(initialState: appState);
      final engineRepository = MemoryTrainingEngineStateRepository();
      final container = _buildContainer(
        initialState: appState,
        appRepository: appRepository,
        engineRepository: engineRepository,
      );
      addTearDown(container.dispose);

      final engine = await container.read(trainingEngineProvider.future);

      expect(engine.state.sessionsIngested, 0);
      expect(engine.state.e1rmHistory, isEmpty);
      expect(engineRepository.state, isNotNull);
    });

    test(
      'falls back to app history when saved engine state cannot be restored',
      () async {
        final appState = _appStateWithCompletedSession();
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository(
          initialState: <String, dynamic>{'bad': 'snapshot'},
        );
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sessionsIngested, 1);
        expect(engine.state.e1rmHistory['barbell_back_squat'], isNotEmpty);
        expect(engineRepository.state, isNotNull);
        expect(engineRepository.state?['sessionsIngested'], 1);
      },
    );

    test(
      'falls back to app history when loading saved engine state throws',
      () async {
        final appState = _appStateWithCompletedSession();
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = _ThrowingTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sessionsIngested, 1);
        expect(engine.state.e1rmHistory['barbell_back_squat'], isNotEmpty);
      },
    );

    test(
      'does not ingest demo sleep or HRV when HealthKit returns no samples',
      () async {
        final appState = _appStateWithCompletedSession().copyWith(
          healthKitEnabled: true,
        );
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
          healthKit: const _FakeHealthKitDataSource(
            sleepStatus: HealthKitFetchStatus.noSamples,
            hrvStatus: HealthKitFetchStatus.noSamples,
          ),
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sleepHistory, isEmpty);
        expect(engine.state.hrvHistory, isEmpty);
        expect(engine.state.lastHealthKitFetch, isNotNull);
      },
    );

    test(
      'does not ingest demo sleep or HRV when HealthKit is unavailable',
      () async {
        final appState = _appStateWithCompletedSession().copyWith(
          healthKitEnabled: true,
        );
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
          healthKit: const _FakeHealthKitDataSource(
            sleepStatus: HealthKitFetchStatus.unavailable,
            hrvStatus: HealthKitFetchStatus.unavailable,
          ),
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sleepHistory, isEmpty);
        expect(engine.state.hrvHistory, isEmpty);
        expect(engine.state.lastHealthKitFetch, isNotNull);
      },
    );

    test(
      'does not ingest demo sleep or HRV when HealthKit authorization is denied',
      () async {
        final appState = _appStateWithCompletedSession().copyWith(
          healthKitEnabled: true,
        );
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
          healthKit: const _FakeHealthKitDataSource(
            sleepStatus: HealthKitFetchStatus.denied,
            hrvStatus: HealthKitFetchStatus.denied,
          ),
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sleepHistory, isEmpty);
        expect(engine.state.hrvHistory, isEmpty);
        expect(engine.state.lastHealthKitFetch, isNotNull);
      },
    );

    test(
      'does not ingest demo sleep or HRV when HealthKit fetch fails',
      () async {
        final appState = _appStateWithCompletedSession().copyWith(
          healthKitEnabled: true,
        );
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
          healthKit: const _FakeHealthKitDataSource(
            sleepStatus: HealthKitFetchStatus.error,
            hrvStatus: HealthKitFetchStatus.error,
          ),
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);

        expect(engine.state.sleepHistory, isEmpty);
        expect(engine.state.hrvHistory, isEmpty);
        expect(engine.state.lastHealthKitFetch, isNotNull);
      },
    );

    test(
      'engine debug persisted state summary is provider-backed and sorted',
      () async {
        final appState = _appStateWithCompletedSession();
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository(
          initialState: _savedEngineStateWithBenchAndSquatData(),
        );
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final summary = await container.read(
          engineDebugPersistedStateSummaryProvider.future,
        );

        expect(summary.acwrSummary, isNotEmpty);
        expect(summary.dailyLoadsCount, 1);
        expect(summary.latestDailyLoad, isNotNull);
        expect(summary.lastTopSetsCount, 2);
        expect(summary.lastTopSetRows.first.label, 'Barbell Back Squat');
        expect(summary.lastTopSetRows.last.label, 'Barbell Bench Press');
        expect(summary.e1rmHistoryCount, 2);
        expect(summary.e1rmHistoryRows.first.label, 'Barbell Back Squat');
        expect(summary.e1rmHistoryRows.last.label, 'Barbell Bench Press');
      },
    );

    test(
      'engine debug fatigue rows are sorted from highest to lowest fatigue',
      () async {
        final appState = _appStateWithCompletedSession();
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final savedEngine = TrainingEngine(
          registry: ExerciseRegistry.withDefaults(),
          profile: UserProfile(
            sex: Sex.male,
            age: 30,
            bodyWeightKg: 82,
            experience: ExperienceLevel.intermediate,
            goal: HypertrophyGoal.hypertrophy,
            availableDays: const [1, 3, 5],
            maxSessionDuration: const Duration(minutes: 60),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        savedEngine.ingestSession(
          EngineSession(
            id: 'completed-session-1',
            startedAt: DateTime.utc(2026, 3, 1, 17, 0),
            endedAt: DateTime.utc(2026, 3, 1, 18, 0),
            sets: [
              LoggedSet(
                exerciseId: 'barbell_back_squat',
                weightKg: 110,
                reps: 8,
                rpe: 8.5,
                completedAt: DateTime.utc(2026, 3, 1, 17, 10),
              ),
            ],
          ),
        );
        final engineRepository = MemoryTrainingEngineStateRepository(
          initialState: savedEngine.serializeState(),
        );
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final rows = await container.read(
          engineDebugFatigueRowsProvider.future,
        );

        expect(rows, isNotEmpty);
        expect(rows.first.value, greaterThanOrEqualTo(rows.last.value));
      },
    );

    test('engine debug recommendation rows expose row details', () async {
      final appState = _appStateWithCompletedSession();
      final appRepository = MemoryAppStateRepository(initialState: appState);
      final savedEngine = TrainingEngine(
        registry: ExerciseRegistry.withDefaults(),
        profile: UserProfile(
          sex: Sex.male,
          age: 30,
          bodyWeightKg: 82,
          experience: ExperienceLevel.intermediate,
          goal: HypertrophyGoal.hypertrophy,
          availableDays: const [1, 3, 5],
          maxSessionDuration: const Duration(minutes: 60),
          createdAt: DateTime.utc(2026, 1, 1),
        ),
      );
      savedEngine.ingestSession(
        EngineSession(
          id: 'completed-session-1',
          startedAt: DateTime.utc(2026, 3, 1, 17, 0),
          endedAt: DateTime.utc(2026, 3, 1, 18, 0),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_back_squat',
              weightKg: 110,
              reps: 8,
              rpe: 8.5,
              completedAt: DateTime.utc(2026, 3, 1, 17, 10),
            ),
            LoggedSet(
              exerciseId: 'barbell_bench_press',
              weightKg: 80,
              reps: 8,
              rpe: 8.0,
              completedAt: DateTime.utc(2026, 3, 1, 17, 20),
            ),
          ],
        ),
      );
      final engineRepository = MemoryTrainingEngineStateRepository(
        initialState: savedEngine.serializeState(),
      );
      final container = _buildContainer(
        initialState: appState,
        appRepository: appRepository,
        engineRepository: engineRepository,
      );
      addTearDown(container.dispose);

      final rows = await container.read(
        engineDebugRecommendationRowsProvider.future,
      );

      final exerciseIds = rows.map((row) => row.exerciseId).toList();

      expect(rows, hasLength(2));
      expect(
        exerciseIds,
        orderedEquals(<String>['barbell_back_squat', 'barbell_bench_press']),
      );

      final squatRow = rows.firstWhere(
        (row) => row.exerciseId == 'barbell_back_squat',
      );
      final benchRow = rows.firstWhere(
        (row) => row.exerciseId == 'barbell_bench_press',
      );

      expect(squatRow.e1rm, isNotNull);
      expect(squatRow.lastTopSet, isNotNull);
      expect(squatRow.recommendation, isA<LoadRecommendation>());
      expect(benchRow.e1rm, isNotNull);
      expect(benchRow.lastTopSet, isNotNull);
      expect(benchRow.recommendation, isA<LoadRecommendation>());
    });

    test(
      'routine load recommendations use target reps and explicit default target RPE',
      () async {
        final completedAt = DateTime.utc(2026, 4, 1, 18, 0);
        final session =
            _completedSession(
              id: 'bench-strength-session',
              completedAt: completedAt,
              exerciseId: 'barbell_bench_press',
              weightKg: 100,
            ).copyWith(
              completedSets: [
                CompletedSet(
                  exerciseId: 'barbell_bench_press',
                  setNumber: 1,
                  weightKg: 100,
                  reps: 6,
                  completedAt: completedAt,
                  note: '',
                  rpe: 8.0,
                ),
              ],
            );
        final appState = _appStateWithCompletedSessions([session]);
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final engine = await container.read(trainingEngineProvider.future);
        final defaultRecommendation = engine.recommendLoad(
          'barbell_bench_press',
          at: completedAt.add(const Duration(days: 8)),
        );
        final routineRecommendation = await container.read(
          routineLoadRecommendationProvider(
            const RoutineLoadRecommendationParams(
              exerciseId: 'barbell_bench_press',
              targetReps: 5,
            ),
          ).future,
        );

        expect(defaultRecommendation.targets.targetRepsHigh, 12);
        expect(defaultRecommendation.delta, PerformanceDelta.maintenance);
        expect(routineRecommendation, isNotNull);
        expect(routineRecommendation!.targets.targetRepsLow, 5);
        expect(routineRecommendation.targets.targetRepsHigh, 5);
        expect(routineRecommendation.targets.targetRpe, 8.0);
        expect(routineRecommendation.delta, PerformanceDelta.progression);
      },
    );

    test(
      'engine debug raw snapshot provider returns formatted serialized state',
      () async {
        final appState = _appStateWithCompletedSession();
        final appRepository = MemoryAppStateRepository(initialState: appState);
        final engineRepository = MemoryTrainingEngineStateRepository();
        final container = _buildContainer(
          initialState: appState,
          appRepository: appRepository,
          engineRepository: engineRepository,
        );
        addTearDown(container.dispose);

        final snapshot = await container.read(
          engineDebugRawSnapshotProvider.future,
        );

        expect(snapshot, contains('sessionsIngested'));
        expect(snapshot, contains('e1rmHistory'));
        expect(snapshot, contains('\n'));
        expect(snapshot, contains('  "sessionsIngested"'));
        expect(snapshot, startsWith('{\n'));
      },
    );
  });

  group('SharedPreferencesTrainingEngineStateRepository', () {
    test('persists and reloads serialized engine state', () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesTrainingEngineStateRepository(
        preferences,
      );

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
          id: 'persisted-session',
          startedAt: DateTime.utc(2026, 3, 1, 17, 0),
          endedAt: DateTime.utc(2026, 3, 1, 18, 0),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_back_squat',
              weightKg: 100,
              reps: 8,
              rpe: 8.0,
              completedAt: DateTime.utc(2026, 3, 1, 17, 15),
            ),
          ],
        ),
      );

      await repository.save(engine.serializeState());
      final restored = await repository.load();

      expect(restored, isNotNull);
      expect(restored!['sessionsIngested'], 1);
      expect(restored['e1rmHistory'], isNotEmpty);
    });
  });
}
