import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/workout/stale_session_service.dart';

void main() {
  const service = StaleSessionService();

  WorkoutSession buildSession({
    DateTime? startedAt,
    DateTime? lastActivityAt,
  }) {
    final start = startedAt ?? DateTime(2026, 3, 21, 9);
    return WorkoutSession(
      id: 'session_test',
      routineId: 'push_day',
      status: WorkoutSessionStatus.active,
      startedAt: start,
      endedAt: null,
      lastActivityAt: lastActivityAt,
      currentExerciseIndex: 0,
      completedSets: const [],
      sessionNote: '',
      rpe: null,
    );
  }

  test('marks a session stale after 90 minutes of inactivity', () {
    final session = buildSession(
      lastActivityAt: DateTime(2026, 3, 21, 9, 0),
    );

    expect(
      service.isStale(
        session,
        now: DateTime(2026, 3, 21, 10, 30),
      ),
      isTrue,
    );
  });

  test('uses startedAt when lastActivityAt is missing', () {
    final session = buildSession(
      startedAt: DateTime(2026, 3, 21, 9, 0),
      lastActivityAt: null,
    );

    expect(
      service.isStale(
        session,
        now: DateTime(2026, 3, 21, 10, 29, 59),
      ),
      isFalse,
    );
  });
}
