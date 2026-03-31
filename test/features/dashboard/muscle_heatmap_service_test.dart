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

  test('timed exercise duration is scaled to minutes so it does not dominate fatigue', () {
    final now = DateTime.now();
    final state = AppState(
      exercises: const [
        Exercise(
          id: 'bench_press',
          name: 'Bench Press',
          primaryMuscles: ['Chest'],
          secondaryMuscles: [],
          equipment: ['Barbell'],
          instructions: '',
          archived: false,
        ),
        Exercise(
          id: 'treadmill',
          name: 'Treadmill',
          exerciseType: 'timed',
          primaryMuscles: ['Quadriceps'],
          secondaryMuscles: [],
          equipment: ['Machine'],
          instructions: '',
          archived: false,
        ),
      ],
      routines: const [],
      routineGroups: const [],
      sessions: [
        WorkoutSession(
          id: 'session_mixed',
          routineId: 'full_body',
          status: WorkoutSessionStatus.completed,
          startedAt: now.subtract(const Duration(hours: 1)),
          endedAt: now,
          lastActivityAt: now,
          currentExerciseIndex: 0,
          completedSets: [
            CompletedSet(
              exerciseId: 'bench_press',
              setNumber: 1,
              weightKg: 80,
              reps: 10,
              completedAt: now.subtract(const Duration(minutes: 30)),
              note: '',
            ),
            CompletedSet(
              exerciseId: 'treadmill',
              setNumber: 1,
              weightKg: 0,
              reps: 0,
              durationSeconds: 1800, // 30 minutes
              completedAt: now.subtract(const Duration(minutes: 10)),
              note: '',
            ),
          ],
          sessionNote: '',
          rpe: null,
        ),
      ],
    );

    final fatigue = service.computeFatigue(state);

    // Bench press: 80 * 10 = 800 volume
    // Treadmill: 1800 / 60 = 30 volume (not 1800 raw seconds)
    // So chest should have higher fatigue than quadriceps
    expect(fatigue.containsKey(Muscle.chest), isTrue);
    expect(fatigue.containsKey(Muscle.quadriceps), isTrue);
    expect(fatigue[Muscle.chest]!.intensity,
        greaterThan(fatigue[Muscle.quadriceps]!.intensity));
  });
}
