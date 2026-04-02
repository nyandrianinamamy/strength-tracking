import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
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
    bodyGender: 'male',
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
    bodyGender: 'male',
  );
}

ProviderContainer _buildContainer({
  required AppState initialState,
  required AppStateRepository appRepository,
  required TrainingEngineStateRepository engineRepository,
}) {
  return ProviderContainer(
    overrides: [
      appStateRepositoryProvider.overrideWithValue(appRepository),
      initialAppStateProvider.overrideWithValue(initialState),
      trainingEngineStateRepositoryProvider.overrideWithValue(engineRepository),
    ],
  );
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
            id: 'saved-session',
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
            id: 'debug-fatigue-session',
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
          id: 'debug-recommendation-session',
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
