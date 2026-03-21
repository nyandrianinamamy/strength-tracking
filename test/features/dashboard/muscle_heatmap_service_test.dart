import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_service.dart';

void main() {
  final service = MuscleHeatmapService();

  test('computeFatigue includes logged sets from the active session', () {
    final now = DateTime.now();
    final state = AppState(
      exercises: const [
        Exercise(
          id: 'barbell_bench_press',
          name: 'Barbell Bench Press',
          primaryMuscles: ['Chest'],
          secondaryMuscles: ['Triceps'],
          equipment: ['Barbell'],
          instructions: '',
          archived: false,
        ),
      ],
      routines: const [],
      routineGroups: const [],
      sessions: [
        WorkoutSession(
          id: 'session_active',
          routineId: 'push_day',
          status: WorkoutSessionStatus.active,
          startedAt: now.subtract(const Duration(minutes: 20)),
          endedAt: null,
          lastActivityAt: now.subtract(const Duration(minutes: 1)),
          currentExerciseIndex: 1,
          completedSets: [
            CompletedSet(
              exerciseId: 'barbell_bench_press',
              setNumber: 1,
              weightKg: 60,
              reps: 8,
              completedAt: now.subtract(const Duration(minutes: 1)),
              note: '',
            ),
          ],
          sessionNote: '',
          rpe: null,
        ),
      ],
    );

    final fatigue = service.computeFatigue(state);

    expect(fatigue.containsKey(Muscle.chest), isTrue);
    expect(fatigue[Muscle.chest]!.intensity, greaterThan(0));
  });
}
