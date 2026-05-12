import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  group('LoggedSet', () {
    final now = DateTime(2026, 1, 15, 10, 0, 0);

    test('constructs with valid RPE', () {
      final set = LoggedSet(
        exerciseId: 'squat',
        weightKg: 100.0,
        reps: 8,
        rpe: 8.0,
        completedAt: now,
      );
      expect(set.exerciseId, 'squat');
      expect(set.weightKg, 100.0);
      expect(set.reps, 8);
      expect(set.rpe, 8.0);
      expect(set.rpeEstimated, false);
    });

    test('constructs with minimum supported strength RPE', () {
      final set = LoggedSet(
        exerciseId: 'squat',
        weightKg: 100.0,
        reps: 8,
        rpe: 5.0,
        completedAt: now,
      );

      expect(set.rpe, 5.0);
    });

    test('rpeEstimated defaults to false', () {
      final set = LoggedSet(
        exerciseId: 'squat',
        weightKg: 100.0,
        reps: 8,
        rpe: 7.5,
        completedAt: now,
      );
      expect(set.rpeEstimated, false);
    });

    test('throws ArgumentError for RPE < 5', () {
      expect(
        () => LoggedSet(
          exerciseId: 'squat',
          weightKg: 100.0,
          reps: 8,
          rpe: 4.9,
          completedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('throws ArgumentError for RPE > 10', () {
      expect(
        () => LoggedSet(
          exerciseId: 'squat',
          weightKg: 100.0,
          reps: 8,
          rpe: 10.1,
          completedAt: now,
        ),
        throwsArgumentError,
      );
    });

    test('JSON roundtrip', () {
      final set = LoggedSet(
        exerciseId: 'deadlift',
        weightKg: 140.0,
        reps: 5,
        rpe: 9.0,
        completedAt: now,
        rpeEstimated: true,
      );
      final json = set.toJson();
      final restored = LoggedSet.fromJson(json);
      expect(restored.exerciseId, set.exerciseId);
      expect(restored.weightKg, set.weightKg);
      expect(restored.reps, set.reps);
      expect(restored.rpe, set.rpe);
      expect(restored.completedAt, set.completedAt);
      expect(restored.rpeEstimated, set.rpeEstimated);
    });
  });

  group('strength RPE formula contract', () {
    test('accepts the supported 5 to 10 range', () {
      expect(rirFromRpe(5.0), 5.0);
      expect(rirFromRpe(10.0), 0.0);
    });

    test('throws ArgumentError below the supported range', () {
      expect(() => rirFromRpe(4.9), throwsArgumentError);
    });

    test('throws ArgumentError above the supported range', () {
      expect(() => rirFromRpe(10.1), throwsArgumentError);
    });
  });

  group('EngineSession', () {
    final start = DateTime(2026, 1, 15, 10, 0, 0);
    final end = DateTime(2026, 1, 15, 11, 0, 0);

    late LoggedSet sampleSet;

    setUp(() {
      sampleSet = LoggedSet(
        exerciseId: 'bench',
        weightKg: 80.0,
        reps: 10,
        rpe: 7.0,
        completedAt: start,
      );
    });

    test('constructs correctly', () {
      final session = EngineSession(
        id: 'session-1',
        startedAt: start,
        endedAt: end,
        sets: [sampleSet],
        sessionRpe: 7.5,
      );
      expect(session.id, 'session-1');
      expect(session.sets.length, 1);
      expect(session.sessionRpe, 7.5);
    });

    test('sessionRpe is nullable', () {
      final session = EngineSession(
        id: 'session-2',
        startedAt: start,
        endedAt: end,
        sets: [],
        sessionRpe: null,
      );
      expect(session.sessionRpe, isNull);
    });

    test('JSON roundtrip', () {
      final session = EngineSession(
        id: 'session-1',
        startedAt: start,
        endedAt: end,
        sets: [sampleSet],
        sessionRpe: 8.0,
      );
      final json = session.toJson();
      final restored = EngineSession.fromJson(json);
      expect(restored.id, session.id);
      expect(restored.startedAt, session.startedAt);
      expect(restored.endedAt, session.endedAt);
      expect(restored.sets.length, session.sets.length);
      expect(restored.sessionRpe, session.sessionRpe);
    });
  });

  group('EngineExercise', () {
    test('constructs correctly', () {
      final exercise = EngineExercise(
        id: 'squat',
        name: 'Back Squat',
        muscleMap: [
          MuscleActivation(
            muscleId: 'quads',
            role: MuscleRole.primary,
            coefficient: 0.9,
          ),
        ],
        equipment: EquipmentClass.barbell,
        movement: MovementClass.compoundLower,
      );
      expect(exercise.id, 'squat');
      expect(exercise.name, 'Back Squat');
      expect(exercise.muscleMap.length, 1);
      expect(exercise.equipment, EquipmentClass.barbell);
      expect(exercise.movement, MovementClass.compoundLower);
    });

    test('JSON roundtrip', () {
      final exercise = EngineExercise(
        id: 'curl',
        name: 'Barbell Curl',
        muscleMap: [
          MuscleActivation(
            muscleId: 'biceps',
            role: MuscleRole.primary,
            coefficient: 1.0,
          ),
        ],
        equipment: EquipmentClass.barbell,
        movement: MovementClass.isolation,
      );
      final json = exercise.toJson();
      final restored = EngineExercise.fromJson(json);
      expect(restored.id, exercise.id);
      expect(restored.name, exercise.name);
      expect(restored.muscleMap.length, exercise.muscleMap.length);
      expect(restored.muscleMap[0].muscleId, exercise.muscleMap[0].muscleId);
      expect(restored.equipment, exercise.equipment);
      expect(restored.movement, exercise.movement);
    });
  });
}
