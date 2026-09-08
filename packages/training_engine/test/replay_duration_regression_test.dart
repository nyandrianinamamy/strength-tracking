import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  final at = DateTime.utc(2026, 9, 1, 12);
  TrainingEngine engine() => TrainingEngine(
    registry: ExerciseRegistry.withDefaults()
      ..addCustom(
        EngineExercise(
          id: 'running',
          name: 'Run',
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
      ),
    profile: UserProfile(
      sex: Sex.male,
      age: 30,
      bodyWeightKg: 75,
      experience: ExperienceLevel.intermediate,
      goal: HypertrophyGoal.hypertrophy,
      availableDays: [1, 3, 5],
      maxSessionDuration: const Duration(hours: 1),
      createdAt: at,
    ),
  );
  for (final exerciseId in ['barbell_back_squat', 'plank', 'running']) {
    for (final mode in ['missing', 'estimated', 'explicit']) {
      final explicit = mode == 'explicit';
      final missing = mode == 'missing';
      test('$exerciseId $mode replay and restart agree', () {
        final isStrength = exerciseId == 'barbell_back_squat';
        final isCardio = exerciseId == 'running';
        final set = LoggedSet(
          exerciseId: exerciseId,
          weightKg: isStrength ? 80 : 0,
          reps: isStrength ? 8 : 0,
          durationSeconds: isStrength ? 0 : (isCardio ? 1200 : 60),
          completedAt: at,
          rpeEstimated: !explicit,
          strengthRpe: isStrength && !missing ? (explicit ? 9 : 7) : null,
          effortRpe: isCardio && !missing ? (explicit ? 6 : 5) : null,
          localRpe: !isCardio && !isStrength && !missing
              ? (explicit ? 9 : 7)
              : null,
          intensityClass: IntensityClass.moderate,
        );
        final session = EngineSession(
          id: 'session',
          startedAt: at.subtract(const Duration(minutes: 30)),
          endedAt: at,
          sessionRpe: 8,
          sets: [set],
        );
        final direct = engine()..ingestSession(session);
        final restored = engine()..restoreState(direct.serializeState());
        final replayed = engine()
          ..bootstrapFromHistory([EngineSession.fromJson(session.toJson())]);
        expect(direct.state.fatigueLog, isNotEmpty);
        Map<String, dynamic> derivatives(TrainingEngine engine) {
          // Restore applies canonical muscle-ID migration; compare the same
          // representation and ignore the wall-clock persistence timestamp.
          final canonical = TrainingEngine(
            registry: engine.registry,
            profile: engine.state.profile,
          )..restoreState(engine.serializeState());
          return canonical.serializeState()..remove('lastUpdated');
        }

        expect(derivatives(replayed), derivatives(direct));
        expect(derivatives(restored), derivatives(direct));
      });
    }
  }

  test('unsupported supersets cannot compress the execution estimate', () {
    final exercises = [
      for (var i = 0; i < 2; i++)
        PlannedExercise(
          exerciseId: 'ex$i',
          targetSets: 4,
          targetReps: 8,
          targetRpe: 8,
          restSeconds: 180,
          isSupersetPair: true,
        ),
    ];
    final original = PlannedSession(
      dayOfWeek: 1,
      focus: SessionFocus.push,
      exercises: exercises,
      estimatedDuration: const Duration(minutes: 18),
    );
    final result = boundSessionToTime(
      original,
      const Duration(minutes: 20),
      allowSupersets: false,
    );
    expect(result.session.exercises.every((e) => !e.isSupersetPair), isTrue);
    expect(result.session.estimatedDuration, const Duration(minutes: 30));
    expect(result.fitsWithinLimit, isFalse);
  });

  test('bounded estimate always describes the returned exercises', () {
    for (final rest in [100, 180, 90]) {
      final exercises = List.generate(
        6,
        (i) => PlannedExercise(
          exerciseId: 'ex$i',
          targetSets: 3,
          targetReps: 8,
          targetRpe: 8,
          restSeconds: rest,
        ),
      );
      final original = PlannedSession(
        dayOfWeek: 1,
        focus: SessionFocus.push,
        exercises: exercises,
        estimatedDuration: const Duration(minutes: 30),
      );
      for (final limit in [
        const Duration(hours: 2),
        const Duration(minutes: 20),
        const Duration(minutes: 1),
      ]) {
        final result = boundSessionToTime(original, limit);
        expect(
          result.session.estimatedDuration,
          estimateSessionDuration(result.session.exercises),
        );
        expect(
          result.fitsWithinLimit,
          result.session.estimatedDuration <= limit,
        );
      }
    }
  });
}
