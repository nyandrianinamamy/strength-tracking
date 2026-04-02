import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  group('ExerciseRegistry', () {
    late ExerciseRegistry registry;

    setUp(() {
      registry = ExerciseRegistry.withDefaults();
    });

    // -------------------------------------------------------------------------
    // Size
    // -------------------------------------------------------------------------
    test('has >= 80 exercises', () {
      expect(registry.all.length, greaterThanOrEqualTo(80));
    });

    test('empty registry has 0 exercises', () {
      expect(ExerciseRegistry.empty().all.length, equals(0));
    });

    // -------------------------------------------------------------------------
    // Bench press — muscle map
    // -------------------------------------------------------------------------
    test('barbell_bench_press has pectorals as primary', () {
      final ex = registry.lookup('barbell_bench_press');
      expect(ex, isNotNull);
      final pec = ex!.muscleMap.firstWhere(
        (m) => m.muscleId == 'pectorals',
      );
      expect(pec.role, equals(MuscleRole.primary));
      expect(pec.coefficient, equals(1.0));
    });

    test('barbell_bench_press has anterior_deltoid as synergist', () {
      final ex = registry.lookup('barbell_bench_press')!;
      final delt = ex.muscleMap.firstWhere(
        (m) => m.muscleId == 'anterior_deltoid',
      );
      expect(delt.role, equals(MuscleRole.synergist));
    });

    test('barbell_bench_press has triceps as synergist', () {
      final ex = registry.lookup('barbell_bench_press')!;
      final tri = ex.muscleMap.firstWhere(
        (m) => m.muscleId == 'triceps',
      );
      expect(tri.role, equals(MuscleRole.synergist));
    });

    test('barbell_bench_press uses barbell equipment', () {
      expect(
        registry.lookup('barbell_bench_press')!.equipment,
        equals(EquipmentClass.barbell),
      );
    });

    // -------------------------------------------------------------------------
    // Back squat
    // -------------------------------------------------------------------------
    test('barbell_back_squat is compoundLower', () {
      expect(
        registry.lookup('barbell_back_squat')!.movement,
        equals(MovementClass.compoundLower),
      );
    });

    test('barbell_back_squat has quadriceps as primary', () {
      final ex = registry.lookup('barbell_back_squat')!;
      final quad = ex.muscleMap.firstWhere((m) => m.muscleId == 'quadriceps');
      expect(quad.role, equals(MuscleRole.primary));
      expect(quad.coefficient, equals(1.0));
    });

    // -------------------------------------------------------------------------
    // exerciseById alias
    // -------------------------------------------------------------------------
    test('exerciseById is an alias for lookup', () {
      expect(
        registry.exerciseById('barbell_bench_press'),
        equals(registry.lookup('barbell_bench_press')),
      );
    });

    test('exerciseById returns null for unknown id', () {
      expect(registry.exerciseById('non_existent'), isNull);
    });

    // -------------------------------------------------------------------------
    // Custom exercises
    // -------------------------------------------------------------------------
    test('custom exercises can be added and looked up', () {
      final custom = EngineExercise(
        id: 'my_custom_exercise',
        name: 'My Custom Exercise',
        muscleMap: [
          MuscleActivation(
            muscleId: 'pectorals',
            role: MuscleRole.primary,
            coefficient: 1.0,
          ),
        ],
        equipment: EquipmentClass.cable,
        movement: MovementClass.isolation,
      );
      registry.addCustom(custom);

      expect(registry.lookup('my_custom_exercise'), equals(custom));
      expect(registry.all, contains(custom));
    });

    test('custom exercise overrides built-in with same id', () {
      final override = EngineExercise(
        id: 'barbell_bench_press',
        name: 'Custom Bench',
        muscleMap: [
          MuscleActivation(
            muscleId: 'pectorals',
            role: MuscleRole.primary,
            coefficient: 1.0,
          ),
        ],
        equipment: EquipmentClass.dumbbell,
        movement: MovementClass.isolation,
      );
      registry.addCustom(override);

      expect(registry.lookup('barbell_bench_press')!.name, equals('Custom Bench'));
    });

    // -------------------------------------------------------------------------
    // exercisesForMuscle
    // -------------------------------------------------------------------------
    test('exercisesForMuscle returns exercises targeting that muscle', () {
      final chest = registry.exercisesForMuscle('pectorals');
      expect(chest, isNotEmpty);
      expect(
        chest.every(
          (ex) => ex.muscleMap.any(
            (m) => m.muscleId == 'pectorals' && m.role == MuscleRole.primary,
          ),
        ),
        isTrue,
      );
    });

    test('exercisesForMuscle excludes specified IDs', () {
      final chest = registry.exercisesForMuscle(
        'pectorals',
        excludeIds: {'barbell_bench_press'},
      );
      expect(chest.any((ex) => ex.id == 'barbell_bench_press'), isFalse);
    });

    test('exercisesForMuscle returns lats exercises', () {
      final lats = registry.exercisesForMuscle('lats');
      expect(lats, isNotEmpty);
    });

    test('exercisesForMuscle returns quadriceps exercises', () {
      final quads = registry.exercisesForMuscle('quadriceps');
      expect(quads, isNotEmpty);
      expect(quads.any((ex) => ex.id == 'barbell_back_squat'), isTrue);
    });

    // -------------------------------------------------------------------------
    // compoundsForFocus
    // -------------------------------------------------------------------------
    test('compoundsForFocus(push) returns chest/shoulder compounds', () {
      final pushCompounds = registry.compoundsForFocus(SessionFocus.push);
      expect(pushCompounds, isNotEmpty);
      expect(
        pushCompounds.every(
          (ex) =>
              ex.movement == MovementClass.compoundUpper ||
              ex.movement == MovementClass.compoundLower,
        ),
        isTrue,
      );
      // Should include bench press
      expect(pushCompounds.any((ex) => ex.id == 'barbell_bench_press'), isTrue);
    });

    test('compoundsForFocus(pull) returns back compounds', () {
      final pullCompounds = registry.compoundsForFocus(SessionFocus.pull);
      expect(pullCompounds, isNotEmpty);
      expect(
        pullCompounds.every((ex) => ex.movement == MovementClass.compoundUpper),
        isTrue,
      );
      expect(pullCompounds.any((ex) => ex.id == 'barbell_row'), isTrue);
    });

    test('compoundsForFocus(legs) returns lower compounds', () {
      final legCompounds = registry.compoundsForFocus(SessionFocus.legs);
      expect(legCompounds, isNotEmpty);
      expect(
        legCompounds.every((ex) => ex.movement == MovementClass.compoundLower),
        isTrue,
      );
      expect(legCompounds.any((ex) => ex.id == 'barbell_back_squat'), isTrue);
    });

    test('compoundsForFocus(upper) returns only upper compounds', () {
      final upperCompounds = registry.compoundsForFocus(SessionFocus.upper);
      expect(upperCompounds, isNotEmpty);
      expect(
        upperCompounds.every((ex) => ex.movement == MovementClass.compoundUpper),
        isTrue,
      );
    });

    test('compoundsForFocus(lower) returns only lower compounds', () {
      final lowerCompounds = registry.compoundsForFocus(SessionFocus.lower);
      expect(lowerCompounds, isNotEmpty);
      expect(
        lowerCompounds.every((ex) => ex.movement == MovementClass.compoundLower),
        isTrue,
      );
    });

    test('compoundsForFocus(fullBody) returns all compounds', () {
      final fullBodyCompounds = registry.compoundsForFocus(SessionFocus.fullBody);
      expect(fullBodyCompounds, isNotEmpty);
      expect(
        fullBodyCompounds.every(
          (ex) =>
              ex.movement == MovementClass.compoundUpper ||
              ex.movement == MovementClass.compoundLower,
        ),
        isTrue,
      );
    });

    test('compoundsForFocus excludes specified IDs', () {
      final pushCompounds = registry.compoundsForFocus(
        SessionFocus.push,
        excludeIds: {'barbell_bench_press'},
      );
      expect(pushCompounds.any((ex) => ex.id == 'barbell_bench_press'), isFalse);
    });

    // -------------------------------------------------------------------------
    // substitutesFor
    // -------------------------------------------------------------------------
    test('substitutesFor returns same-primary exercises', () {
      final subs = registry.substitutesFor('barbell_bench_press');
      expect(subs, isNotEmpty);
      // All substitutes must have pectorals as primary
      expect(
        subs.every(
          (ex) => ex.muscleMap.any(
            (m) => m.muscleId == 'pectorals' && m.role == MuscleRole.primary,
          ),
        ),
        isTrue,
      );
    });

    test('substitutesFor excludes the source exercise', () {
      final subs = registry.substitutesFor('barbell_bench_press');
      expect(subs.any((ex) => ex.id == 'barbell_bench_press'), isFalse);
    });

    test('substitutesFor avoids muscles with coefficient >= 0.3', () {
      // Tricep pushdown primary = triceps; avoid triceps should remove it
      final subs = registry.substitutesFor(
        'barbell_bench_press',
        avoidMuscles: {'triceps'},
      );
      // No substitute should have triceps at coefficient >= 0.3
      for (final ex in subs) {
        final tri = ex.muscleMap.where((m) => m.muscleId == 'triceps');
        for (final m in tri) {
          expect(m.coefficient, lessThan(0.3));
        }
      }
    });

    test('substitutesFor returns empty list for unknown exercise', () {
      expect(registry.substitutesFor('nonexistent_exercise'), isEmpty);
    });
  });
}
