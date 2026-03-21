import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/live_activity/workout_live_activity_service.dart';

void main() {
  group('WorkoutLiveActivityPayload', () {
    test('returns null when there is no active session', () {
      final state = DemoSeedData.initialState();

      expect(WorkoutLiveActivityPayload.fromState(state), isNull);
    });

    test('builds payload for an active strength workout with rest', () {
      final now = DateTime.now();
      final session = WorkoutSession(
        id: 'session_live',
        routineId: 'push_day',
        status: WorkoutSessionStatus.active,
        startedAt: now.subtract(const Duration(minutes: 18)),
        endedAt: null,
        lastActivityAt: now.subtract(const Duration(seconds: 20)),
        currentExerciseIndex: 1,
        completedSets: [
          CompletedSet(
            exerciseId: 'incline_dumbbell_press',
            setNumber: 1,
            weightKg: 24,
            reps: 10,
            completedAt: now.subtract(const Duration(seconds: 20)),
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: null,
      );

      final state = DemoSeedData.initialState().copyWith(sessions: [session]);
      final payload = WorkoutLiveActivityPayload.fromState(state);

      expect(payload, isNotNull);
      expect(payload!.sessionId, 'session_live');
      expect(payload.routineName, 'Push Day');
      expect(payload.currentExerciseName, 'Incline Dumbbell Press');
      expect(payload.currentExerciseProgressText, '1/3 sets');
      expect(payload.exerciseDetailText, '10 reps target');
      expect(payload.hasActiveRest, isTrue);
      expect(payload.restEndAt, isNotNull);
    });

    test('omits rest when the most recent rest window has expired', () {
      final now = DateTime.now();
      final session = WorkoutSession(
        id: 'session_live',
        routineId: 'push_day',
        status: WorkoutSessionStatus.active,
        startedAt: now.subtract(const Duration(minutes: 18)),
        endedAt: null,
        lastActivityAt: now.subtract(const Duration(minutes: 5)),
        currentExerciseIndex: 0,
        completedSets: [
          CompletedSet(
            exerciseId: 'barbell_bench_press',
            setNumber: 1,
            weightKg: 60,
            reps: 8,
            completedAt: now.subtract(const Duration(minutes: 5)),
            note: '',
          ),
        ],
        sessionNote: '',
        rpe: null,
      );

      final state = DemoSeedData.initialState().copyWith(sessions: [session]);
      final payload = WorkoutLiveActivityPayload.fromState(state);

      expect(payload, isNotNull);
      expect(payload!.hasActiveRest, isFalse);
      expect(payload.restEndAt, isNull);
      expect(payload.restSeconds, 0);
    });
  });
}
