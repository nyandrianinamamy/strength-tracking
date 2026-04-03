import 'package:test/test.dart';
import 'package:training_engine/src/e1rm/composite_estimator.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('compositeE1rm', () {
    test('100kg x 8 @ RPE 8 produces value in 125-135 range', () {
      final result = compositeE1rm(weight: 100, reps: 8, rpe: 8.0);
      expect(result, inInclusiveRange(125.0, 135.0));
    });

    test('single rep max (rMax <= 1) returns weight directly', () {
      // 1 rep @ RPE 10 => rMax = 1
      final result = compositeE1rm(weight: 100, reps: 1, rpe: 10.0);
      expect(result, 100.0);
    });

    test('heavy set (5 reps @ RPE 9, rMax=6) produces reasonable value', () {
      final result = compositeE1rm(weight: 150, reps: 5, rpe: 9.0);
      // rMax=6, should be in rMax range 1-5... actually 6 is in 6-10
      // e1RM should be above 150
      expect(result, greaterThan(150));
      expect(result, lessThan(200));
    });

    test('high-rep set (15 reps @ RPE 9, rMax=16) produces reasonable value',
        () {
      final result = compositeE1rm(weight: 80, reps: 15, rpe: 9.0);
      // rMax=16, in >15 range
      expect(result, greaterThan(80));
      expect(result, lessThan(150));
    });

    test('heavier weight produces proportionally larger e1RM', () {
      final result100 = compositeE1rm(weight: 100, reps: 8, rpe: 8.0);
      final result200 = compositeE1rm(weight: 200, reps: 8, rpe: 8.0);
      expect(result200, closeTo(result100 * 2, 1.0));
    });

    test('lower RPE (more RIR) gives higher e1RM estimate', () {
      final resultRpe8 = compositeE1rm(weight: 100, reps: 8, rpe: 8.0);
      final resultRpe10 = compositeE1rm(weight: 100, reps: 8, rpe: 10.0);
      expect(resultRpe8, greaterThan(resultRpe10));
    });
  });

  group('estimateConfidence', () {
    test('heavy set (rMax <= 5) -> high confidence 0.95', () {
      expect(estimateConfidence(3.0), 0.95);
      expect(estimateConfidence(5.0), 0.95);
    });

    test('moderate set (rMax <= 10) -> 0.80', () {
      expect(estimateConfidence(6.0), 0.80);
      expect(estimateConfidence(10.0), 0.80);
    });

    test('higher rep set (rMax <= 15) -> 0.60', () {
      expect(estimateConfidence(11.0), 0.60);
      expect(estimateConfidence(15.0), 0.60);
    });

    test('very high rep set (rMax <= 20) -> 0.40', () {
      expect(estimateConfidence(16.0), 0.40);
      expect(estimateConfidence(20.0), 0.40);
    });

    test('extreme rep count (rMax > 20) -> 0.25', () {
      expect(estimateConfidence(21.0), 0.25);
      expect(estimateConfidence(30.0), 0.25);
    });
  });

  group('rollingE1rm', () {
    final now = DateTime(2026, 1, 15, 12, 0, 0);

    E1rmEstimate makeEstimate({
      required double value,
      required int daysAgo,
      required double rMax,
      required double confidence,
      bool fromEstimatedRpe = false,
    }) {
      return E1rmEstimate(
        exerciseId: 'squat',
        value: value,
        rMax: rMax,
        confidence: confidence,
        estimatedAt: now.subtract(Duration(days: daysAgo)),
        fromEstimatedRpe: fromEstimatedRpe,
      );
    }

    test('returns null for empty list', () {
      expect(rollingE1rm([], now), isNull);
    });

    test('returns estimate value for single recent estimate', () {
      final estimates = [
        makeEstimate(value: 150.0, daysAgo: 0, rMax: 8.0, confidence: 0.80),
      ];
      final result = rollingE1rm(estimates, now);
      expect(result, isNotNull);
      // Single estimate, result should be close to the value
      expect(result!, closeTo(150.0, 1.0));
    });

    test('recent estimates weighted higher than old estimates', () {
      final recentHigh = [
        makeEstimate(value: 200.0, daysAgo: 1, rMax: 8.0, confidence: 0.80),
        makeEstimate(value: 100.0, daysAgo: 60, rMax: 8.0, confidence: 0.80),
      ];
      final recentLow = [
        makeEstimate(value: 100.0, daysAgo: 1, rMax: 8.0, confidence: 0.80),
        makeEstimate(value: 200.0, daysAgo: 60, rMax: 8.0, confidence: 0.80),
      ];

      final resultHigh = rollingE1rm(recentHigh, now)!;
      final resultLow = rollingE1rm(recentLow, now)!;

      // Recent high value should pull average up vs recent low value
      expect(resultHigh, greaterThan(resultLow));
    });

    test('legacy (fromEstimatedRpe) estimates weighted at 50%', () {
      // Same estimates but one set uses fromEstimatedRpe=true
      final withLegacy = [
        makeEstimate(
          value: 200.0,
          daysAgo: 1,
          rMax: 8.0,
          confidence: 0.80,
          fromEstimatedRpe: true, // penalty 0.5
        ),
        makeEstimate(value: 100.0, daysAgo: 1, rMax: 8.0, confidence: 0.80),
      ];
      final withoutLegacy = [
        makeEstimate(value: 200.0, daysAgo: 1, rMax: 8.0, confidence: 0.80),
        makeEstimate(value: 100.0, daysAgo: 1, rMax: 8.0, confidence: 0.80),
      ];

      final resultLegacy = rollingE1rm(withLegacy, now)!;
      final resultNormal = rollingE1rm(withoutLegacy, now)!;

      // The legacy penalty reduces the weight of the 200 estimate,
      // pulling the result closer to 100 than the normal case
      expect(resultLegacy, lessThan(resultNormal));
    });

    test('multiple estimates produce weighted average in plausible range', () {
      final estimates = [
        makeEstimate(value: 150.0, daysAgo: 0, rMax: 8.0, confidence: 0.80),
        makeEstimate(value: 145.0, daysAgo: 7, rMax: 8.0, confidence: 0.80),
        makeEstimate(value: 140.0, daysAgo: 14, rMax: 8.0, confidence: 0.80),
      ];
      final result = rollingE1rm(estimates, now)!;
      // Weighted toward recent: should be between 140 and 150, closer to 150
      expect(result, inInclusiveRange(140.0, 150.0));
      expect(result, greaterThan(144.0)); // closer to recent 150
    });
  });
}
