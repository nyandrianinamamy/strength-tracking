import 'package:test/test.dart';
import 'package:training_engine/src/progression/safety_gates.dart';
import 'package:training_engine/src/models/enums.dart';

void main() {
  group('checkSafetyGates', () {
    group('clear result', () {
      test('returns clear when all values are safe', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 40,
          acwrZone: AcwrZone.optimal,
          readinessScore: 80,
        );
        expect(result.passed, isTrue);
        expect(result.reason, isNull);
        expect(result.action, isNull);
        expect(result.modifier, equals(1.0));
      });

      test('returns clear when fatigue is exactly 60', () {
        final result = checkSafetyGates(primaryMuscleFatigue: 60);
        expect(result.passed, isTrue);
        expect(result.modifier, equals(1.0));
      });
    });

    group('fatigue gate', () {
      test('blocked with reduceLoad when fatigue is 61-80', () {
        final result = checkSafetyGates(primaryMuscleFatigue: 70);
        expect(result.passed, isFalse);
        expect(result.reason, equals(GateReason.muscleFatigue));
        expect(result.action, equals(GateAction.reduceLoad));
      });

      test('blocked with suggestAlternative when fatigue > 80', () {
        final result = checkSafetyGates(primaryMuscleFatigue: 90);
        expect(result.passed, isFalse);
        expect(result.reason, equals(GateReason.muscleFatigue));
        expect(result.action, equals(GateAction.suggestAlternative));
      });

      test('modifier calculated correctly when fatigue > 80', () {
        // fatigue=90: modifier = 1 - (90-60)/100 = 1 - 0.3 = 0.7
        final result = checkSafetyGates(primaryMuscleFatigue: 90);
        expect(result.modifier, closeTo(0.7, 0.001));
      });

      test('modifier at fatigue=100: 1 - (100-60)/100 = 0.6', () {
        final result = checkSafetyGates(primaryMuscleFatigue: 100);
        expect(result.modifier, closeTo(0.6, 0.001));
      });
    });

    group('ACWR gate', () {
      test('blocked with deload when ACWR is danger', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.danger,
        );
        expect(result.passed, isFalse);
        expect(result.reason, equals(GateReason.acwrDanger));
        expect(result.action, equals(GateAction.deload));
      });

      test('blocked with maintain when ACWR is caution', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.caution,
        );
        expect(result.passed, isFalse);
        expect(result.reason, equals(GateReason.acwrCaution));
        expect(result.action, equals(GateAction.maintain));
      });

      test('passes when ACWR is optimal', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
        );
        expect(result.passed, isTrue);
      });

      test('passes when ACWR is undertraining', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.undertraining,
        );
        expect(result.passed, isTrue);
      });
    });

    group('readiness gate', () {
      test('blocked with reduceLoad when readiness < 30', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          readinessScore: 25,
        );
        expect(result.passed, isFalse);
        expect(result.reason, equals(GateReason.lowReadiness));
        expect(result.action, equals(GateAction.reduceLoad));
      });

      test('blocked with maintain when readiness 30-49', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          readinessScore: 40,
        );
        expect(result.passed, isFalse);
        expect(result.reason, equals(GateReason.lowReadiness));
        expect(result.action, equals(GateAction.maintain));
      });

      test('dampened with modifier=0.5 when readiness 50-69', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          readinessScore: 60,
        );
        expect(result.passed, isTrue);
        expect(result.modifier, equals(0.5));
        expect(result.reason, isNull);
        expect(result.action, isNull);
      });

      test('passes when readiness >= 70', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          readinessScore: 75,
        );
        expect(result.passed, isTrue);
        expect(result.modifier, equals(1.0));
      });
    });

    group('null values are permissive', () {
      test('null acwrZone skips gate', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          acwrZone: null,
          readinessScore: 80,
        );
        expect(result.passed, isTrue);
      });

      test('null readinessScore skips gate', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.optimal,
          readinessScore: null,
        );
        expect(result.passed, isTrue);
      });

      test('all nulls with safe fatigue returns clear', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 30,
          acwrZone: null,
          readinessScore: null,
        );
        expect(result.passed, isTrue);
        expect(result.modifier, equals(1.0));
      });
    });

    group('gate ordering / short-circuit', () {
      test('fatigue gate fires before ACWR gate', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 70,
          acwrZone: AcwrZone.danger,
        );
        // Fatigue gate should fire first
        expect(result.reason, equals(GateReason.muscleFatigue));
      });

      test('ACWR gate fires before readiness gate', () {
        final result = checkSafetyGates(
          primaryMuscleFatigue: 20,
          acwrZone: AcwrZone.danger,
          readinessScore: 20,
        );
        expect(result.reason, equals(GateReason.acwrDanger));
      });
    });
  });
}
