import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

// Helper: build a LoggedSet for testing
LoggedSet makeSet({
  String exerciseId = 'squat',
  double weightKg = 100.0,
  int reps = 10,
  double rpe = 8.0,
}) => LoggedSet(
  exerciseId: exerciseId,
  weightKg: weightKg,
  reps: reps,
  rpe: rpe,
  completedAt: DateTime.now(),
);

// Default safe context
const _safeTargets = TargetParams(
  targetRepsLow: 6,
  targetRepsHigh: 10,
  targetRpe: 8.0,
);

void main() {
  group('buildRecommendation', () {
    // -----------------------------------------------------------------------
    // Clear gates + progression -> increased weight
    // -----------------------------------------------------------------------
    group('clear gates + progression', () {
      test('suggests increased weight and positive explanation', () {
        // lastTopSet: 10 reps @ RPE 8 -> reps >= high AND rpe <= target -> progression
        // e1rm = 150, targets 6-10 @ RPE 8, mid = 8 reps
        // predictLoad(150, 8, 8.0) = 150 / (1 + 10/30) = 112.5
        final rec = buildRecommendation(
          exerciseId: 'squat',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 150.0,
          previousWeightKg: 100.0,
          lastTopSet: makeSet(reps: 10, rpe: 8.0),
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
          readinessScore: 85,
        );

        expect(rec.delta, equals(PerformanceDelta.progression));
        expect(rec.gateResult.passed, isTrue);
        expect(rec.suggestedWeightKg, isNotNull);
        expect(rec.suggestedWeightKg!, greaterThan(100.0));
        expect(rec.explanation, contains('Great performance'));
      });

      test('suggested weight is rounded to barbell increment (2.5)', () {
        final rec = buildRecommendation(
          exerciseId: 'squat',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 150.0,
          previousWeightKg: 100.0,
          lastTopSet: makeSet(reps: 10, rpe: 8.0),
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
          readinessScore: 85,
        );

        final w = rec.suggestedWeightKg!;
        expect(w % 2.5, closeTo(0.0, 0.001));
      });
    });

    // -----------------------------------------------------------------------
    // Clear gates + maintenance -> same weight
    // -----------------------------------------------------------------------
    group('clear gates + maintenance', () {
      test('suggests same weight as previous', () {
        // 8 reps @ RPE 8 with high=10: not progression (reps < high)
        // not regression (reps >= targetRepsLow=6)
        final rec = buildRecommendation(
          exerciseId: 'bench',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 120.0,
          previousWeightKg: 80.0,
          lastTopSet: makeSet(reps: 8, rpe: 8.0),
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
          readinessScore: 85,
        );

        expect(rec.delta, equals(PerformanceDelta.maintenance));
        expect(rec.suggestedWeightKg, closeTo(80.0, 0.001));
        expect(rec.explanation, contains('Maintain'));
      });
    });

    // -----------------------------------------------------------------------
    // Blocked by fatigue -> maintenance with warning
    // -----------------------------------------------------------------------
    group('blocked by fatigue', () {
      test('fatigue 61-80 -> reduceLoad, weight reduced by 10%', () {
        final rec = buildRecommendation(
          exerciseId: 'squat',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 150.0,
          previousWeightKg: 100.0,
          lastTopSet: makeSet(reps: 10, rpe: 8.0),
          primaryMuscleFatigue: 70, // >60, <=80 -> reduceLoad
          acwrZone: AcwrZone.optimal,
          readinessScore: 85,
        );

        expect(rec.gateResult.passed, isFalse);
        expect(rec.gateResult.reason, equals(GateReason.muscleFatigue));
        expect(rec.gateResult.action, equals(GateAction.reduceLoad));
        expect(rec.explanation, contains('fatigue'));
      });
    });

    // -----------------------------------------------------------------------
    // ACWR danger -> deload to 70% of previous
    // -----------------------------------------------------------------------
    group('ACWR danger', () {
      test('deloads to 70% of previous weight', () {
        final rec = buildRecommendation(
          exerciseId: 'deadlift',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 200.0,
          previousWeightKg: 140.0,
          lastTopSet: makeSet(weightKg: 140, reps: 10, rpe: 8.0),
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.danger,
          readinessScore: 85,
        );

        expect(rec.gateResult.passed, isFalse);
        expect(rec.gateResult.reason, equals(GateReason.acwrDanger));
        expect(rec.gateResult.action, equals(GateAction.deload));
        // 140 * 0.7 = 98, rounded to 97.5
        expect(rec.suggestedWeightKg, closeTo(97.5, 0.1));
        expect(rec.explanation, contains('dangerously high'));
      });
    });

    // -----------------------------------------------------------------------
    // Dampened readiness (50-69) -> half-increment applied
    // -----------------------------------------------------------------------
    group('dampened readiness', () {
      test('applies modifier=0.5 to increment when readiness is 50-69', () {
        // progression scenario with readiness 60 -> gate.modifier = 0.5
        // predictLoad(150, 8, 8) = 112.5, previous = 100
        // increment = 12.5, dampened = 12.5 * 0.5 = 6.25
        // suggested = 100 + 6.25 = 106.25 -> rounded to 106.25 (not multiple of 2.5!)
        // Actually 106.25 / 2.5 = 42.5 -> rounds to 42 or 43?
        // 42 * 2.5 = 105, 43 * 2.5 = 107.5; 106.25 is midpoint -> Dart rounds half to even: 42*2.5=105 or 43*2.5=107.5
        // 106.25 / 2.5 = 42.5, .round() = 43 (rounds half away from zero in Dart)
        // 43 * 2.5 = 107.5
        final rec = buildRecommendation(
          exerciseId: 'squat',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 150.0,
          previousWeightKg: 100.0,
          lastTopSet: makeSet(reps: 10, rpe: 8.0),
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
          readinessScore: 60, // 50-69 -> dampened, modifier=0.5
        );

        expect(rec.gateResult.passed, isTrue);
        expect(rec.gateResult.modifier, equals(0.5));
        expect(rec.delta, equals(PerformanceDelta.progression));
        // Weight should be less than full progression prediction (112.5)
        // but more than previous (100)
        expect(rec.suggestedWeightKg!, greaterThan(100.0));
        expect(rec.suggestedWeightKg!, lessThan(112.5));
        expect(rec.explanation, contains('dampened'));
      });
    });

    // -----------------------------------------------------------------------
    // No data -> explanation says not enough data
    // -----------------------------------------------------------------------
    group('no data', () {
      test('returns null weight with not enough data explanation', () {
        final rec = buildRecommendation(
          exerciseId: 'pullup',
          equipment: EquipmentClass.bodyweight,
          targets: _safeTargets,
          e1rm: null,
          previousWeightKg: null,
          lastTopSet: null,
          primaryMuscleFatigue: 20,
          acwrZone: null,
          readinessScore: null,
        );

        expect(rec.suggestedWeightKg, isNull);
        expect(rec.explanation.toLowerCase(), contains('not enough data'));
      });

      test('null lastTopSet defaults to maintenance delta', () {
        final rec = buildRecommendation(
          exerciseId: 'bench',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: null,
          previousWeightKg: 60.0,
          lastTopSet: null, // no top set
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
          readinessScore: 85,
        );

        expect(rec.delta, equals(PerformanceDelta.maintenance));
        expect(rec.suggestedWeightKg, closeTo(60.0, 0.001));
      });
    });

    // -----------------------------------------------------------------------
    // ACWR caution -> maintain
    // -----------------------------------------------------------------------
    group('ACWR caution', () {
      test('suggests maintaining previous weight', () {
        final rec = buildRecommendation(
          exerciseId: 'squat',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 150.0,
          previousWeightKg: 100.0,
          lastTopSet: makeSet(reps: 10, rpe: 8.0),
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.caution,
          readinessScore: 85,
        );

        expect(rec.gateResult.passed, isFalse);
        expect(rec.gateResult.reason, equals(GateReason.acwrCaution));
        expect(rec.gateResult.action, equals(GateAction.maintain));
        expect(rec.suggestedWeightKg, closeTo(100.0, 0.001));
      });
    });

    // -----------------------------------------------------------------------
    // Regression -> 92% of previous weight
    // -----------------------------------------------------------------------
    group('regression', () {
      test('reduces weight by 8% on regression', () {
        // reps=4 < targetRepsLow=6, rpe=9.5 -> regression
        final rec = buildRecommendation(
          exerciseId: 'squat',
          equipment: EquipmentClass.barbell,
          targets: _safeTargets,
          e1rm: 150.0,
          previousWeightKg: 100.0,
          lastTopSet: makeSet(reps: 4, rpe: 9.5),
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
          readinessScore: 85,
        );

        expect(rec.delta, equals(PerformanceDelta.regression));
        // 100 * 0.92 = 92, rounded to 92.5 (nearest 2.5)
        expect(rec.suggestedWeightKg, closeTo(92.5, 0.1));
        expect(rec.explanation, contains('regress'));
      });
    });
  });

  group('routine target overrides', () {
    test(
      'treats seeded 5-rep strength work as progression when routine target is met',
      () {
        final engine = TrainingEngine(
          registry: ExerciseRegistry.withDefaults(),
          profile: UserProfile(
            sex: Sex.male,
            age: 32,
            bodyWeightKg: 84,
            experience: ExperienceLevel.intermediate,
            goal: HypertrophyGoal.strength,
            availableDays: const [1, 3, 5],
            maxSessionDuration: const Duration(minutes: 60),
            createdAt: DateTime.utc(2026, 1, 1),
          ),
        );
        final completedAt = DateTime.utc(2026, 5, 1, 18, 0);

        engine.ingestSession(
          EngineSession(
            id: 'seeded-strength-routine-session',
            startedAt: completedAt.subtract(const Duration(hours: 1)),
            endedAt: completedAt,
            sets: [
              LoggedSet(
                exerciseId: 'barbell_bench_press',
                weightKg: 100,
                reps: 6,
                rpe: 8.0,
                completedAt: completedAt.subtract(const Duration(minutes: 40)),
              ),
            ],
          ),
        );

        final defaultRecommendation = engine.recommendLoad(
          'barbell_bench_press',
          at: completedAt.add(const Duration(days: 8)),
        );
        final routineRecommendation = engine.recommendLoad(
          'barbell_bench_press',
          overrides: const TargetParams(
            targetRepsLow: 5,
            targetRepsHigh: 5,
            targetRpe: 8.0,
          ),
          at: completedAt.add(const Duration(days: 8)),
        );

        expect(
          defaultRecommendation.targets.targetRepsHigh,
          12,
          reason: 'Compound upper defaults should stay available.',
        );
        expect(
          defaultRecommendation.delta,
          PerformanceDelta.maintenance,
          reason: 'Six reps is below the default 8-12 progression target.',
        );
        expect(routineRecommendation.targets.targetRepsLow, 5);
        expect(routineRecommendation.targets.targetRepsHigh, 5);
        expect(routineRecommendation.targets.targetRpe, 8.0);
        expect(routineRecommendation.delta, PerformanceDelta.progression);
        expect(routineRecommendation.suggestedWeightKg, greaterThan(100));
      },
    );
  });
}
