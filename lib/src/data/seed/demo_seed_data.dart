import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

class DemoSeedData {
  static AppState initialState() {
    final exercises = <Exercise>[
      const Exercise(
        id: 'bench_press',
        name: 'Barbell Bench Press',
        primaryMuscles: ['Chest', 'Triceps'],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Plant your feet, retract your shoulder blades, and drive the bar in a straight line over your chest.',
        archived: false,
      ),
      const Exercise(
        id: 'incline_db_press',
        name: 'Incline Dumbbell Press',
        primaryMuscles: ['Chest', 'Shoulders'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Keep your wrists stacked over elbows and lower the dumbbells until your upper arms are slightly below parallel.',
        archived: false,
      ),
      const Exercise(
        id: 'pull_up',
        name: 'Pull Up',
        primaryMuscles: ['Back', 'Biceps'],
        equipment: ['Pull-Up Bar'],
        instructions:
            'Start from a dead hang, brace your core, and pull your chest toward the bar without kipping.',
        archived: false,
      ),
      const Exercise(
        id: 'barbell_row',
        name: 'Barbell Row',
        primaryMuscles: ['Back', 'Rear Delts'],
        equipment: ['Barbell'],
        instructions:
            'Hinge to a strong torso position and row the bar toward your lower ribs without jerking.',
        archived: false,
      ),
      const Exercise(
        id: 'back_squat',
        name: 'Barbell Back Squat',
        primaryMuscles: ['Legs', 'Glutes'],
        equipment: ['Barbell', 'Rack'],
        instructions:
            'Brace hard, sit between your hips, and keep the bar balanced over your midfoot.',
        archived: false,
      ),
      const Exercise(
        id: 'leg_press',
        name: 'Leg Press',
        primaryMuscles: ['Legs'],
        equipment: ['Machine'],
        instructions:
            'Control the eccentric, keep your lower back planted, and press through the middle of your foot.',
        archived: false,
      ),
      const Exercise(
        id: 'deadlift',
        name: 'Conventional Deadlift',
        primaryMuscles: ['Back', 'Glutes', 'Hamstrings'],
        equipment: ['Barbell'],
        instructions:
            'Pull the slack out of the bar, drive through the floor, and finish by squeezing your glutes.',
        archived: false,
      ),
      const Exercise(
        id: 'shoulder_press',
        name: 'Seated Dumbbell Shoulder Press',
        primaryMuscles: ['Shoulders', 'Triceps'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Keep your ribs down and press the dumbbells in a slight arc toward the midline.',
        archived: false,
      ),
      const Exercise(
        id: 'plank',
        name: 'Weighted Plank',
        primaryMuscles: ['Abs', 'Core'],
        equipment: ['Plate'],
        instructions:
            'Keep a straight line from shoulders to heels and breathe behind the brace.',
        archived: false,
      ),
      const Exercise(
        id: 'cable_fly',
        name: 'Cable Fly',
        primaryMuscles: ['Chest'],
        equipment: ['Cable Machine'],
        instructions:
            'Slight bend in the elbows, bring hands together in an arc, and pause at peak contraction.',
        archived: false,
      ),
    ];

    final routines = <Routine>[
      const Routine(
        id: 'push_a',
        name: 'Push Day (A)',
        category: 'Hypertrophy',
        estimatedDurationMin: 65,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'bench_press',
            targetSets: 4,
            targetReps: 6,
            restSeconds: 120,
            order: 0,
          ),
          RoutineExercise(
            exerciseId: 'incline_db_press',
            targetSets: 3,
            targetReps: 10,
            restSeconds: 90,
            order: 1,
          ),
          RoutineExercise(
            exerciseId: 'shoulder_press',
            targetSets: 3,
            targetReps: 10,
            restSeconds: 75,
            order: 2,
          ),
          RoutineExercise(
            exerciseId: 'cable_fly',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 60,
            order: 3,
          ),
        ],
      ),
      const Routine(
        id: 'pull_a',
        name: 'Pull Day (A)',
        category: 'Strength',
        estimatedDurationMin: 55,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'deadlift',
            targetSets: 3,
            targetReps: 5,
            restSeconds: 150,
            order: 0,
          ),
          RoutineExercise(
            exerciseId: 'pull_up',
            targetSets: 4,
            targetReps: 8,
            restSeconds: 90,
            order: 1,
          ),
          RoutineExercise(
            exerciseId: 'barbell_row',
            targetSets: 4,
            targetReps: 8,
            restSeconds: 90,
            order: 2,
          ),
        ],
      ),
      const Routine(
        id: 'leg_b',
        name: 'Leg Day (B)',
        category: 'Strength',
        estimatedDurationMin: 70,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'back_squat',
            targetSets: 4,
            targetReps: 5,
            restSeconds: 150,
            order: 0,
          ),
          RoutineExercise(
            exerciseId: 'leg_press',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 90,
            order: 1,
          ),
          RoutineExercise(
            exerciseId: 'plank',
            targetSets: 3,
            targetReps: 1,
            restSeconds: 45,
            order: 2,
          ),
        ],
      ),
      const Routine(
        id: 'core_reset',
        name: 'Core Stability',
        category: 'Mobility',
        estimatedDurationMin: 20,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'plank',
            targetSets: 4,
            targetReps: 1,
            restSeconds: 45,
            order: 0,
          ),
        ],
      ),
    ];

    final now = DateTime.now();

    WorkoutSession buildSession({
      required String id,
      required String routineId,
      required DateTime startedAt,
      required DateTime endedAt,
      required List<CompletedSet> completedSets,
      double? rpe,
      String note = '',
    }) {
      return WorkoutSession(
        id: id,
        routineId: routineId,
        status: WorkoutSessionStatus.completed,
        startedAt: startedAt,
        endedAt: endedAt,
        currentExerciseIndex: 0,
        completedSets: completedSets,
        sessionNote: note,
        rpe: rpe,
      );
    }

    List<CompletedSet> sets(
      DateTime baseTime,
      List<(String, List<(double, int)>)> spec,
    ) {
      final output = <CompletedSet>[];
      var offset = 0;

      for (final entry in spec) {
        final exerciseId = entry.$1;
        final values = entry.$2;

        for (var index = 0; index < values.length; index++) {
          final value = values[index];
          output.add(
            CompletedSet(
              exerciseId: exerciseId,
              setNumber: index + 1,
              weightKg: value.$1,
              reps: value.$2,
              completedAt: baseTime.add(Duration(minutes: offset)),
              note: '',
            ),
          );
          offset += 4;
        }
      }

      return output;
    }

    final sessions = <WorkoutSession>[
      buildSession(
        id: 'session_push_1',
        routineId: 'push_a',
        startedAt: now.subtract(const Duration(days: 14, hours: 1)),
        endedAt: now.subtract(const Duration(days: 14)),
        completedSets: sets(now.subtract(const Duration(days: 14, hours: 1)), [
          ('bench_press', [(90, 6), (92.5, 6), (95, 5), (95, 5)]),
          ('incline_db_press', [(30, 10), (30, 10), (32.5, 8)]),
          ('shoulder_press', [(24, 10), (24, 10), (24, 9)]),
        ]),
        rpe: 7.5,
        note:
            'Bench moved well. Slight shoulder fatigue on the last dumbbell set.',
      ),
      buildSession(
        id: 'session_pull_1',
        routineId: 'pull_a',
        startedAt: now.subtract(const Duration(days: 10, hours: 1)),
        endedAt: now.subtract(const Duration(days: 10)),
        completedSets: sets(now.subtract(const Duration(days: 10, hours: 1)), [
          ('deadlift', [(160, 5), (165, 5), (170, 4)]),
          ('pull_up', [(0, 10), (0, 9), (0, 8), (0, 8)]),
          ('barbell_row', [(75, 8), (77.5, 8), (80, 8), (80, 7)]),
        ]),
        rpe: 8.0,
        note:
            'Deadlifts were heavy but crisp. Grip almost slipped on the last rep.',
      ),
      buildSession(
        id: 'session_leg_1',
        routineId: 'leg_b',
        startedAt: now.subtract(const Duration(days: 7, hours: 1, minutes: 15)),
        endedAt: now.subtract(const Duration(days: 7)),
        completedSets: sets(
          now.subtract(const Duration(days: 7, hours: 1, minutes: 15)),
          [
            ('back_squat', [(115, 5), (122.5, 5), (127.5, 5), (132.5, 4)]),
            ('leg_press', [(220, 12), (240, 12), (250, 12)]),
            ('plank', [(20, 1), (20, 1), (20, 1)]),
          ],
        ),
        rpe: 8.5,
        note: 'Strong lower body day. Squat depth stayed consistent.',
      ),
      buildSession(
        id: 'session_push_2',
        routineId: 'push_a',
        startedAt: now.subtract(const Duration(days: 4, hours: 1)),
        endedAt: now.subtract(const Duration(days: 4)),
        completedSets: sets(now.subtract(const Duration(days: 4, hours: 1)), [
          ('bench_press', [(92.5, 6), (95, 6), (97.5, 5), (100, 4)]),
          ('incline_db_press', [(32.5, 10), (32.5, 10), (35, 8)]),
          ('shoulder_press', [(24, 11), (24, 10), (26, 8)]),
          ('cable_fly', [(18, 12), (18, 12), (20, 10)]),
        ]),
        rpe: 7.8,
        note: 'Bench PR exposure. Keep elbows tucked earlier in the set.',
      ),
      buildSession(
        id: 'session_pull_2',
        routineId: 'pull_a',
        startedAt: now.subtract(const Duration(days: 2, hours: 1, minutes: 10)),
        endedAt: now.subtract(const Duration(days: 2)),
        completedSets: sets(
          now.subtract(const Duration(days: 2, hours: 1, minutes: 10)),
          [
            ('deadlift', [(165, 5), (170, 5), (175, 4)]),
            ('pull_up', [(5, 8), (5, 8), (5, 7), (5, 7)]),
            ('barbell_row', [(80, 8), (82.5, 8), (82.5, 8), (85, 7)]),
          ],
        ),
        rpe: 8.4,
        note: 'Best deadlift session this block.',
      ),
      buildSession(
        id: 'session_leg_2',
        routineId: 'leg_b',
        startedAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 5)),
        endedAt: now.subtract(const Duration(days: 1)),
        completedSets: sets(
          now.subtract(const Duration(days: 1, hours: 1, minutes: 5)),
          [
            ('back_squat', [(120, 5), (130, 5), (135, 5), (140, 5)]),
            ('leg_press', [(240, 12), (260, 12), (280, 12)]),
            ('plank', [(25, 1), (25, 1), (25, 1)]),
          ],
        ),
        rpe: 8.8,
        note: 'New squat and leg press bests. Final squat set was a grind.',
      ),
    ];

    return AppState(
      exercises: exercises,
      routines: routines,
      sessions: sessions,
    );
  }
}
