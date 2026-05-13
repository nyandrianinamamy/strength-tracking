import 'package:training_engine/training_engine.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine_group.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

class DemoSeedData {
  static AppState initialState() {
    final exercises = seedExercises();

    final routines = <Routine>[
      const Routine(
        id: 'push_day',
        name: 'Push Day',
        category: 'Hypertrophy',
        estimatedDurationMin: 65,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'barbell_bench_press',
            targetSets: 4,
            targetReps: 6,
            restSeconds: 120,
            order: 0,
          ),
          RoutineExercise(
            exerciseId: 'incline_dumbbell_press',
            targetSets: 3,
            targetReps: 10,
            restSeconds: 90,
            order: 1,
          ),
          RoutineExercise(
            exerciseId: 'overhead_press',
            targetSets: 3,
            targetReps: 8,
            restSeconds: 90,
            order: 2,
          ),
          RoutineExercise(
            exerciseId: 'lateral_raise',
            targetSets: 3,
            targetReps: 15,
            restSeconds: 60,
            order: 3,
          ),
          RoutineExercise(
            exerciseId: 'tricep_pushdown',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 60,
            order: 4,
          ),
          RoutineExercise(
            exerciseId: 'cable_fly',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 60,
            order: 5,
          ),
        ],
      ),
      const Routine(
        id: 'pull_day',
        name: 'Pull Day',
        category: 'Hypertrophy',
        estimatedDurationMin: 60,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'barbell_row',
            targetSets: 4,
            targetReps: 8,
            restSeconds: 90,
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
            exerciseId: 'seated_cable_row',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 75,
            order: 2,
          ),
          RoutineExercise(
            exerciseId: 'face_pull',
            targetSets: 3,
            targetReps: 15,
            restSeconds: 60,
            order: 3,
          ),
          RoutineExercise(
            exerciseId: 'barbell_curl',
            targetSets: 3,
            targetReps: 10,
            restSeconds: 60,
            order: 4,
          ),
          RoutineExercise(
            exerciseId: 'hammer_curl',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 60,
            order: 5,
          ),
        ],
      ),
      const Routine(
        id: 'leg_day',
        name: 'Leg Day',
        category: 'Strength',
        estimatedDurationMin: 70,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'barbell_back_squat',
            targetSets: 4,
            targetReps: 5,
            restSeconds: 150,
            order: 0,
          ),
          RoutineExercise(
            exerciseId: 'romanian_deadlift',
            targetSets: 3,
            targetReps: 8,
            restSeconds: 120,
            order: 1,
          ),
          RoutineExercise(
            exerciseId: 'leg_press',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 90,
            order: 2,
          ),
          RoutineExercise(
            exerciseId: 'leg_extension',
            targetSets: 3,
            targetReps: 15,
            restSeconds: 60,
            order: 3,
          ),
          RoutineExercise(
            exerciseId: 'lying_leg_curl',
            targetSets: 3,
            targetReps: 12,
            restSeconds: 60,
            order: 4,
          ),
          RoutineExercise(
            exerciseId: 'hip_thrust',
            targetSets: 3,
            targetReps: 10,
            restSeconds: 90,
            order: 5,
          ),
        ],
      ),
      const Routine(
        id: 'full_body',
        name: 'Full Body',
        category: 'Strength',
        estimatedDurationMin: 75,
        archived: false,
        exercises: [
          RoutineExercise(
            exerciseId: 'barbell_bench_press',
            targetSets: 3,
            targetReps: 6,
            restSeconds: 120,
            order: 0,
          ),
          RoutineExercise(
            exerciseId: 'barbell_back_squat',
            targetSets: 3,
            targetReps: 6,
            restSeconds: 120,
            order: 1,
          ),
          RoutineExercise(
            exerciseId: 'barbell_row',
            targetSets: 3,
            targetReps: 8,
            restSeconds: 90,
            order: 2,
          ),
          RoutineExercise(
            exerciseId: 'overhead_press',
            targetSets: 3,
            targetReps: 8,
            restSeconds: 90,
            order: 3,
          ),
          RoutineExercise(
            exerciseId: 'conventional_deadlift',
            targetSets: 3,
            targetReps: 5,
            restSeconds: 150,
            order: 4,
          ),
          RoutineExercise(
            exerciseId: 'plank',
            targetSets: 3,
            targetReps: 1,
            restSeconds: 45,
            order: 5,
            targetDurationSeconds: 60,
          ),
        ],
      ),
    ];

    final now = DateTime.now();
    const routineGroups = [
      RoutineGroup(
        id: 'ppl_split',
        name: 'Push / Pull / Legs',
        routineIds: ['push_day', 'pull_day', 'leg_day'],
        pendingRoutineIds: ['push_day', 'pull_day', 'leg_day'],
      ),
    ];

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
        lastActivityAt: endedAt,
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
        routineId: 'push_day',
        startedAt: now.subtract(const Duration(days: 14, hours: 1)),
        endedAt: now.subtract(const Duration(days: 14)),
        completedSets: sets(now.subtract(const Duration(days: 14, hours: 1)), [
          ('barbell_bench_press', [(90, 6), (92.5, 6), (95, 5), (95, 5)]),
          ('incline_dumbbell_press', [(30, 10), (30, 10), (32.5, 8)]),
          ('overhead_press', [(40, 8), (40, 8), (42.5, 7)]),
        ]),
        rpe: 7.5,
        note: 'Bench moved well. Slight shoulder fatigue on the last OHP set.',
      ),
      buildSession(
        id: 'session_pull_1',
        routineId: 'pull_day',
        startedAt: now.subtract(const Duration(days: 10, hours: 1)),
        endedAt: now.subtract(const Duration(days: 10)),
        completedSets: sets(now.subtract(const Duration(days: 10, hours: 1)), [
          ('barbell_row', [(75, 8), (77.5, 8), (80, 8), (80, 7)]),
          ('pull_up', [(0, 10), (0, 9), (0, 8), (0, 8)]),
          ('seated_cable_row', [(55, 12), (57.5, 12), (60, 10)]),
        ]),
        rpe: 8.0,
        note: 'Rows felt strong. Grip almost slipped on the last pull-up set.',
      ),
      buildSession(
        id: 'session_leg_1',
        routineId: 'leg_day',
        startedAt: now.subtract(const Duration(days: 7, hours: 1, minutes: 15)),
        endedAt: now.subtract(const Duration(days: 7)),
        completedSets: sets(
          now.subtract(const Duration(days: 7, hours: 1, minutes: 15)),
          [
            (
              'barbell_back_squat',
              [(115, 5), (122.5, 5), (127.5, 5), (132.5, 4)],
            ),
            ('romanian_deadlift', [(80, 8), (85, 8), (90, 7)]),
            ('leg_press', [(220, 12), (240, 12), (250, 12)]),
          ],
        ),
        rpe: 8.5,
        note: 'Strong lower body day. Squat depth stayed consistent.',
      ),
      buildSession(
        id: 'session_push_2',
        routineId: 'push_day',
        startedAt: now.subtract(const Duration(days: 4, hours: 1)),
        endedAt: now.subtract(const Duration(days: 4)),
        completedSets: sets(now.subtract(const Duration(days: 4, hours: 1)), [
          ('barbell_bench_press', [(92.5, 6), (95, 6), (97.5, 5), (100, 4)]),
          ('incline_dumbbell_press', [(32.5, 10), (32.5, 10), (35, 8)]),
          ('overhead_press', [(42.5, 8), (42.5, 8), (45, 6)]),
          ('cable_fly', [(18, 12), (18, 12), (20, 10)]),
        ]),
        rpe: 7.8,
        note: 'Bench PR exposure. Keep elbows tucked earlier in the set.',
      ),
      buildSession(
        id: 'session_pull_2',
        routineId: 'pull_day',
        startedAt: now.subtract(const Duration(days: 2, hours: 1, minutes: 10)),
        endedAt: now.subtract(const Duration(days: 2)),
        completedSets: sets(
          now.subtract(const Duration(days: 2, hours: 1, minutes: 10)),
          [
            ('barbell_row', [(80, 8), (82.5, 8), (82.5, 8), (85, 7)]),
            ('pull_up', [(5, 8), (5, 8), (5, 7), (5, 7)]),
            ('seated_cable_row', [(60, 12), (62.5, 12), (65, 10)]),
          ],
        ),
        rpe: 8.4,
        note: 'Best rowing session this block.',
      ),
      buildSession(
        id: 'session_leg_2',
        routineId: 'leg_day',
        startedAt: now.subtract(const Duration(days: 1, hours: 1, minutes: 5)),
        endedAt: now.subtract(const Duration(days: 1)),
        completedSets: sets(
          now.subtract(const Duration(days: 1, hours: 1, minutes: 5)),
          [
            ('barbell_back_squat', [(120, 5), (130, 5), (135, 5), (140, 5)]),
            ('romanian_deadlift', [(85, 8), (90, 8), (95, 7)]),
            ('leg_press', [(240, 12), (260, 12), (280, 12)]),
          ],
        ),
        rpe: 8.8,
        note: 'New squat and leg press bests. Final squat set was a grind.',
      ),
    ];

    return AppState(
      exercises: exercises,
      routines: routines,
      routineGroups: routineGroups,
      sessions: sessions,
      userName: 'Alex',
      activeRoutineGroupId: 'ppl_split',
      healthKitEnabled: true,
    );
  }

  /// Returns mock sleep records for the last 7 nights.
  static List<SleepRecord> seedSleep() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 7 - i));
      // Vary total between 6.5h and 8h
      final totalMinutes = 390 + (i * 15) % 90;
      final deep = (totalMinutes * 0.20).round();
      final rem = (totalMinutes * 0.22).round();
      final core = totalMinutes - deep - rem;
      return SleepRecord(
        date: date,
        totalSleep: Duration(minutes: totalMinutes),
        deepSleep: Duration(minutes: deep),
        remSleep: Duration(minutes: rem),
        coreSleep: Duration(minutes: core),
      );
    });
  }

  /// Returns mock HRV records for the last 7 days.
  static List<HrvRecord> seedHrv() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = DateTime(
        now.year,
        now.month,
        now.day,
      ).subtract(Duration(days: 7 - i));
      // SDNN between 35–55 ms, resting HR between 55–65 bpm
      return HrvRecord(
        date: date,
        sdnn: 35.0 + (i * 3.5) % 20,
        restingHeartRate: 55.0 + (i * 1.5) % 10,
      );
    });
  }

  /// Returns the full list of ~60 seed exercises with translation keys.
  static List<Exercise> seedExercises() {
    return const [
      // ── Chest ──────────────────────────────────────────────────
      Exercise(
        id: 'barbell_bench_press',
        name: 'Barbell Bench Press',
        translationKey: 'exercise_barbell_bench_press',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Triceps', 'Shoulders'],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Retract shoulder blades, plant feet, unrack and lower the bar to mid-chest, then press up.',
        archived: false,
      ),
      Exercise(
        id: 'incline_barbell_press',
        name: 'Incline Barbell Press',
        translationKey: 'exercise_incline_barbell_press',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Shoulders', 'Triceps'],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Set bench to 30-45 degrees. Lower bar to upper chest and press.',
        archived: false,
      ),
      Exercise(
        id: 'decline_barbell_press',
        name: 'Decline Barbell Press',
        translationKey: 'exercise_decline_barbell_press',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Triceps', 'Shoulders'],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Set bench to slight decline. Lower bar to lower chest and press up.',
        archived: false,
      ),
      Exercise(
        id: 'dumbbell_bench_press',
        name: 'Dumbbell Bench Press',
        translationKey: 'exercise_dumbbell_bench_press',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Triceps', 'Shoulders'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Press dumbbells from chest level, keep wrists stacked over elbows.',
        archived: false,
      ),
      Exercise(
        id: 'incline_dumbbell_press',
        name: 'Incline Dumbbell Press',
        translationKey: 'exercise_incline_dumbbell_press',
        primaryMuscles: ['Chest', 'Shoulders'],
        secondaryMuscles: ['Triceps'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Set bench to 30-45 degrees. Press dumbbells in a slight arc toward the midline.',
        archived: false,
      ),
      Exercise(
        id: 'cable_fly',
        name: 'Cable Fly',
        translationKey: 'exercise_cable_fly',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Shoulders'],
        equipment: ['Cable Machine'],
        instructions:
            'Slight bend in elbows, bring hands together in an arc, pause at peak contraction.',
        archived: false,
      ),
      Exercise(
        id: 'pec_deck',
        name: 'Pec Deck',
        translationKey: 'exercise_pec_deck',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Shoulders'],
        equipment: ['Machine'],
        instructions:
            'Keep elbows at chest height, squeeze pads together with a controlled motion.',
        archived: false,
      ),
      Exercise(
        id: 'push_up',
        name: 'Push-Up',
        translationKey: 'exercise_push_up',
        primaryMuscles: ['Chest'],
        secondaryMuscles: ['Triceps', 'Shoulders', 'Abs'],
        equipment: [],
        instructions:
            'Maintain a straight body line, lower until chest nearly touches the floor, press up.',
        archived: false,
      ),

      // ── Back ───────────────────────────────────────────────────
      Exercise(
        id: 'barbell_row',
        name: 'Barbell Row',
        translationKey: 'exercise_barbell_row',
        primaryMuscles: ['Back'],
        secondaryMuscles: ['Biceps', 'Shoulders'],
        equipment: ['Barbell'],
        instructions:
            'Hinge forward, keep back flat, row bar toward lower ribs without jerking.',
        archived: false,
      ),
      Exercise(
        id: 'dumbbell_row',
        name: 'Dumbbell Row',
        translationKey: 'exercise_dumbbell_row',
        primaryMuscles: ['Back'],
        secondaryMuscles: ['Biceps'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Support with one hand on the bench, row dumbbell to hip, squeeze shoulder blade.',
        archived: false,
      ),
      Exercise(
        id: 'lat_pulldown',
        name: 'Lat Pulldown',
        translationKey: 'exercise_lat_pulldown',
        primaryMuscles: ['Back'],
        secondaryMuscles: ['Biceps'],
        equipment: ['Cable Machine'],
        instructions:
            'Lean slightly back, pull bar to upper chest, control the return.',
        archived: false,
      ),
      Exercise(
        id: 'pull_up',
        name: 'Pull-Up',
        translationKey: 'exercise_pull_up',
        primaryMuscles: ['Back'],
        secondaryMuscles: ['Biceps'],
        equipment: ['Pull-Up Bar'],
        instructions:
            'Start from a dead hang, brace core, pull chest toward the bar without kipping.',
        archived: false,
      ),
      Exercise(
        id: 'chin_up',
        name: 'Chin-Up',
        translationKey: 'exercise_chin_up',
        primaryMuscles: ['Back', 'Biceps'],
        secondaryMuscles: [],
        equipment: ['Pull-Up Bar'],
        instructions:
            'Use a supinated grip, pull chin above the bar, lower with control.',
        archived: false,
      ),
      Exercise(
        id: 'seated_cable_row',
        name: 'Seated Cable Row',
        translationKey: 'exercise_seated_cable_row',
        primaryMuscles: ['Back'],
        secondaryMuscles: ['Biceps'],
        equipment: ['Cable Machine'],
        instructions:
            'Sit upright, pull handle to abdomen, squeeze shoulder blades together.',
        archived: false,
      ),
      Exercise(
        id: 't_bar_row',
        name: 'T-Bar Row',
        translationKey: 'exercise_t_bar_row',
        primaryMuscles: ['Back'],
        secondaryMuscles: ['Biceps', 'Shoulders'],
        equipment: ['Barbell'],
        instructions:
            'Straddle the bar, hinge forward, row with both hands toward your chest.',
        archived: false,
      ),
      Exercise(
        id: 'face_pull',
        name: 'Face Pull',
        translationKey: 'exercise_face_pull',
        primaryMuscles: ['Back', 'Shoulders'],
        secondaryMuscles: [],
        equipment: ['Cable Machine'],
        instructions:
            'Pull rope toward your face, externally rotate at the end, squeeze rear delts.',
        archived: false,
      ),

      // ── Shoulders ──────────────────────────────────────────────
      Exercise(
        id: 'overhead_press',
        name: 'Overhead Press',
        translationKey: 'exercise_overhead_press',
        primaryMuscles: ['Shoulders'],
        secondaryMuscles: ['Triceps'],
        equipment: ['Barbell', 'Rack'],
        instructions:
            'Brace core, press the bar overhead in a straight line, lock out at the top.',
        archived: false,
      ),
      Exercise(
        id: 'dumbbell_shoulder_press',
        name: 'Dumbbell Shoulder Press',
        translationKey: 'exercise_dumbbell_shoulder_press',
        primaryMuscles: ['Shoulders'],
        secondaryMuscles: ['Triceps'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Press dumbbells overhead from shoulder level, keep ribs down.',
        archived: false,
      ),
      Exercise(
        id: 'lateral_raise',
        name: 'Lateral Raise',
        translationKey: 'exercise_lateral_raise',
        primaryMuscles: ['Shoulders'],
        secondaryMuscles: [],
        equipment: ['Dumbbells'],
        instructions:
            'Raise dumbbells to the side until arms are parallel to the floor.',
        archived: false,
      ),
      Exercise(
        id: 'front_raise',
        name: 'Front Raise',
        translationKey: 'exercise_front_raise',
        primaryMuscles: ['Shoulders'],
        secondaryMuscles: ['Chest'],
        equipment: ['Dumbbells'],
        instructions:
            'Raise dumbbells in front until arms are parallel to the floor.',
        archived: false,
      ),
      Exercise(
        id: 'rear_delt_fly',
        name: 'Rear Delt Fly',
        translationKey: 'exercise_rear_delt_fly',
        primaryMuscles: ['Shoulders'],
        secondaryMuscles: ['Back'],
        equipment: ['Dumbbells'],
        instructions:
            'Bend forward, raise dumbbells to the side, squeeze rear delts.',
        archived: false,
      ),
      Exercise(
        id: 'arnold_press',
        name: 'Arnold Press',
        translationKey: 'exercise_arnold_press',
        primaryMuscles: ['Shoulders'],
        secondaryMuscles: ['Triceps'],
        equipment: ['Dumbbells'],
        instructions:
            'Start with palms facing you, rotate as you press overhead.',
        archived: false,
      ),

      // ── Biceps ─────────────────────────────────────────────────
      Exercise(
        id: 'barbell_curl',
        name: 'Barbell Curl',
        translationKey: 'exercise_barbell_curl',
        primaryMuscles: ['Biceps'],
        secondaryMuscles: [],
        equipment: ['Barbell'],
        instructions:
            'Keep elbows pinned, curl the bar up, lower with control.',
        archived: false,
      ),
      Exercise(
        id: 'dumbbell_curl',
        name: 'Dumbbell Curl',
        translationKey: 'exercise_dumbbell_curl',
        primaryMuscles: ['Biceps'],
        secondaryMuscles: [],
        equipment: ['Dumbbells'],
        instructions:
            'Curl with supination, squeeze at the top, control the eccentric.',
        archived: false,
      ),
      Exercise(
        id: 'hammer_curl',
        name: 'Hammer Curl',
        translationKey: 'exercise_hammer_curl',
        primaryMuscles: ['Biceps'],
        secondaryMuscles: [],
        equipment: ['Dumbbells'],
        instructions:
            'Keep a neutral grip, curl both dumbbells up simultaneously.',
        archived: false,
      ),
      Exercise(
        id: 'preacher_curl',
        name: 'Preacher Curl',
        translationKey: 'exercise_preacher_curl',
        primaryMuscles: ['Biceps'],
        secondaryMuscles: [],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Rest arms on the preacher pad, curl the bar without lifting elbows.',
        archived: false,
      ),
      Exercise(
        id: 'cable_curl',
        name: 'Cable Curl',
        translationKey: 'exercise_cable_curl',
        primaryMuscles: ['Biceps'],
        secondaryMuscles: [],
        equipment: ['Cable Machine'],
        instructions:
            'Stand facing the cable, curl with elbows stationary, squeeze at the top.',
        archived: false,
      ),

      // ── Triceps ────────────────────────────────────────────────
      Exercise(
        id: 'tricep_pushdown',
        name: 'Tricep Pushdown',
        translationKey: 'exercise_tricep_pushdown',
        primaryMuscles: ['Triceps'],
        secondaryMuscles: [],
        equipment: ['Cable Machine'],
        instructions:
            'Keep elbows at your sides, push the handle down, lock out at the bottom.',
        archived: false,
      ),
      Exercise(
        id: 'overhead_tricep_extension',
        name: 'Overhead Tricep Extension',
        translationKey: 'exercise_overhead_tricep_extension',
        primaryMuscles: ['Triceps'],
        secondaryMuscles: [],
        equipment: ['Dumbbells'],
        instructions:
            'Hold a dumbbell overhead with both hands, lower behind head, extend up.',
        archived: false,
      ),
      Exercise(
        id: 'skull_crusher',
        name: 'Skull Crusher',
        translationKey: 'exercise_skull_crusher',
        primaryMuscles: ['Triceps'],
        secondaryMuscles: [],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Lie on a bench, lower the bar toward your forehead, extend back up.',
        archived: false,
      ),
      Exercise(
        id: 'dips',
        name: 'Dips',
        translationKey: 'exercise_dips',
        primaryMuscles: ['Triceps', 'Chest'],
        secondaryMuscles: ['Shoulders'],
        equipment: [],
        instructions:
            'Keep your body upright for tricep emphasis, lower until elbows are at 90 degrees.',
        archived: false,
      ),
      Exercise(
        id: 'close_grip_bench_press',
        name: 'Close-Grip Bench Press',
        translationKey: 'exercise_close_grip_bench_press',
        primaryMuscles: ['Triceps'],
        secondaryMuscles: ['Chest', 'Shoulders'],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Narrow grip on the bar, lower to mid-chest, press up emphasizing triceps.',
        archived: false,
      ),

      // ── Quads ──────────────────────────────────────────────────
      Exercise(
        id: 'barbell_back_squat',
        name: 'Barbell Back Squat',
        translationKey: 'exercise_barbell_back_squat',
        primaryMuscles: ['Quads', 'Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Barbell', 'Rack'],
        instructions:
            'Brace hard, sit between your hips, keep the bar balanced over midfoot.',
        archived: false,
      ),
      Exercise(
        id: 'front_squat',
        name: 'Front Squat',
        translationKey: 'exercise_front_squat',
        primaryMuscles: ['Quads'],
        secondaryMuscles: ['Glutes', 'Abs'],
        equipment: ['Barbell', 'Rack'],
        instructions:
            'Rest bar on front delts, keep elbows high, squat to depth.',
        archived: false,
      ),
      Exercise(
        id: 'leg_press',
        name: 'Leg Press',
        translationKey: 'exercise_leg_press',
        primaryMuscles: ['Quads', 'Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Machine'],
        instructions:
            'Control the eccentric, keep lower back planted, press through midfoot.',
        archived: false,
      ),
      Exercise(
        id: 'leg_extension',
        name: 'Leg Extension',
        translationKey: 'exercise_leg_extension',
        primaryMuscles: ['Quads'],
        secondaryMuscles: [],
        equipment: ['Machine'],
        instructions:
            'Extend legs fully, squeeze quads at the top, lower slowly.',
        archived: false,
      ),
      Exercise(
        id: 'bulgarian_split_squat',
        name: 'Bulgarian Split Squat',
        translationKey: 'exercise_bulgarian_split_squat',
        primaryMuscles: ['Quads', 'Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Rear foot elevated on bench, lower until front thigh is parallel.',
        archived: false,
      ),
      Exercise(
        id: 'goblet_squat',
        name: 'Goblet Squat',
        translationKey: 'exercise_goblet_squat',
        primaryMuscles: ['Quads', 'Glutes'],
        secondaryMuscles: ['Abs'],
        equipment: ['Dumbbells'],
        instructions: 'Hold dumbbell at chest, squat deep with upright torso.',
        archived: false,
      ),
      Exercise(
        id: 'hack_squat',
        name: 'Hack Squat',
        translationKey: 'exercise_hack_squat',
        primaryMuscles: ['Quads'],
        secondaryMuscles: ['Glutes'],
        equipment: ['Machine'],
        instructions:
            'Back against pad, lower until thighs are parallel, drive up.',
        archived: false,
      ),
      Exercise(
        id: 'walking_lunge',
        name: 'Walking Lunge',
        translationKey: 'exercise_walking_lunge',
        primaryMuscles: ['Quads', 'Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Dumbbells'],
        instructions:
            'Step forward, lower rear knee toward the floor, alternate legs.',
        archived: false,
      ),

      // ── Hamstrings ─────────────────────────────────────────────
      Exercise(
        id: 'romanian_deadlift',
        name: 'Romanian Deadlift',
        translationKey: 'exercise_romanian_deadlift',
        primaryMuscles: ['Hamstrings', 'Glutes'],
        secondaryMuscles: ['Back'],
        equipment: ['Barbell'],
        instructions:
            'Hinge at the hips with slight knee bend, lower bar along shins, feel hamstring stretch.',
        archived: false,
      ),
      Exercise(
        id: 'lying_leg_curl',
        name: 'Lying Leg Curl',
        translationKey: 'exercise_lying_leg_curl',
        primaryMuscles: ['Hamstrings'],
        secondaryMuscles: [],
        equipment: ['Machine'],
        instructions:
            'Lie face down, curl heels toward glutes, squeeze at the top.',
        archived: false,
      ),
      Exercise(
        id: 'seated_leg_curl',
        name: 'Seated Leg Curl',
        translationKey: 'exercise_seated_leg_curl',
        primaryMuscles: ['Hamstrings'],
        secondaryMuscles: [],
        equipment: ['Machine'],
        instructions: 'Sit upright, curl pad behind knees, squeeze hamstrings.',
        archived: false,
      ),
      Exercise(
        id: 'stiff_leg_deadlift',
        name: 'Stiff-Leg Deadlift',
        translationKey: 'exercise_stiff_leg_deadlift',
        primaryMuscles: ['Hamstrings'],
        secondaryMuscles: ['Glutes', 'Back'],
        equipment: ['Barbell'],
        instructions:
            'Keep legs nearly straight, hinge forward, lower bar to mid-shin.',
        archived: false,
      ),
      Exercise(
        id: 'good_morning',
        name: 'Good Morning',
        translationKey: 'exercise_good_morning',
        primaryMuscles: ['Hamstrings'],
        secondaryMuscles: ['Glutes', 'Back'],
        equipment: ['Barbell', 'Rack'],
        instructions:
            'Bar on upper back, hinge forward keeping back straight, return to standing.',
        archived: false,
      ),

      // ── Glutes ─────────────────────────────────────────────────
      Exercise(
        id: 'hip_thrust',
        name: 'Hip Thrust',
        translationKey: 'exercise_hip_thrust',
        primaryMuscles: ['Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Barbell', 'Bench'],
        instructions:
            'Upper back on bench, drive hips up with barbell on lap, squeeze at the top.',
        archived: false,
      ),
      Exercise(
        id: 'glute_bridge',
        name: 'Glute Bridge',
        translationKey: 'exercise_glute_bridge',
        primaryMuscles: ['Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: [],
        instructions:
            'Lie on back, feet flat, drive hips up and squeeze glutes.',
        archived: false,
      ),
      Exercise(
        id: 'cable_kickback',
        name: 'Cable Kickback',
        translationKey: 'exercise_cable_kickback',
        primaryMuscles: ['Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Cable Machine'],
        instructions:
            'Attach ankle cuff, kick leg straight back, squeeze glute at the top.',
        archived: false,
      ),
      Exercise(
        id: 'step_up',
        name: 'Step-Up',
        translationKey: 'exercise_step_up',
        primaryMuscles: ['Glutes', 'Quads'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Dumbbells', 'Bench'],
        instructions:
            'Step onto bench driving through the heel, stand tall, lower with control.',
        archived: false,
      ),

      // ── Abs ────────────────────────────────────────────────────
      Exercise(
        id: 'crunch',
        name: 'Crunch',
        translationKey: 'exercise_crunch',
        primaryMuscles: ['Abs'],
        secondaryMuscles: [],
        equipment: [],
        instructions:
            'Lie on back, curl shoulders off the floor, squeeze abs at the top.',
        archived: false,
      ),
      Exercise(
        id: 'hanging_leg_raise',
        name: 'Hanging Leg Raise',
        translationKey: 'exercise_hanging_leg_raise',
        primaryMuscles: ['Abs'],
        secondaryMuscles: [],
        equipment: ['Pull-Up Bar'],
        instructions: 'Hang from bar, raise legs to parallel without swinging.',
        archived: false,
      ),
      Exercise(
        id: 'plank',
        name: 'Plank',
        translationKey: 'exercise_plank',
        primaryMuscles: ['Abs'],
        secondaryMuscles: [],
        equipment: [],
        instructions:
            'Maintain a straight line from shoulders to heels, breathe behind the brace.',
        archived: false,
        exerciseType: 'timed',
      ),
      Exercise(
        id: 'cable_woodchop',
        name: 'Cable Woodchop',
        translationKey: 'exercise_cable_woodchop',
        primaryMuscles: ['Abs'],
        secondaryMuscles: [],
        equipment: ['Cable Machine'],
        instructions:
            'Rotate torso diagonally, pulling the cable from high to low in a chopping motion.',
        archived: false,
      ),
      Exercise(
        id: 'ab_wheel_rollout',
        name: 'Ab Wheel Rollout',
        translationKey: 'exercise_ab_wheel_rollout',
        primaryMuscles: ['Abs'],
        secondaryMuscles: [],
        equipment: [],
        instructions:
            'Kneel on the floor, roll the wheel forward keeping core tight, pull back.',
        archived: false,
      ),

      // ── Compound / Deadlifts ──────────────────────────────────
      Exercise(
        id: 'conventional_deadlift',
        name: 'Conventional Deadlift',
        translationKey: 'exercise_conventional_deadlift',
        primaryMuscles: ['Back', 'Glutes', 'Hamstrings'],
        secondaryMuscles: ['Quads'],
        equipment: ['Barbell'],
        instructions:
            'Pull the slack out of the bar, drive through the floor, finish by squeezing glutes.',
        archived: false,
      ),
      Exercise(
        id: 'sumo_deadlift',
        name: 'Sumo Deadlift',
        translationKey: 'exercise_sumo_deadlift',
        primaryMuscles: ['Glutes', 'Quads', 'Hamstrings'],
        secondaryMuscles: ['Back'],
        equipment: ['Barbell'],
        instructions:
            'Wide stance, toes out, grip inside knees, push the floor apart as you lift.',
        archived: false,
      ),
      Exercise(
        id: 'trap_bar_deadlift',
        name: 'Trap Bar Deadlift',
        translationKey: 'exercise_trap_bar_deadlift',
        primaryMuscles: ['Back', 'Quads', 'Glutes'],
        secondaryMuscles: ['Hamstrings'],
        equipment: ['Barbell'],
        instructions:
            'Stand inside the trap bar, grip handles, drive up keeping torso upright.',
        archived: false,
      ),

      // ── Cardio ─────────────────────────────────────────────────
      Exercise(
        id: 'treadmill',
        name: 'Treadmill',
        translationKey: 'exercise_treadmill',
        primaryMuscles: ['Quads', 'Glutes', 'Calves'],
        secondaryMuscles: ['Hamstrings', 'Abs'],
        equipment: ['Machine'],
        instructions:
            'Maintain good posture, land midfoot, adjust speed and incline as needed.',
        archived: false,
        exerciseType: 'timed',
      ),
      Exercise(
        id: 'stationary_bike',
        name: 'Stationary Bike',
        translationKey: 'exercise_stationary_bike',
        primaryMuscles: ['Quads', 'Glutes'],
        secondaryMuscles: ['Calves', 'Hamstrings', 'Abs'],
        equipment: ['Machine'],
        instructions:
            'Adjust seat height, pedal at a steady cadence, increase resistance as needed.',
        archived: false,
        exerciseType: 'timed',
      ),
      Exercise(
        id: 'rowing_machine',
        name: 'Rowing Machine',
        translationKey: 'exercise_rowing_machine',
        primaryMuscles: ['Back', 'Quads', 'Glutes'],
        secondaryMuscles: ['Hamstrings', 'Biceps', 'Abs'],
        equipment: ['Machine'],
        instructions:
            'Drive with legs first, then lean back and pull handle to chest.',
        archived: false,
        exerciseType: 'timed',
      ),
      Exercise(
        id: 'stair_climber',
        name: 'Stair Climber',
        translationKey: 'exercise_stair_climber',
        primaryMuscles: ['Quads', 'Glutes', 'Calves'],
        secondaryMuscles: ['Hamstrings', 'Abs'],
        equipment: ['Machine'],
        instructions: 'Step at a steady pace, avoid leaning on the handles.',
        archived: false,
        exerciseType: 'timed',
      ),
      Exercise(
        id: 'elliptical',
        name: 'Elliptical',
        translationKey: 'exercise_elliptical',
        primaryMuscles: ['Quads', 'Glutes', 'Calves'],
        secondaryMuscles: ['Hamstrings', 'Back', 'Chest', 'Biceps', 'Triceps'],
        equipment: ['Machine'],
        instructions:
            'Maintain an upright posture, push and pull with both arms and legs.',
        archived: false,
        exerciseType: 'timed',
      ),
    ];
  }
}
