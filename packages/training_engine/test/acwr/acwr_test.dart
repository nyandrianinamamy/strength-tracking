import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart'
    show
        EngineSession,
        ExerciseRegistry,
        ExperienceLevel,
        HypertrophyGoal,
        LoggedSet,
        Sex,
        TrainingEngine,
        UserProfile;
import 'package:training_engine/src/acwr/ewma.dart';
import 'package:training_engine/src/acwr/acwr_classifier.dart';
import 'package:training_engine/src/models/enums.dart';
import 'package:training_engine/src/models/ewma_state.dart';

UserProfile _profile() => UserProfile(
  sex: Sex.male,
  age: 28,
  bodyWeightKg: 80.0,
  experience: ExperienceLevel.intermediate,
  goal: HypertrophyGoal.hypertrophy,
  availableDays: [1, 3, 5],
  maxSessionDuration: const Duration(hours: 1),
  createdAt: DateTime.utc(2026, 1, 1),
);

TrainingEngine _engine() => TrainingEngine(
  registry: ExerciseRegistry.withDefaults(),
  profile: _profile(),
);

EngineSession _session({
  required String id,
  required DateTime endedAt,
  required double weightKg,
  int reps = 10,
}) {
  return EngineSession(
    id: id,
    startedAt: endedAt.subtract(const Duration(hours: 1)),
    endedAt: endedAt,
    sets: [
      LoggedSet(
        exerciseId: 'barbell_back_squat',
        weightKg: weightKg,
        reps: reps,
        rpe: 8.0,
        completedAt: endedAt,
      ),
    ],
    sessionRpe: 8.0,
  );
}

