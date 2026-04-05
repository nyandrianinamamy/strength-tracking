import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

/// Creates a standard test profile.
UserProfile _profile({
  Sex sex = Sex.male,
  int age = 28,
  double bodyWeightKg = 80.0,
  ExperienceLevel experience = ExperienceLevel.intermediate,
}) =>
    UserProfile(
      sex: sex,
      age: age,
      bodyWeightKg: bodyWeightKg,
      experience: experience,
      goal: HypertrophyGoal.hypertrophy,
      availableDays: [1, 3, 5],
      maxSessionDuration: const Duration(hours: 60),
      createdAt: DateTime.utc(2026, 1, 1),
    );

TrainingEngine _engine({UserProfile? profile}) => TrainingEngine(
      registry: ExerciseRegistry.withDefaults(),
      profile: profile ?? _profile(),
    );

/// Creates a basic session with one exercise.
EngineSession _session({
  String exerciseId = 'barbell_back_squat',
  double weightKg = 100.0,
  int reps = 8,
  double rpe = 8.0,
  DateTime? endedAt,
}) {
  final ts = endedAt ?? DateTime.utc(2026, 3, 1, 18, 0);
  return EngineSession(
    id: 's1',
    startedAt: ts.subtract(const Duration(hours: 1)),
    endedAt: ts,
    sets: [
      LoggedSet(
        exerciseId: exerciseId,
        weightKg: weightKg,
        reps: reps,
        rpe: rpe,
        completedAt: ts,
      ),
      LoggedSet(
        exerciseId: exerciseId,
        weightKg: weightKg,
        reps: reps - 1,
        rpe: rpe + 0.5,
        completedAt: ts,
      ),
      LoggedSet(
        exerciseId: exerciseId,
        weightKg: weightKg,
        reps: reps - 2,
        rpe: rpe + 1.0,
        completedAt: ts,
      ),
    ],
    sessionRpe: rpe,
  );
}

