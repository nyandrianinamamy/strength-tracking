import 'package:test/test.dart';
import 'package:training_engine/src/fatigue/muscle_registry.dart';
import 'package:training_engine/src/models/enums.dart';

void main() {
  group('decayConstantForSize', () {
    test('small muscle (36h recovery) -> tau ≈ 12.01', () {
      final tau = decayConstantForSize(MuscleSize.small);
      expect(tau, closeTo(12.01, 0.05));
    });

    test('moderate muscle (48h recovery) -> tau ≈ 16.01', () {
      final tau = decayConstantForSize(MuscleSize.moderate);
      expect(tau, closeTo(16.01, 0.05));
    });

    test('large muscle (72h recovery) -> tau ≈ 24.02', () {
      final tau = decayConstantForSize(MuscleSize.large);
      expect(tau, closeTo(24.02, 0.05));
    });
  });

  group('defaultMuscles', () {
    test('registry has at least 25 entries', () {
      expect(defaultMuscles.length, greaterThanOrEqualTo(25));
    });

    test('biceps is small with correct tau', () {
      final m = defaultMuscles['biceps']!;
      expect(m.size, MuscleSize.small);
      expect(m.decayConstant, closeTo(12.01, 0.05));
    });

    test('triceps is moderate with correct tau', () {
      final m = defaultMuscles['triceps']!;
      expect(m.size, MuscleSize.moderate);
      expect(m.decayConstant, closeTo(16.01, 0.05));
    });

    test('quadriceps is large with correct tau', () {
      final m = defaultMuscles['quadriceps']!;
      expect(m.size, MuscleSize.large);
      expect(m.decayConstant, closeTo(24.02, 0.05));
    });

    test('glutes is large', () {
      final m = defaultMuscles['glutes']!;
      expect(m.size, MuscleSize.large);
    });

    test('pectorals is large', () {
      final m = defaultMuscles['pectorals']!;
      expect(m.size, MuscleSize.large);
    });

    test('lats is large', () {
      final m = defaultMuscles['lats']!;
      expect(m.size, MuscleSize.large);
    });

    test('lateral_deltoid is small', () {
      final m = defaultMuscles['lateral_deltoid']!;
      expect(m.size, MuscleSize.small);
    });

    test('hamstrings is moderate', () {
      final m = defaultMuscles['hamstrings']!;
      expect(m.size, MuscleSize.moderate);
    });

    test('calves is small', () {
      final m = defaultMuscles['calves']!;
      expect(m.size, MuscleSize.small);
    });

    test('trapezius is moderate', () {
      final m = defaultMuscles['trapezius']!;
      expect(m.size, MuscleSize.moderate);
    });

    test('erector_spinae is large', () {
      final m = defaultMuscles['erector_spinae']!;
      expect(m.size, MuscleSize.large);
    });

    test('each muscle has displayName, id and tau matching its size', () {
      for (final entry in defaultMuscles.entries) {
        final m = entry.value;
        expect(m.id, entry.key);
        expect(m.displayName, isNotEmpty);
        expect(m.decayConstant, closeTo(decayConstantForSize(m.size), 0.001));
      }
    });
  });

  group('MuscleDefinition', () {
    test('stores all fields correctly', () {
      final m = MuscleDefinition(
        id: 'test_muscle',
        displayName: 'Test Muscle',
        size: MuscleSize.moderate,
        decayConstant: 16.01,
      );
      expect(m.id, 'test_muscle');
      expect(m.displayName, 'Test Muscle');
      expect(m.size, MuscleSize.moderate);
      expect(m.decayConstant, closeTo(16.01, 0.001));
    });
  });
}
