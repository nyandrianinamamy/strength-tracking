import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

void main() {
  final startedAt = DateTime(2026, 4, 8, 9, 0);

  WorkoutSession _baseSession() => WorkoutSession(
        id: 'session1',
        routineId: 'routine1',
        status: WorkoutSessionStatus.active,
        startedAt: startedAt,
        endedAt: null,
        lastActivityAt: null,
        currentExerciseIndex: 0,
        completedSets: const [],
        sessionNote: '',
        rpe: null,
      );

  const sampleOverride = RoutineExercise(
    exerciseId: 'ex2',
    targetSets: 3,
    targetReps: 10,
    restSeconds: 90,
    order: 0,
  );

  group('WorkoutSession.exerciseOverrides', () {
    test('default is null', () {
      final session = _baseSession();
      expect(session.exerciseOverrides, isNull);
    });

    test('copyWith preserves exerciseOverrides when not specified', () {
      final session = _baseSession().copyWith(
        exerciseOverrides: [sampleOverride],
      );
      final updated = session.copyWith(sessionNote: 'updated note');
      expect(updated.exerciseOverrides, [sampleOverride]);
    });

    test('copyWith sets exerciseOverrides', () {
      final session = _baseSession();
      final updated = session.copyWith(exerciseOverrides: [sampleOverride]);
      expect(updated.exerciseOverrides, [sampleOverride]);
    });

    test('copyWith clearExerciseOverrides resets to null', () {
      final session = _baseSession().copyWith(
        exerciseOverrides: [sampleOverride],
      );
      final cleared = session.copyWith(clearExerciseOverrides: true);
      expect(cleared.exerciseOverrides, isNull);
    });

    test('toJson includes exerciseOverrides when set', () {
      final session = _baseSession().copyWith(
        exerciseOverrides: [sampleOverride],
      );
      final json = session.toJson();
      expect(json['exerciseOverrides'], isNotNull);
      expect(json['exerciseOverrides'], isA<List>());
      expect((json['exerciseOverrides'] as List).length, 1);
      expect(
        (json['exerciseOverrides'] as List)[0],
        sampleOverride.toJson(),
      );
    });

    test('toJson omits exerciseOverrides when null', () {
      final session = _baseSession();
      final json = session.toJson();
      expect(json.containsKey('exerciseOverrides'), isFalse);
    });

    test('fromJson round-trips exerciseOverrides', () {
      final session = _baseSession().copyWith(
        exerciseOverrides: [sampleOverride],
      );
      final json = session.toJson();
      final restored = WorkoutSession.fromJson(json);
      expect(restored.exerciseOverrides, isNotNull);
      expect(restored.exerciseOverrides!.length, 1);
      expect(restored.exerciseOverrides![0].exerciseId, 'ex2');
      expect(restored.exerciseOverrides![0].targetSets, 3);
      expect(restored.exerciseOverrides![0].order, 0);
    });

    test('fromJson defaults to null when field absent', () {
      final json = {
        'id': 'session1',
        'routineId': 'routine1',
        'status': 'active',
        'startedAt': startedAt.toIso8601String(),
        'currentExerciseIndex': 0,
        'completedSets': <dynamic>[],
        'sessionNote': '',
      };
      final session = WorkoutSession.fromJson(json);
      expect(session.exerciseOverrides, isNull);
    });
  });
}