void main() {
  final t0 = DateTime.utc(2026, 1, 1);

  // ---------------------------------------------------------------------------
  // updateEwma
  // ---------------------------------------------------------------------------
  group('updateEwma', () {
    test('first day initialises both EWMAs to todayLoad', () {
      final state = updateEwma(todayLoad: 100.0, today: t0);

      expect(state.acuteEwma, closeTo(100.0, 0.001));
      expect(state.chronicEwma, closeTo(100.0, 0.001));
      expect(state.lastComputedDate, DateTime(2026, 1, 1));
    });

    test('first day with zero load initialises both to 0', () {
      final state = updateEwma(todayLoad: 0.0, today: t0);

      expect(state.acuteEwma, 0.0);
      expect(state.chronicEwma, 0.0);
    });

    test('consecutive day applies EWMA formula', () {
      final day1 = updateEwma(todayLoad: 100.0, today: t0);
      final day2 = updateEwma(
        previous: day1,
        todayLoad: 100.0,
        today: t0.add(const Duration(days: 1)),
      );

      // acute:   0.25 * 100 + 0.75 * 100 = 100
      // chronic: 0.069 * 100 + 0.931 * 100 = 100
      expect(day2.acuteEwma, closeTo(100.0, 0.1));
      expect(day2.chronicEwma, closeTo(100.0, 0.1));
    });

    test('rest day (load=0) decays acute faster than chronic', () {
      // Seed both at 100 then apply 7 rest days
      EwmaState state = updateEwma(todayLoad: 100.0, today: t0);
      for (var i = 1; i <= 7; i++) {
        state = updateEwma(
          previous: state,
          todayLoad: 0.0,
          today: t0.add(Duration(days: i)),
        );
      }

      // Acute should decay much more than chronic after 7 rest days
      expect(state.acuteEwma, lessThan(state.chronicEwma));
    });

    test('skipped days are caught up with zero load', () {
      final day1 = updateEwma(todayLoad: 100.0, today: t0);

      // Skip directly to day 5 (days 2-4 are skipped)
      final day5Direct = updateEwma(
        previous: day1,
        todayLoad: 0.0,
        today: t0.add(const Duration(days: 4)),
      );

      // Manually walk through each day
      EwmaState manual = day1;
      for (var i = 1; i <= 3; i++) {
        manual = updateEwma(
          previous: manual,
          todayLoad: 0.0,
          today: t0.add(Duration(days: i)),
        );
      }
      manual = updateEwma(
        previous: manual,
        todayLoad: 0.0,
        today: t0.add(const Duration(days: 4)),
      );

      expect(day5Direct.acuteEwma, closeTo(manual.acuteEwma, 0.001));
      expect(day5Direct.chronicEwma, closeTo(manual.chronicEwma, 0.001));
    });

    test('lastComputedDate is normalised to local-calendar midnight', () {
      // Pass in a date with time component
      final today = DateTime.utc(2026, 3, 15, 14, 30, 59);
      final state = updateEwma(todayLoad: 50.0, today: today);

      expect(state.lastComputedDate, DateTime(2026, 3, 15));
    });

    test('same-day update (no skipped days) applies load correctly', () {
      final seed = EwmaState(
        acuteEwma: 80.0,
        chronicEwma: 80.0,
        lastComputedDate: t0,
      );
      // One day later with load 0 -> both should decay
      final next = updateEwma(
        previous: seed,
        todayLoad: 0.0,
        today: t0.add(const Duration(days: 1)),
      );

      // acute:   0.25 * 0 + 0.75 * 80 = 60
      expect(next.acuteEwma, closeTo(60.0, 0.1));
      // chronic: ~0.069 * 0 + 0.931 * 80 ≈ 74.48
      expect(next.chronicEwma, closeTo(74.48, 0.5));
    });
  });

  group('daily ACWR aggregation', () {
    test('same-day split sessions match one combined day load', () {
      final day = DateTime(2026, 3, 9, 8);

      final split = _engine()
        ..ingestSession(_session(id: 'morning', endedAt: day, weightKg: 100))
        ..ingestSession(
          _session(
            id: 'evening',
            endedAt: DateTime(2026, 3, 9, 18),
            weightKg: 80,
          ),
        );

      final combined = _engine()
        ..ingestSession(
          EngineSession(
            id: 'combined',
            startedAt: DateTime(2026, 3, 9, 7),
            endedAt: DateTime(2026, 3, 9, 18),
            sets: [
              LoggedSet(
                exerciseId: 'barbell_back_squat',
                weightKg: 100,
                reps: 10,
                rpe: 8.0,
                completedAt: DateTime(2026, 3, 9, 8),
              ),
              LoggedSet(
                exerciseId: 'barbell_back_squat',
                weightKg: 80,
                reps: 10,
                rpe: 8.0,
                completedAt: DateTime(2026, 3, 9, 18),
              ),
            ],
            sessionRpe: 8.0,
          ),
        );

      expect(split.state.dailyLoads, hasLength(1));
      expect(split.state.dailyLoads.single.volumeLoad, closeTo(1800, 0.001));
      expect(
        split.state.acwrState!.acuteEwma,
        closeTo(combined.state.acwrState!.acuteEwma, 0.001),
      );
      expect(
        split.state.acwrState!.chronicEwma,
        closeTo(combined.state.acwrState!.chronicEwma, 0.001),
      );
    });
  });

  // ---------------------------------------------------------------------------
  // classifyAcwr
  // ---------------------------------------------------------------------------
  group('classifyAcwr', () {
    AcwrStatus classify(double ratio) =>
        classifyAcwr(ratio, acuteEwma: ratio * 100.0, chronicEwma: 100.0);

    test('ratio 1.0 -> optimal zone', () {
      final status = classify(1.0);
      expect(status.zone, AcwrZone.optimal);
      expect(status.ratio, closeTo(1.0, 0.001));
    });

    test('ratio 0.5 -> undertraining zone', () {
      final status = classify(0.5);
      expect(status.zone, AcwrZone.undertraining);
    });

    test('ratio 0.80 boundary -> optimal zone', () {
      final status = classify(0.80);
      expect(status.zone, AcwrZone.optimal);
    });

    test('ratio just below 0.80 -> undertraining zone', () {
      final status = classify(0.799);
      expect(status.zone, AcwrZone.undertraining);
    });

    test('ratio 1.30 boundary -> optimal zone', () {
      final status = classify(1.30);
      expect(status.zone, AcwrZone.optimal);
    });

    test('ratio 1.4 -> caution zone', () {
      final status = classify(1.4);
      expect(status.zone, AcwrZone.caution);
    });

    test('ratio 1.50 boundary -> caution zone', () {
      final status = classify(1.50);
      expect(status.zone, AcwrZone.caution);
    });

    test('ratio 1.7 -> danger zone', () {
      final status = classify(1.7);
      expect(status.zone, AcwrZone.danger);
    });

    test('status includes acuteEwma and chronicEwma', () {
      final status = classifyAcwr(1.0, acuteEwma: 200.0, chronicEwma: 200.0);
      expect(status.acuteEwma, 200.0);
      expect(status.chronicEwma, 200.0);
    });

    test('recommendation is non-empty string', () {
      for (final ratio in [0.5, 1.0, 1.4, 1.7]) {
        final status = classify(ratio);
        expect(status.recommendation, isNotEmpty);
      }
    });
  });

  // ---------------------------------------------------------------------------
  // computeAcwr
  // ---------------------------------------------------------------------------
  group('computeAcwr', () {
    test('returns null when chronicEwma is below threshold', () {
      final state = EwmaState(
        acuteEwma: 10.0,
        chronicEwma: 0.5, // below 1.0 threshold
        lastComputedDate: t0,
      );
      expect(computeAcwr(state), isNull);
    });

    test('returns null when chronicEwma is exactly 0', () {
      final state = EwmaState(
        acuteEwma: 0.0,
        chronicEwma: 0.0,
        lastComputedDate: t0,
      );
      expect(computeAcwr(state), isNull);
    });

    test('returns AcwrStatus when chronicEwma is at or above threshold', () {
      final state = EwmaState(
        acuteEwma: 100.0,
        chronicEwma: 100.0,
        lastComputedDate: t0,
      );
      final result = computeAcwr(state);
      expect(result, isNotNull);
      expect(result!.ratio, closeTo(1.0, 0.001));
      expect(result.zone, AcwrZone.optimal);
    });

    test('ratio computed correctly from state', () {
      final state = EwmaState(
        acuteEwma: 150.0,
        chronicEwma: 100.0,
        lastComputedDate: t0,
      );
      final result = computeAcwr(state)!;
      expect(result.ratio, closeTo(1.5, 0.001));
      expect(result.zone, AcwrZone.caution);
    });

    test('chronicEwma exactly at threshold produces valid result', () {
      final state = EwmaState(
        acuteEwma: 1.0,
        chronicEwma: 1.0,
        lastComputedDate: t0,
      );
      expect(computeAcwr(state), isNotNull);
    });
  });

  // ---------------------------------------------------------------------------
  // acwrConfidence
  // ---------------------------------------------------------------------------
  group('acwrConfidence', () {
    test('0 days -> null', () => expect(acwrConfidence(0), isNull));
    test('6 days -> null', () => expect(acwrConfidence(6), isNull));
    test(
      '7 days -> low',
      () => expect(acwrConfidence(7), AcwrConfidenceLevel.low),
    );
    test(
      '14 days -> low',
      () => expect(acwrConfidence(14), AcwrConfidenceLevel.low),
    );
    test(
      '21 days -> low',
      () => expect(acwrConfidence(21), AcwrConfidenceLevel.low),
    );
    test(
      '22 days -> full',
      () => expect(acwrConfidence(22), AcwrConfidenceLevel.full),
    );
    test(
      '25 days -> full',
      () => expect(acwrConfidence(25), AcwrConfidenceLevel.full),
    );
    test(
      '90 days -> full',
      () => expect(acwrConfidence(90), AcwrConfidenceLevel.full),
    );
  });
}