void main() {
  group('TrainingEngine.ingestSession', () {
    test('updates e1RM history after ingestion', () {
      final engine = _engine();
      engine.ingestSession(_session());

      expect(engine.state.e1rmHistory['barbell_back_squat'], isNotEmpty);
      expect(
        engine.state.e1rmHistory['barbell_back_squat']!.first.value,
        greaterThan(0),
      );
    });

    test('updates lastTopSets with heaviest set', () {
      final engine = _engine();
      engine.ingestSession(_session(weightKg: 120.0));

      final topSet = engine.state.lastTopSets['barbell_back_squat'];
      expect(topSet, isNotNull);
      expect(topSet!.weightKg, closeTo(120.0, 0.001));
    });

    test('updates fatigue log for known exercise', () {
      final engine = _engine();
      engine.ingestSession(_session());

      // barbell_back_squat should activate quad/glute etc.
      expect(engine.state.fatigueLog, isNotEmpty);
    });

    test('updates ACWR EWMA state', () {
      final engine = _engine();
      engine.ingestSession(_session());

      expect(engine.state.acwrState, isNotNull);
      expect(engine.state.acwrState!.acuteEwma, greaterThan(0));
    });

    test('increments sessionsIngested', () {
      final engine = _engine();
      expect(engine.state.sessionsIngested, equals(0));

      engine.ingestSession(_session());
      expect(engine.state.sessionsIngested, equals(1));

      engine.ingestSession(_session(
        endedAt: DateTime.utc(2026, 3, 3, 18, 0),
      ));
      expect(engine.state.sessionsIngested, equals(2));
    });

    test('trims e1rmHistory to 20 per exercise', () {
      final engine = _engine();
      for (int i = 0; i < 25; i++) {
        engine.ingestSession(_session(
          endedAt: DateTime.utc(2026, 1, i + 1, 18, 0),
        ));
      }
      expect(
        engine.state.e1rmHistory['barbell_back_squat']!.length,
        lessThanOrEqualTo(20),
      );
    });

    test('trims dailyLoads to at most 36 entries (35-day window)', () {
      final engine = _engine();
      for (int i = 0; i < 40; i++) {
        engine.ingestSession(_session(
          endedAt: DateTime.utc(2026, 1, i + 1, 18, 0),
        ));
      }
      // 35-day window keeps entries from (today - 35 days) onward,
      // which is at most 36 unique days (inclusive on both ends).
      expect(engine.state.dailyLoads.length, lessThanOrEqualTo(36));
    });

    test('handles unknown exercise (no fatigue, but e1rm updated)', () {
      final engine = _engine();
      engine.ingestSession(_session(exerciseId: 'unknown_exercise_xyz'));

      // e1rm still computed
      expect(engine.state.e1rmHistory['unknown_exercise_xyz'], isNotEmpty);
      // no fatigue (exercise not in registry)
      expect(engine.state.fatigueLog, isEmpty);
    });
  });

  group('TrainingEngine.currentE1rm', () {
    test('returns baseline when no history', () {
      final engine = _engine();
      final e1rm = engine.currentE1rm('barbell_back_squat');
      // Intermediate male 80kg squat baseline: 1.25 * 80 = 100
      expect(e1rm, closeTo(100.0, 1.0));
    });

    test('returns rolling estimate after ingestion', () {
      final engine = _engine();
      engine.ingestSession(_session(weightKg: 140.0, reps: 5, rpe: 9.0));
      final e1rm = engine.currentE1rm('barbell_back_squat');
      // 5 reps @ RPE 9 should give a higher e1RM than baseline
      expect(e1rm, greaterThan(100.0));
    });

    test('falls back to baseline for unknown exercise', () {
      final engine = _engine();
      final e1rm = engine.currentE1rm('unknown_isolation_xyz');
      // isolation category baseline for intermediate male 80kg: 0.25 * 80 = 20
      expect(e1rm, greaterThan(0));
    });
  });

  group('TrainingEngine.currentFatigue', () {
    test('returns 0 with no ingested sessions', () {
      final engine = _engine();
      expect(engine.currentFatigue('quadriceps'), equals(0.0));
    });

    test('returns positive fatigue after session', () {
      final engine = _engine();
      engine.ingestSession(_session());
      final fatigue = engine.currentFatigue('quadriceps');
      // quad is primary for squat
      expect(fatigue, greaterThan(0.0));
    });

    test('fatigue decays to near zero after sufficient time', () {
      final engine = _engine();
      final sessionDate = DateTime.utc(2026, 1, 1, 18, 0);
      engine.ingestSession(_session(endedAt: sessionDate));

      // Query 30 days later — well beyond 7-day pruning window
      final farFuture = sessionDate.add(const Duration(days: 30));
      final fatigue = engine.currentFatigue('quadriceps', farFuture);
      expect(fatigue, closeTo(0.0, 1.0));
    });
  });

  group('TrainingEngine.fullFatigueMap', () {
    test('returns empty map before any ingestion', () {
      final engine = _engine();
      expect(engine.fullFatigueMap(), isEmpty);
    });

    test('returns map with muscles after ingestion', () {
      final engine = _engine();
      engine.ingestSession(_session());
      final map = engine.fullFatigueMap();
      expect(map, isNotEmpty);
      expect(map.values.every((s) => s.level >= 0 && s.level <= 100), isTrue);
    });
  });

  group('TrainingEngine.currentAcwr', () {
    test('returns null before any session', () {
      final engine = _engine();
      expect(engine.currentAcwr(), isNull);
    });

    test('returns status after first session', () {
      final engine = _engine();
      engine.ingestSession(_session());
      // After a single session with equal acute/chronic, ratio = 1.0 → optimal
      expect(engine.currentAcwr(), isNotNull);
    });
  });

  group('TrainingEngine.computeReadiness', () {
    test('cold start returns score of 50 (unavailable)', () {
      final engine = _engine();
      final readiness = engine.computeReadiness();
      expect(readiness.tier, equals(ReadinessTier.cold));
      expect(readiness.score, closeTo(50.0, 0.001));
    });

    test('ACWR-only tier after session ingestion', () {
      final engine = _engine();
      engine.ingestSession(_session());
      final readiness = engine.computeReadiness();
      // Should have at least ACWR data now
      expect(readiness.tier, isNot(equals(ReadinessTier.cold)));
    });

    test('manual slider shifts score', () {
      final engine = _engine();
      final low = engine.computeReadiness(manualSlider: 1.0);
      final high = engine.computeReadiness(manualSlider: 5.0);
      expect(high.score, greaterThan(low.score));
    });

    test('noHrv tier when sleep available', () {
      final engine = _engine();
      // Use a date within 14 days of today so scoreSleep picks it up
      final recentDate = DateTime.now().subtract(const Duration(days: 1));
      engine.ingestSession(EngineSession(
        id: 's_recent',
        startedAt: recentDate.subtract(const Duration(hours: 1)),
        endedAt: recentDate,
        sets: [
          LoggedSet(
            exerciseId: 'barbell_back_squat',
            weightKg: 100.0,
            reps: 8,
            rpe: 8.0,
            completedAt: recentDate,
          ),
        ],
        sessionRpe: 8.0,
      ));
      engine.ingestSleep(SleepRecord(
        date: recentDate,
        totalSleep: const Duration(hours: 8),
        deepSleep: const Duration(hours: 2),
        remSleep: const Duration(hours: 2),
        coreSleep: const Duration(hours: 4),
      ));
      final readiness = engine.computeReadiness();
      expect(readiness.tier, equals(ReadinessTier.noHrv));
    });
  });

  group('TrainingEngine.recommendLoad', () {
    test('returns recommendation after ingestion (3 days later, recovered)', () {
      final engine = _engine();
      final sessionDate = DateTime.utc(2026, 3, 1, 18, 0);
      engine.ingestSession(_session(
        weightKg: 100.0,
        reps: 10,
        rpe: 8.0,
        endedAt: sessionDate,
      ));

      // Query 3 days later (fatigue mostly recovered)
      final queryDate = sessionDate.add(const Duration(days: 3));
      final rec = engine.recommendLoad('barbell_back_squat', at: queryDate);

      expect(rec.exerciseId, equals('barbell_back_squat'));
      expect(rec.e1rm, isNotNull);
      expect(rec.e1rm, greaterThan(0));
      // After performing top of rep range at target RPE → expect progression
      expect(rec.suggestedWeightKg, isNotNull);
      expect(rec.suggestedWeightKg, greaterThan(0));
    });

    test('returns recommendation using custom TargetParams', () {
      final engine = _engine();
      engine.ingestSession(_session());

      final rec = engine.recommendLoad(
        'barbell_back_squat',
        overrides: const TargetParams(
          targetRepsLow: 4,
          targetRepsHigh: 6,
          targetRpe: 9.0,
        ),
      );

      expect(rec.targets.targetRepsHigh, equals(6));
      expect(rec.targets.targetRpe, equals(9.0));
    });

    test('baseline e1RM used when no ingested history', () {
      final engine = _engine();
      final rec = engine.recommendLoad('barbell_back_squat');
      // No lastTopSet, no previousWeight → null or baseline-based suggestion
      expect(rec.exerciseId, equals('barbell_back_squat'));
      expect(rec.e1rm, isNotNull);
    });
  });

  group('TrainingEngine.generatePlan', () {
    test('generates valid weekly plan for 3 days', () {
      final engine = _engine();
      final plan = engine.generatePlan(const PlannerConfig(
        availableDays: [1, 3, 5],
      ));

      expect(plan.sessions, hasLength(3));
      expect(plan.sessions.every((s) => s.exercises.isNotEmpty), isTrue);
    });

    test('split type reflects available days', () {
      final engine = _engine();
      final plan4 = engine.generatePlan(const PlannerConfig(
        availableDays: [1, 2, 4, 6],
      ));
      expect(plan4.splitType, equals(SplitType.upperLower));
    });
  });

  group('TrainingEngine state serialization', () {
    test('roundtrip preserves e1rm, fatigue, ACWR and lastTopSets', () {
      final engine = _engine();
      engine.ingestSession(_session(weightKg: 120.0, reps: 6, rpe: 8.0));

      final json = engine.serializeState();
      final engine2 = _engine();
      engine2.restoreState(json);

      expect(
        engine2.state.e1rmHistory['barbell_back_squat'],
        isNotEmpty,
      );
      expect(
        engine2.state.lastTopSets['barbell_back_squat']?.weightKg,
        closeTo(120.0, 0.001),
      );
      expect(engine2.state.acwrState, isNotNull);
      expect(engine2.state.fatigueLog, isNotEmpty);
    });

    test('sessionsIngested preserved', () {
      final engine = _engine();
      engine.ingestSession(_session());
      engine.ingestSession(_session(endedAt: DateTime.utc(2026, 3, 4, 18)));

      final json = engine.serializeState();
      final engine2 = _engine();
      engine2.restoreState(json);

      expect(engine2.state.sessionsIngested, equals(2));
    });

    test('lastHealthKitFetch survives serialization roundtrip', () {
      final engine = _engine();
      engine.stampHealthKitFetch();
      expect(engine.state.lastHealthKitFetch, isNotNull);

      final json = engine.serializeState();
      final engine2 = _engine();
      engine2.restoreState(json);

      expect(engine2.state.lastHealthKitFetch, isNotNull);
    });
  });

  group('TrainingEngine.bootstrapFromHistory', () {
    test('ingests sessions in chronological order', () {
      final engine = _engine();
      // Provide sessions out of order
      final sessions = [
        EngineSession(
          id: 's2',
          startedAt: DateTime.utc(2026, 2, 5, 9),
          endedAt: DateTime.utc(2026, 2, 5, 10),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_back_squat',
              weightKg: 110.0,
              reps: 5,
              rpe: 8.0,
              completedAt: DateTime.utc(2026, 2, 5, 10),
            ),
          ],
          sessionRpe: 8.0,
        ),
        EngineSession(
          id: 's1',
          startedAt: DateTime.utc(2026, 2, 1, 9),
          endedAt: DateTime.utc(2026, 2, 1, 10),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_back_squat',
              weightKg: 100.0,
              reps: 5,
              rpe: 8.0,
              completedAt: DateTime.utc(2026, 2, 1, 10),
            ),
          ],
          sessionRpe: 8.0,
        ),
      ];

      engine.bootstrapFromHistory(sessions);
      expect(engine.state.sessionsIngested, equals(2));
      // Last top set should be from the later session (110 kg)
      expect(
        engine.state.lastTopSets['barbell_back_squat']?.weightKg,
        closeTo(110.0, 0.001),
      );
    });

    test('backfills RPE for rpeEstimated sets from sessionRpe', () {
      final engine = _engine();
      const sessionRpe = 7.5;
      final sessions = [
        EngineSession(
          id: 's1',
          startedAt: DateTime.utc(2026, 2, 1, 9),
          endedAt: DateTime.utc(2026, 2, 1, 10),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_bench_press',
              weightKg: 80.0,
              reps: 8,
              rpe: sessionRpe, // estimated from session RPE
              completedAt: DateTime.utc(2026, 2, 1, 10),
              rpeEstimated: true,
            ),
          ],
          sessionRpe: sessionRpe,
        ),
      ];

      engine.bootstrapFromHistory(sessions);
      expect(engine.state.sessionsIngested, equals(1));
      expect(
        engine.state.e1rmHistory['barbell_bench_press'],
        isNotEmpty,
      );
    });

    test('defaults RPE to 8.0 when no sessionRpe and set is estimated', () {
      final engine = _engine();
      final sessions = [
        EngineSession(
          id: 's1',
          startedAt: DateTime.utc(2026, 2, 1, 9),
          endedAt: DateTime.utc(2026, 2, 1, 10),
          sets: [
            LoggedSet(
              exerciseId: 'barbell_bench_press',
              weightKg: 80.0,
              reps: 8,
              rpe: 8.0, // default
              completedAt: DateTime.utc(2026, 2, 1, 10),
              rpeEstimated: true,
            ),
          ],
          sessionRpe: null,
        ),
      ];

      engine.bootstrapFromHistory(sessions);
      expect(engine.state.sessionsIngested, equals(1));
    });
  });

  group('refreshHealthKitIfStale', () {
    test('fetches when lastHealthKitFetch is null', () async {
      final engine = _engine();

      var fetchCount = 0;
      Future<List<SleepRecord>> fakeSleep() async {
        fetchCount++;
        return [];
      }
      Future<List<HrvRecord>> fakeHrv() async => [];

      await engine.refreshHealthKitIfStale(
        fetchSleep: fakeSleep,
        fetchHrv: fakeHrv,
      );

      expect(fetchCount, 1);
      expect(engine.state.lastHealthKitFetch, isNotNull);
    });

    test('skips fetch when within threshold', () async {
      final engine = _engine();

      var fetchCount = 0;
      Future<List<SleepRecord>> fakeSleep() async {
        fetchCount++;
        return [];
      }
      Future<List<HrvRecord>> fakeHrv() async => [];

      // First call — should fetch
      await engine.refreshHealthKitIfStale(
        fetchSleep: fakeSleep,
        fetchHrv: fakeHrv,
      );
      expect(fetchCount, 1);

      // Second call — should skip (within 1h)
      await engine.refreshHealthKitIfStale(
        fetchSleep: fakeSleep,
        fetchHrv: fakeHrv,
      );
      expect(fetchCount, 1);
    });

    test('fetches again after threshold expires', () async {
      final engine = _engine();

      var fetchCount = 0;
      Future<List<SleepRecord>> fakeSleep() async {
        fetchCount++;
        return [];
      }
      Future<List<HrvRecord>> fakeHrv() async => [];

      // First fetch
      await engine.refreshHealthKitIfStale(
        fetchSleep: fakeSleep,
        fetchHrv: fakeHrv,
        threshold: Duration.zero, // force immediate staleness
      );
      expect(fetchCount, 1);

      // Second fetch — threshold is zero so always stale
      await engine.refreshHealthKitIfStale(
        fetchSleep: fakeSleep,
        fetchHrv: fakeHrv,
        threshold: Duration.zero,
      );
      expect(fetchCount, 2);
    });

    test('ingests fetched sleep and hrv records', () async {
      final engine = _engine();

      final sleepRecord = SleepRecord(
        date: DateTime.now(),
        totalSleep: const Duration(hours: 7),
        deepSleep: const Duration(hours: 2),
        remSleep: const Duration(hours: 1, minutes: 30),
        coreSleep: const Duration(hours: 3, minutes: 30),
      );
      final hrvRecord = HrvRecord(
        date: DateTime.now(),
        sdnn: 45.0,
      );

      await engine.refreshHealthKitIfStale(
        fetchSleep: () async => [sleepRecord],
        fetchHrv: () async => [hrvRecord],
      );

      expect(engine.state.sleepHistory, hasLength(1));
      expect(engine.state.hrvHistory, hasLength(1));
    });
  });

  group('TrainingEngine.ingestSleep and ingestHrv', () {
    test('sleep history is populated and trimmed to at most 15 entries (14-day window)', () {
      final engine = _engine();
      for (int i = 0; i < 20; i++) {
        engine.ingestSleep(SleepRecord(
          date: DateTime.utc(2026, 3, i + 1),
          totalSleep: const Duration(hours: 7),
          deepSleep: const Duration(hours: 1, minutes: 30),
          remSleep: const Duration(hours: 1, minutes: 45),
          coreSleep: const Duration(hours: 3, minutes: 45),
        ));
      }
      // 14-day window: records from (latest - 14 days) onward, inclusive on both
      // ends → at most 15 unique calendar dates.
      expect(engine.state.sleepHistory.length, lessThanOrEqualTo(15));
    });

    test('HRV history is populated and trimmed to at most 15 entries (14-day window)', () {
      final engine = _engine();
      for (int i = 0; i < 20; i++) {
        engine.ingestHrv(HrvRecord(
          date: DateTime.utc(2026, 3, i + 1),
          sdnn: 65.0 + i,
        ));
      }
      expect(engine.state.hrvHistory.length, lessThanOrEqualTo(15));
    });
  });
}
