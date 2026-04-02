import 'package:test/test.dart';
import 'package:training_engine/src/progression/performance_delta.dart';
import 'package:training_engine/src/progression/load_predictor.dart';
import 'package:training_engine/src/progression/equipment_rounding.dart';
import 'package:training_engine/src/models/enums.dart';

void main() {
  // ---------------------------------------------------------------------------
  // evaluateDelta
  // ---------------------------------------------------------------------------
  group('evaluateDelta', () {
    test('returns progression when reps >= targetRepsHigh and rpe <= targetRpe', () {
      final delta = evaluateDelta(
        reps: 10,
        rpe: 8.0,
        targetRepsHigh: 10,
        targetRpe: 8.0,
      );
      expect(delta, equals(PerformanceDelta.progression));
    });

    test('returns progression when reps exceed targetRepsHigh and rpe is low', () {
      final delta = evaluateDelta(
        reps: 12,
        rpe: 7.5,
        targetRepsHigh: 10,
        targetRpe: 8.0,
      );
      expect(delta, equals(PerformanceDelta.progression));
    });

    test('returns maintenance when reps meet high but rpe is too high', () {
      final delta = evaluateDelta(
        reps: 10,
        rpe: 9.0,
        targetRepsHigh: 10,
        targetRpe: 8.0,
      );
      expect(delta, equals(PerformanceDelta.maintenance));
    });

    test('returns maintenance when reps just below high and rpe acceptable', () {
      final delta = evaluateDelta(
        reps: 8,
        rpe: 8.0,
        targetRepsHigh: 10,
        targetRpe: 8.0,
        targetRepsLow: 6,
      );
      expect(delta, equals(PerformanceDelta.maintenance));
    });

    test('returns regression when reps < targetRepsLow and rpe >= 9.5', () {
      final delta = evaluateDelta(
        reps: 5,
        rpe: 9.5,
        targetRepsHigh: 10,
        targetRpe: 8.0,
        targetRepsLow: 6,
      );
      expect(delta, equals(PerformanceDelta.regression));
    });

    test('returns regression when reps < (targetRepsHigh - 4) and rpe >= 9.5 (no low provided)', () {
      final delta = evaluateDelta(
        reps: 5,
        rpe: 9.5,
        targetRepsHigh: 10,
        targetRpe: 8.0,
      );
      // targetRepsLow defaults to 10 - 4 = 6, reps=5 < 6 and rpe=9.5
      expect(delta, equals(PerformanceDelta.regression));
    });

    test('returns maintenance when rpe < 9.5 despite low reps', () {
      final delta = evaluateDelta(
        reps: 5,
        rpe: 9.0,
        targetRepsHigh: 10,
        targetRpe: 8.0,
        targetRepsLow: 6,
      );
      expect(delta, equals(PerformanceDelta.maintenance));
    });
  });

  // ---------------------------------------------------------------------------
  // predictLoad
  // ---------------------------------------------------------------------------
  group('predictLoad', () {
    test('paper example: e1RM=150, 8 @ RPE8 -> ~112.5', () {
      // targetRMax = 8 + (10 - 8) = 10
      // weight = 150 / (1 + 10/30) = 150 / 1.3333 = 112.5
      final load = predictLoad(e1rm: 150, targetReps: 8, targetRpe: 8.0);
      expect(load, closeTo(112.5, 0.1));
    });

    test('e1RM=200, 5 @ RPE 9 -> targetRMax=6, weight=200/1.2=166.67', () {
      // targetRMax = 5 + (10 - 9) = 6
      // weight = 200 / (1 + 6/30) = 200 / 1.2 = 166.67
      final load = predictLoad(e1rm: 200, targetReps: 5, targetRpe: 9.0);
      expect(load, closeTo(166.67, 0.1));
    });

    test('e1RM=100, 12 @ RPE 8.5 -> targetRMax=13.5, weight=100/1.45=68.97', () {
      // targetRMax = 12 + (10 - 8.5) = 13.5
      // weight = 100 / (1 + 13.5/30) = 100 / 1.45 = 68.97
      final load = predictLoad(e1rm: 100, targetReps: 12, targetRpe: 8.5);
      expect(load, closeTo(68.97, 0.1));
    });
  });

  // ---------------------------------------------------------------------------
  // roundToEquipment
  // ---------------------------------------------------------------------------
  group('roundToEquipment', () {
    group('barbell (2.5 kg increments)', () {
      test('112.3 -> 112.5', () {
        expect(roundToEquipment(112.3, EquipmentClass.barbell), closeTo(112.5, 0.001));
      });

      test('113.7 -> 112.5 (nearest 2.5)', () {
        // 113.7 / 2.5 = 45.48, rounds to 45, 45 * 2.5 = 112.5
        expect(roundToEquipment(113.7, EquipmentClass.barbell), closeTo(112.5, 0.001));
      });

      test('113.8 -> 115.0 (nearest 2.5)', () {
        // 113.8 / 2.5 = 45.52, rounds to 46, 46 * 2.5 = 115.0
        expect(roundToEquipment(113.8, EquipmentClass.barbell), closeTo(115.0, 0.001));
      });

      test('100.0 stays at 100.0', () {
        expect(roundToEquipment(100.0, EquipmentClass.barbell), closeTo(100.0, 0.001));
      });
    });

    group('dumbbell (2.0 kg increments)', () {
      test('23.3 -> 24.0', () {
        expect(roundToEquipment(23.3, EquipmentClass.dumbbell), closeTo(24.0, 0.001));
      });

      test('22.9 -> 22.0', () {
        expect(roundToEquipment(22.9, EquipmentClass.dumbbell), closeTo(22.0, 0.001));
      });
    });

    group('cable (2.5 kg increments)', () {
      test('47.6 -> 47.5', () {
        expect(roundToEquipment(47.6, EquipmentClass.cable), closeTo(47.5, 0.001));
      });
    });

    group('machine (5.0 kg increments)', () {
      test('47 -> 45.0', () {
        expect(roundToEquipment(47.0, EquipmentClass.machine), closeTo(45.0, 0.001));
      });

      test('48 -> 50.0', () {
        expect(roundToEquipment(48.0, EquipmentClass.machine), closeTo(50.0, 0.001));
      });
    });

    group('bodyweight (no rounding)', () {
      test('returns weight as-is', () {
        expect(roundToEquipment(73.4, EquipmentClass.bodyweight), equals(73.4));
      });
    });
  });

  // ---------------------------------------------------------------------------
  // TargetParams.defaultFor
  // ---------------------------------------------------------------------------
  group('TargetParams.defaultFor', () {
    test('compoundLower: 6-10 @ RPE 8.0', () {
      final params = TargetParams.defaultFor(MovementClass.compoundLower);
      expect(params.targetRepsLow, equals(6));
      expect(params.targetRepsHigh, equals(10));
      expect(params.targetRpe, equals(8.0));
    });

    test('compoundUpper: 8-12 @ RPE 8.0', () {
      final params = TargetParams.defaultFor(MovementClass.compoundUpper);
      expect(params.targetRepsLow, equals(8));
      expect(params.targetRepsHigh, equals(12));
      expect(params.targetRpe, equals(8.0));
    });

    test('isolation: 10-15 @ RPE 8.5', () {
      final params = TargetParams.defaultFor(MovementClass.isolation);
      expect(params.targetRepsLow, equals(10));
      expect(params.targetRepsHigh, equals(15));
      expect(params.targetRpe, equals(8.5));
    });
  });
}
