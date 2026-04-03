import 'package:test/test.dart';
import 'package:training_engine/src/fatigue/decay.dart';
import 'package:training_engine/src/fatigue/muscle_registry.dart';
import 'package:training_engine/src/models/enums.dart';
import 'package:training_engine/src/models/fatigue_impulse.dart';

void main() {
  // Pre-compute tau values for reference
  final tauSmall = decayConstantForSize(MuscleSize.small);    // ~12.01
  final tauModerate = decayConstantForSize(MuscleSize.moderate); // ~16.01
  final tauLarge = decayConstantForSize(MuscleSize.large);     // ~24.02

  final t0 = DateTime.utc(2026, 1, 1, 0);

  group('decayedFatigue', () {
    test('magnitude 100 at t=0 returns 100', () {
      expect(decayedFatigue(magnitude: 100, hoursElapsed: 0, tau: tauLarge), closeTo(100.0, 0.001));
    });

    test('small muscle at 36h -> ~5%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 36, tau: tauSmall);
      expect(result, closeTo(5.0, 0.5));
    });

    test('moderate muscle at 48h -> ~5%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 48, tau: tauModerate);
      expect(result, closeTo(5.0, 0.5));
    });

    test('large muscle at 72h -> ~5%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 72, tau: tauLarge);
      expect(result, closeTo(5.0, 0.5));
    });

    // Paper Table 2: large muscle decay checkpoints (using tau_large ~24.02)
    test('Paper Table 2: large muscle at 12h -> ~60.7%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 12, tau: tauLarge);
      expect(result, closeTo(60.7, 1.0));
    });

    test('Paper Table 2: large muscle at 24h -> ~36.8%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 24, tau: tauLarge);
      expect(result, closeTo(36.8, 1.0));
    });

    test('Paper Table 2: large muscle at 48h -> ~13.5%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 48, tau: tauLarge);
      expect(result, closeTo(13.5, 1.0));
    });

    test('decays monotonically with time', () {
      final t1 = decayedFatigue(magnitude: 100, hoursElapsed: 10, tau: tauLarge);
      final t2 = decayedFatigue(magnitude: 100, hoursElapsed: 20, tau: tauLarge);
      final t3 = decayedFatigue(magnitude: 100, hoursElapsed: 40, tau: tauLarge);
      expect(t1, greaterThan(t2));
      expect(t2, greaterThan(t3));
    });
  });

  group('ageRecoveryModifier', () {
    test('age 25 -> 1.0', () => expect(ageRecoveryModifier(25), 1.0));
    test('age 30 -> 1.0', () => expect(ageRecoveryModifier(30), 1.0));
    test('age 35 -> 1.10', () => expect(ageRecoveryModifier(35), 1.10));
    test('age 40 -> 1.10', () => expect(ageRecoveryModifier(40), 1.10));
    test('age 45 -> 1.25', () => expect(ageRecoveryModifier(45), 1.25));
    test('age 50 -> 1.25', () => expect(ageRecoveryModifier(50), 1.25));
    test('age 55 -> 1.40', () => expect(ageRecoveryModifier(55), 1.40));
    test('age 70 -> 1.40', () => expect(ageRecoveryModifier(70), 1.40));
  });

  group('currentFatigue', () {
    test('single impulse decays over time', () {
      final impulses = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 100.0, timestamp: t0),
      ];
      final now24h = t0.add(const Duration(hours: 24));
      final result = currentFatigue('quadriceps', impulses, now24h);
      // Large muscle, 24h elapsed -> ~36.8
      expect(result, closeTo(36.8, 2.0));
    });

    test('two impulses superimpose correctly', () {
      final impulses = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 50.0, timestamp: t0),
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 50.0, timestamp: t0),
      ];
      // Should be ~double a single impulse
      final singleImpulse = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 50.0, timestamp: t0),
      ];
      final now12h = t0.add(const Duration(hours: 12));
      final combined = currentFatigue('quadriceps', impulses, now12h);
      final single = currentFatigue('quadriceps', singleImpulse, now12h);
      expect(combined, closeTo(single * 2, 0.1));
    });

    test('capped at 100 when sum would exceed', () {
      final impulses = List.generate(
        5,
        (_) => FatigueImpulse(muscleId: 'quadriceps', magnitude: 100.0, timestamp: t0),
      );
      final result = currentFatigue('quadriceps', impulses, t0);
      expect(result, 100.0);
    });

    test('ignores impulses for other muscles', () {
      final impulses = [
        FatigueImpulse(muscleId: 'glutes', magnitude: 100.0, timestamp: t0),
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 50.0, timestamp: t0),
      ];
      final result = currentFatigue('quadriceps', impulses, t0);
      expect(result, closeTo(50.0, 0.01));
    });

    test('returns 0 when no impulses for muscle', () {
      final impulses = [
        FatigueImpulse(muscleId: 'glutes', magnitude: 100.0, timestamp: t0),
      ];
      final result = currentFatigue('quadriceps', impulses, t0);
      expect(result, 0.0);
    });

    test('age modifier slows recovery (older -> higher fatigue at same time)', () {
      final impulses = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 100.0, timestamp: t0),
      ];
      final now24h = t0.add(const Duration(hours: 24));
      final young = currentFatigue('quadriceps', impulses, now24h, age: 25);
      final old = currentFatigue('quadriceps', impulses, now24h, age: 55);
      expect(old, greaterThan(young));
    });

    test('unknown muscle falls back to moderate tau', () {
      final impulses = [
        FatigueImpulse(muscleId: 'unknown_muscle', magnitude: 100.0, timestamp: t0),
      ];
      final now = t0.add(const Duration(hours: 24));
      // Should not throw, just returns a decayed value
      final result = currentFatigue('unknown_muscle', impulses, now);
      expect(result, greaterThan(0.0));
      expect(result, lessThanOrEqualTo(100.0));
    });
  });

  group('FatigueStatus', () {
    test('level 80 -> acute phase', () {
      final status = FatigueStatus(level: 80.0);
      expect(status.phase, RecoveryPhase.acute);
    });

    test('level 30 -> recovering phase', () {
      final status = FatigueStatus(level: 30.0);
      expect(status.phase, RecoveryPhase.recovering);
    });

    test('level 3 -> ready phase', () {
      final status = FatigueStatus(level: 3.0);
      expect(status.phase, RecoveryPhase.ready);
    });

    test('hue = 120 * (1 - level/100)', () {
      final status = FatigueStatus(level: 50.0);
      expect(status.hue, closeTo(60.0, 0.001)); // 120 * 0.5
    });

    test('hue is 0 at level 100', () {
      final status = FatigueStatus(level: 100.0);
      expect(status.hue, closeTo(0.0, 0.001));
    });

    test('hue is 120 at level 0', () {
      final status = FatigueStatus(level: 0.0);
      expect(status.hue, closeTo(120.0, 0.001));
    });

    test('estimatedFullRecovery is positive for high fatigue', () {
      final status = FatigueStatus(level: 80.0);
      expect(status.estimatedFullRecovery.inHours, greaterThan(0));
    });

    test('estimatedFullRecovery is zero-ish for ready muscle', () {
      final status = FatigueStatus(level: 2.0);
      expect(status.estimatedFullRecovery, Duration.zero);
    });
  });

  group('fullFatigueMap', () {
    test('returns FatigueStatus for each muscle with impulses', () {
      final impulseLog = {
        'quadriceps': [
          FatigueImpulse(muscleId: 'quadriceps', magnitude: 80.0, timestamp: t0),
        ],
        'glutes': [
          FatigueImpulse(muscleId: 'glutes', magnitude: 30.0, timestamp: t0),
        ],
      };
      final map = fullFatigueMap(impulseLog, t0);
      expect(map.keys, containsAll(['quadriceps', 'glutes']));
    });

    test('acute phase for high magnitude at t=0', () {
      final impulseLog = {
        'quadriceps': [
          FatigueImpulse(muscleId: 'quadriceps', magnitude: 80.0, timestamp: t0),
        ],
      };
      final map = fullFatigueMap(impulseLog, t0);
      expect(map['quadriceps']!.phase, RecoveryPhase.acute);
    });

    test('ready phase for fully decayed muscle', () {
      final impulseLog = {
        'quadriceps': [
          FatigueImpulse(
            muscleId: 'quadriceps',
            magnitude: 10.0,
            timestamp: t0.subtract(const Duration(days: 10)),
          ),
        ],
      };
      final map = fullFatigueMap(impulseLog, t0);
      expect(map['quadriceps']!.phase, RecoveryPhase.ready);
    });

    test('recovering phase for mid-range fatigue', () {
      // ~36h after large muscle impulse: ~5% but with magnitude 90 -> still recovering
      final impulseLog = {
        'quadriceps': [
          FatigueImpulse(
            muscleId: 'quadriceps',
            magnitude: 90.0,
            timestamp: t0.subtract(const Duration(hours: 48)),
          ),
        ],
      };
      final map = fullFatigueMap(impulseLog, t0);
      // 90 * exp(-48/24.02) = 90 * 0.135 = ~12.2 -> recovering (5-60)
      expect(map['quadriceps']!.phase, RecoveryPhase.recovering);
    });
  });

  group('pruneOldImpulses', () {
    test('removes impulses older than 7 days', () {
      final old = FatigueImpulse(
        muscleId: 'quadriceps',
        magnitude: 80.0,
        timestamp: t0.subtract(const Duration(days: 8)),
      );
      final recent = FatigueImpulse(
        muscleId: 'quadriceps',
        magnitude: 50.0,
        timestamp: t0.subtract(const Duration(days: 3)),
      );
      final result = pruneOldImpulses([old, recent], t0);
      expect(result.length, 1);
      expect(result.first.magnitude, 50.0);
    });

    test('keeps impulses exactly at 7 days boundary', () {
      final boundary = FatigueImpulse(
        muscleId: 'quadriceps',
        magnitude: 50.0,
        timestamp: t0.subtract(const Duration(days: 7)),
      );
      final result = pruneOldImpulses([boundary], t0);
      expect(result.length, 1);
    });

    test('removes impulse just past 7 days', () {
      final tooOld = FatigueImpulse(
        muscleId: 'quadriceps',
        magnitude: 50.0,
        timestamp: t0.subtract(const Duration(days: 7, seconds: 1)),
      );
      final result = pruneOldImpulses([tooOld], t0);
      expect(result.length, 0);
    });

    test('returns empty list when all impulses are old', () {
      final impulses = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 80.0,
            timestamp: t0.subtract(const Duration(days: 10))),
        FatigueImpulse(muscleId: 'glutes', magnitude: 60.0,
            timestamp: t0.subtract(const Duration(days: 9))),
      ];
      expect(pruneOldImpulses(impulses, t0), isEmpty);
    });
  });
}
