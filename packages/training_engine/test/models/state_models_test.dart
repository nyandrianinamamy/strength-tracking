import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  group('E1rmEstimate', () {
    final now = DateTime(2026, 1, 15, 10, 0, 0);

    test('constructs correctly', () {
      final estimate = E1rmEstimate(
        exerciseId: 'squat',
        value: 120.0,
        rMax: 1,
        confidence: 0.9,
        estimatedAt: now,
        fromEstimatedRpe: false,
      );
      expect(estimate.exerciseId, 'squat');
      expect(estimate.value, 120.0);
      expect(estimate.rMax, 1);
      expect(estimate.confidence, 0.9);
      expect(estimate.fromEstimatedRpe, false);
    });

    test('JSON roundtrip', () {
      final estimate = E1rmEstimate(
        exerciseId: 'deadlift',
        value: 180.0,
        rMax: 1,
        confidence: 0.85,
        estimatedAt: now,
        fromEstimatedRpe: true,
      );
      final json = estimate.toJson();
      final restored = E1rmEstimate.fromJson(json);
      expect(restored.exerciseId, estimate.exerciseId);
      expect(restored.value, estimate.value);
      expect(restored.rMax, estimate.rMax);
      expect(restored.confidence, estimate.confidence);
      expect(restored.estimatedAt, estimate.estimatedAt);
      expect(restored.fromEstimatedRpe, estimate.fromEstimatedRpe);
    });
  });

  group('FatigueImpulse', () {
    final now = DateTime(2026, 1, 15, 10, 0, 0);

    test('constructs correctly', () {
      final impulse = FatigueImpulse(
        muscleId: 'quads',
        magnitude: 75.0,
        timestamp: now,
      );
      expect(impulse.muscleId, 'quads');
      expect(impulse.magnitude, 75.0);
      expect(impulse.timestamp, now);
    });

    test('JSON roundtrip', () {
      final impulse = FatigueImpulse(
        muscleId: 'hamstrings',
        magnitude: 50.0,
        timestamp: now,
      );
      final json = impulse.toJson();
      final restored = FatigueImpulse.fromJson(json);
      expect(restored.muscleId, impulse.muscleId);
      expect(restored.magnitude, impulse.magnitude);
      expect(restored.timestamp, impulse.timestamp);
    });
  });

  group('DailyLoad', () {
    final date = DateTime(2026, 1, 15);

    test('constructs with optional sRpeLoad', () {
      final load = DailyLoad(
        date: date,
        volumeLoad: 5000.0,
        sRpeLoad: 400.0,
      );
      expect(load.date, date);
      expect(load.volumeLoad, 5000.0);
      expect(load.sRpeLoad, 400.0);
    });

    test('sRpeLoad is nullable', () {
      final load = DailyLoad(
        date: date,
        volumeLoad: 5000.0,
        sRpeLoad: null,
      );
      expect(load.sRpeLoad, isNull);
    });

    test('JSON roundtrip with sRpeLoad', () {
      final load = DailyLoad(
        date: date,
        volumeLoad: 5000.0,
        sRpeLoad: 400.0,
      );
      final json = load.toJson();
      final restored = DailyLoad.fromJson(json);
      expect(restored.date, load.date);
      expect(restored.volumeLoad, load.volumeLoad);
      expect(restored.sRpeLoad, load.sRpeLoad);
    });

    test('JSON roundtrip without sRpeLoad', () {
      final load = DailyLoad(
        date: date,
        volumeLoad: 3000.0,
        sRpeLoad: null,
      );
      final json = load.toJson();
      final restored = DailyLoad.fromJson(json);
      expect(restored.sRpeLoad, isNull);
    });
  });

  group('EwmaState', () {
    final date = DateTime(2026, 1, 15);

    test('constructs correctly', () {
      final ewma = EwmaState(
        acuteEwma: 450.0,
        chronicEwma: 400.0,
        lastComputedDate: date,
      );
      expect(ewma.acuteEwma, 450.0);
      expect(ewma.chronicEwma, 400.0);
      expect(ewma.lastComputedDate, date);
    });

    test('JSON roundtrip', () {
      final ewma = EwmaState(
        acuteEwma: 450.0,
        chronicEwma: 400.0,
        lastComputedDate: date,
      );
      final json = ewma.toJson();
      final restored = EwmaState.fromJson(json);
      expect(restored.acuteEwma, ewma.acuteEwma);
      expect(restored.chronicEwma, ewma.chronicEwma);
      expect(restored.lastComputedDate, ewma.lastComputedDate);
    });
  });
}
