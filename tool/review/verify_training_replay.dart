// Run from the repository root after resolving training_engine dependencies:
// dart --packages=packages/training_engine/.dart_tool/package_config.json \
//   tool/review/verify_training_replay.dart
//
// Read-only diagnostic: exits 1 when a reviewed invariant is violated. The
// TestFlight 309 baseline is expected to fail both checks. No files are written.
import 'dart:convert';
import 'dart:io';

import 'package:training_engine/training_engine.dart';

void main() {
  final at = DateTime.utc(2026, 6, 1, 18);
  final profile = UserProfile(
    sex: Sex.male,
    age: 30,
    bodyWeightKg: 75,
    experience: ExperienceLevel.intermediate,
    goal: HypertrophyGoal.general,
    availableDays: const [1, 3, 5],
    maxSessionDuration: const Duration(minutes: 60),
    createdAt: at,
  );
  final registry = ExerciseRegistry.withDefaults();
  registry.addCustom(
    EngineExercise(
      id: 'review-cardio',
      name: 'Review cardio',
      muscleMap: [
        MuscleActivation(
          muscleId: 'quadriceps',
          role: MuscleRole.primary,
          coefficient: 1,
        ),
      ],
      equipment: EquipmentClass.bodyweight,
      movement: MovementClass.isolation,
      loadKind: ExerciseLoadKind.cardioSteady,
      localFatigueKind: LocalFatigueKind.cardioAerobicLocal,
    ),
  );
  final session = EngineSession(
    id: 'review-session',
    startedAt: at.subtract(const Duration(minutes: 20)),
    endedAt: at,
    sessionRpe: 8,
    sets: [
      LoggedSet(
        exerciseId: 'review-cardio',
        weightKg: 0,
        reps: 0,
        completedAt: at,
        durationSeconds: 1200,
        effortRpe: 5,
        rpeEstimated: true,
      ),
    ],
  );
  final direct = TrainingEngine(registry: registry, profile: profile)
    ..ingestSession(session);
  final replayed = TrainingEngine(registry: registry, profile: profile)
    ..bootstrapFromHistory([session]);
  final directFatigue = direct.state.fatigueLog['quadriceps']!.single.magnitude;
  final replayedFatigue =
      replayed.state.fatigueLog['quadriceps']!.single.magnitude;
  final replayMatches = (directFatigue - replayedFatigue).abs() < 1e-9;

  final exercises = [
    for (var i = 0; i < 2; i++)
      PlannedExercise(
        exerciseId: 'review-exercise-$i',
        targetSets: 4,
        targetReps: 10,
        targetRpe: 8,
        restSeconds: 180,
      ),
  ];
  final original = PlannedSession(
    dayOfWeek: 1,
    focus: SessionFocus.fullBody,
    exercises: exercises,
    estimatedDuration: estimateSessionDuration(exercises),
  );
  final bounded = boundSessionToTime(original, const Duration(minutes: 20));
  final recomputedDuration = estimateSessionDuration(bounded.session.exercises);
  final durationMatches =
      bounded.session.estimatedDuration == recomputedDuration;

  stdout.writeln(
    const JsonEncoder.withIndent('  ').convert({
      'cardioReplay': {
        'passed': replayMatches,
        'directFatigue': directFatigue,
        'replayedFatigue': replayedFatigue,
      },
      'boundedDuration': {
        'passed': durationMatches,
        'originalSeconds': original.estimatedDuration.inSeconds,
        'storedSeconds': bounded.session.estimatedDuration.inSeconds,
        'recomputedSeconds': recomputedDuration.inSeconds,
        'supersetApplied': bounded.session.exercises.first.isSupersetPair,
      },
    }),
  );
  exitCode = replayMatches && durationMatches ? 0 : 1;
}
