import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_adapter.dart';
import 'package:training_engine/training_engine.dart';

/// Standard test profile.
UserProfile _profile() => UserProfile(
      sex: Sex.male,
      age: 28,
      bodyWeightKg: 82.0,
      experience: ExperienceLevel.intermediate,
      goal: HypertrophyGoal.hypertrophy,
      availableDays: [1, 3, 5],
      maxSessionDuration: const Duration(minutes: 60),
      createdAt: DateTime.utc(2026, 1, 1),
    );

void main() {
  group('TrainingEngine integration smoke test', () {
    test('full flow: ingest session and get recommendation', () {
      // 1. Setup
      final adapter = const TrainingEngineAdapter();
      final engine = TrainingEngine(
        registry: ExerciseRegistry.withDefaults(),
        profile: _profile(),
      );

      // 2. Create a Kotrana WorkoutSession with per-set RPE
      final sessionDate = DateTime.utc(2026, 3, 1, 18, 0);
      final workoutSession = WorkoutSession(
        id: 'smoke-test-session-01',
        routineId: 'routine-ppl',
        status: WorkoutSessionStatus.completed,
        startedAt: sessionDate.subtract(const Duration(hours: 1)),
        endedAt: sessionDate,
        lastActivityAt: sessionDate,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 1,
            weightKg: 110.0,
            reps: 8,
            completedAt: sessionDate,
            note: '',
            rpe: 8.0,
          ),
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 2,
            weightKg: 110.0,
            reps: 7,
            completedAt: sessionDate,
            note: '',
            rpe: 8.5,
          ),
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 3,
            weightKg: 110.0,
            reps: 6,
            completedAt: sessionDate,
            note: '',
            rpe: 9.0,
          ),
          CompletedSet(
            exerciseId: 'barbell_bench_press',
            setNumber: 1,
            weightKg: 80.0,
            reps: 10,
            completedAt: sessionDate,
            note: '',
            rpe: 8.0,
          ),
          CompletedSet(
            exerciseId: 'barbell_bench_press',
            setNumber: 2,
            weightKg: 80.0,
            reps: 9,
            completedAt: sessionDate,
            note: '',
            rpe: 8.5,
          ),
        ],
        sessionNote: 'Good session',
        rpe: 8.0,
      );

      // 3. Map via adapter
      final engineSession = adapter.toEngineSession(workoutSession)!;
      expect(engineSession.sets, hasLength(5));
      expect(engineSession.sets.every((s) => !s.rpeEstimated), isTrue,
          reason: 'All sets have explicit RPE — none should be estimated');

      // 4. Ingest into engine
      engine.ingestSession(engineSession);

      // 5. Verify e1RM
      final squatE1rm = engine.currentE1rm('barbell_back_squat');
      expect(squatE1rm, isNotNull);
      expect(squatE1rm!, greaterThan(110.0),
          reason: 'e1RM should be higher than the working set weight');

      final benchE1rm = engine.currentE1rm('barbell_bench_press');
      expect(benchE1rm, isNotNull);
      expect(benchE1rm!, greaterThan(80.0));

      // 6. Verify fatigue map
      final fatigueMap = engine.fullFatigueMap();
      expect(fatigueMap, isNotEmpty);
      // At least quad should be fatigued after squats
      final quadFatigue = engine.currentFatigue('quad');
      expect(quadFatigue, greaterThan(0.0));

      // 7. Load recommendation 3 days later (recovered state)
      final queryDate = sessionDate.add(const Duration(days: 3));
      final squatRec = engine.recommendLoad(
        'barbell_back_squat',
        at: queryDate,
      );

      expect(squatRec.exerciseId, equals('barbell_back_squat'));
      expect(squatRec.e1rm, isNotNull);
      expect(squatRec.suggestedWeightKg, isNotNull);
      expect(squatRec.suggestedWeightKg!, greaterThan(0));
      expect(squatRec.explanation, isNotEmpty);

      // 8. Verify ACWR is present
      expect(engine.currentAcwr(), isNotNull);
    });

    test('adapter: session RPE backfilled to sets without per-set RPE', () {
      final adapter = const TrainingEngineAdapter();

      final sessionDate = DateTime.utc(2026, 3, 5, 17, 0);
      final legacySession = WorkoutSession(
        id: 'legacy-session-01',
        routineId: 'routine-fb',
        status: WorkoutSessionStatus.completed,
        startedAt: sessionDate.subtract(const Duration(minutes: 50)),
        endedAt: sessionDate,
        lastActivityAt: sessionDate,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_deadlift',
            setNumber: 1,
            weightKg: 140.0,
            reps: 5,
            completedAt: sessionDate,
            note: '',
            // No rpe field — should be backfilled from session rpe
          ),
          CompletedSet(
            exerciseId: 'barbell_deadlift',
            setNumber: 2,
            weightKg: 140.0,
            reps: 4,
            completedAt: sessionDate,
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: 7.5, // session-level RPE
      );

      final engineSession = adapter.toEngineSession(legacySession)!;

      // All sets should have RPE backfilled from session RPE
      for (final set in engineSession.sets) {
        expect(set.rpe, closeTo(7.5, 0.001));
        expect(set.rpeEstimated, isTrue);
      }
    });

    test('adapter: defaults to 8.0 when neither set nor session RPE present', () {
      final adapter = const TrainingEngineAdapter();

      final sessionDate = DateTime.utc(2026, 3, 6, 17, 0);
      final noRpeSession = WorkoutSession(
        id: 'no-rpe-session-01',
        routineId: 'routine-fb',
        status: WorkoutSessionStatus.completed,
        startedAt: sessionDate.subtract(const Duration(minutes: 45)),
        endedAt: sessionDate,
        lastActivityAt: sessionDate,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'cable_row',
            setNumber: 1,
            weightKg: 60.0,
            reps: 12,
            completedAt: sessionDate,
            note: '',
            // No rpe
          ),
        ],
        sessionNote: '',
        rpe: null, // No session RPE either
      );

      final engineSession = adapter.toEngineSession(noRpeSession)!;
      expect(engineSession.sets.first.rpe, closeTo(8.0, 0.001));
      expect(engineSession.sets.first.rpeEstimated, isTrue);
    });

    test('adapter: ignores timed sets and returns null for timed-only sessions', () {
      final adapter = const TrainingEngineAdapter();

      final sessionDate = DateTime.utc(2026, 3, 7, 17, 0);
      final timedOnlySession = WorkoutSession(
        id: 'timed-only-session-01',
        routineId: 'routine-core',
        status: WorkoutSessionStatus.completed,
        startedAt: sessionDate.subtract(const Duration(minutes: 20)),
        endedAt: sessionDate,
        lastActivityAt: sessionDate,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'plank',
            setNumber: 1,
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            completedAt: sessionDate,
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: 7.0,
      );

      expect(adapter.toEngineSession(timedOnlySession), isNull);
    });

    test('adapter: keeps strength sets when a session mixes timed and rep sets', () {
      final adapter = const TrainingEngineAdapter();

      final sessionDate = DateTime.utc(2026, 3, 8, 17, 0);
      final mixedSession = WorkoutSession(
        id: 'mixed-session-01',
        routineId: 'routine-mixed',
        status: WorkoutSessionStatus.completed,
        startedAt: sessionDate.subtract(const Duration(minutes: 45)),
        endedAt: sessionDate,
        lastActivityAt: sessionDate,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'plank',
            setNumber: 1,
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            completedAt: sessionDate,
            note: '',
          ),
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 1,
            weightKg: 100.0,
            reps: 8,
            completedAt: sessionDate,
            note: '',
            rpe: 8.0,
          ),
        ],
        sessionNote: '',
        rpe: 8.0,
      );

      final engineSession = adapter.toEngineSession(mixedSession);

      expect(engineSession, isNotNull);
      expect(engineSession!.sets, hasLength(1));
      expect(engineSession.sets.single.exerciseId, 'barbell_back_squat');
      expect(engineSession.sets.single.reps, 8);
    });

    test('engine state serialization roundtrip via restoreState', () {
      final adapter = const TrainingEngineAdapter();
      final engine = TrainingEngine(
        registry: ExerciseRegistry.withDefaults(),
        profile: _profile(),
      );

      final sessionDate = DateTime.utc(2026, 3, 1, 18, 0);
      final workoutSession = WorkoutSession(
        id: 'serialize-test-01',
        routineId: 'routine-x',
        status: WorkoutSessionStatus.completed,
        startedAt: sessionDate.subtract(const Duration(hours: 1)),
        endedAt: sessionDate,
        lastActivityAt: sessionDate,
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_back_squat',
            setNumber: 1,
            weightKg: 120.0,
            reps: 6,
            completedAt: sessionDate,
            note: '',
            rpe: 8.5,
          ),
        ],
        sessionNote: '',
        rpe: 8.5,
      );

      engine.ingestSession(adapter.toEngineSession(workoutSession)!);

      // Serialize and restore into a fresh engine
      final json = engine.serializeState();
      final engine2 = TrainingEngine(
        registry: ExerciseRegistry.withDefaults(),
        profile: _profile(),
      );
      engine2.restoreState(json);

      // Verify key data survived
      expect(
        engine2.state.e1rmHistory['barbell_back_squat'],
        isNotEmpty,
      );
      expect(
        engine2.state.lastTopSets['barbell_back_squat']?.weightKg,
        closeTo(120.0, 0.001),
      );
      expect(engine2.state.acwrState, isNotNull);
      expect(engine2.state.sessionsIngested, equals(1));
    });

    test('generatePlan returns non-empty sessions for 3-day schedule', () {
      final engine = TrainingEngine(
        registry: ExerciseRegistry.withDefaults(),
        profile: _profile(),
      );

      final plan = engine.generatePlan(const PlannerConfig(
        availableDays: [1, 3, 5],
        maxSessionDuration: Duration(minutes: 60),
        goal: HypertrophyGoal.hypertrophy,
      ));

      expect(plan.sessions, hasLength(3));
      expect(plan.sessions.every((s) => s.exercises.isNotEmpty), isTrue);
    });
  });
}
