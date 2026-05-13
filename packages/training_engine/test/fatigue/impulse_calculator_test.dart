import 'package:test/test.dart';
import 'package:training_engine/src/fatigue/impulse_calculator.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  final sessionEnd = DateTime.utc(2026, 1, 1, 12);

  // Build a standard strength exercise
  final strengthExercise = EngineExercise(
    id: 'squat',
    name: 'Barbell Back Squat',
    muscleMap: [
      MuscleActivation(
        muscleId: 'quadriceps',
        role: MuscleRole.primary,
        coefficient: 1.0,
      ),
      MuscleActivation(
        muscleId: 'glutes',
        role: MuscleRole.synergist,
        coefficient: 0.6,
      ),
      MuscleActivation(
        muscleId: 'hamstrings',
        role: MuscleRole.stabilizer,
        coefficient: 0.3,
      ),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundLower,
    localFatigueKind: LocalFatigueKind.strengthVolume,
    localFatigueCap: 100.0,
  );

  // Isometric exercise (plank)
  final plankExercise = EngineExercise(
    id: 'plank',
    name: 'Plank',
    muscleMap: [
      MuscleActivation(
        muscleId: 'core',
        role: MuscleRole.primary,
        coefficient: 1.0,
      ),
      MuscleActivation(
        muscleId: 'glutes',
        role: MuscleRole.stabilizer,
        coefficient: 0.2,
      ),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
    loadKind: ExerciseLoadKind.timedIsometric,
    localFatigueKind: LocalFatigueKind.isometricHold,
    defaultLocalRpe: 7.0,
    localFatigueCap: 85.0,
  );

  // Cardio exercise (treadmill)
  final treadmillExercise = EngineExercise(
    id: 'treadmill',
    name: 'Treadmill Run',
    muscleMap: [
      MuscleActivation(
        muscleId: 'quadriceps',
        role: MuscleRole.primary,
        coefficient: 0.6,
      ),
      MuscleActivation(
        muscleId: 'calves',
        role: MuscleRole.primary,
        coefficient: 0.5,
      ),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.compoundLower,
    loadKind: ExerciseLoadKind.cardioSteady,
    localFatigueKind: LocalFatigueKind.cardioAerobicLocal,
    defaultEffortRpe: 5.0,
    cardioLocalMultiplier: 1.0,
    metabolicMultiplier: 1.0,
    localFatigueCap: 60.0,
  );

  // Cardio mixed exercise (rowing)
  final rowingExercise = EngineExercise(
    id: 'rowing',
    name: 'Rowing Machine',
    muscleMap: [
      MuscleActivation(
        muscleId: 'quadriceps',
        role: MuscleRole.primary,
        coefficient: 0.5,
      ),
      MuscleActivation(
        muscleId: 'lats',
        role: MuscleRole.primary,
        coefficient: 0.6,
      ),
      MuscleActivation(
        muscleId: 'biceps',
        role: MuscleRole.synergist,
        coefficient: 0.3,
      ),
    ],
    equipment: EquipmentClass.machine,
    movement: MovementClass.compoundUpper,
    loadKind: ExerciseLoadKind.cardioMixed,
    localFatigueKind: LocalFatigueKind.cardioAerobicLocal,
    defaultEffortRpe: 5.0,
    cardioLocalMultiplier: 1.2,
    metabolicMultiplier: 1.2,
    localFatigueCap: 60.0,
  );

  // Mobility exercise
  final mobilityExercise = EngineExercise(
    id: 'stretching',
    name: 'Hip Flexor Stretch',
    muscleMap: [
      MuscleActivation(
        muscleId: 'hip_flexors',
        role: MuscleRole.primary,
        coefficient: 0.3,
      ),
    ],
    equipment: EquipmentClass.bodyweight,
    movement: MovementClass.isolation,
    loadKind: ExerciseLoadKind.mobilitySkill,
    localFatigueKind: LocalFatigueKind.none,
  );

  // e1RM = 100 kg for strength tests
  const e1rm = 100.0;

  // 4 sets x 10 reps @ 75 kg (75% e1RM) RPE 8
  List<LoggedSet> buildStrengthSets({
    int count = 4,
    double weightKg = 75.0,
    int reps = 10,
    double strengthRpe = 8.0,
  }) => List.generate(
    count,
    (_) => LoggedSet(
      exerciseId: 'squat',
      weightKg: weightKg,
      reps: reps,
      strengthRpe: strengthRpe,
      completedAt: sessionEnd,
    ),
  );

  group('calculateImpulses – STRENGTH VOLUME', () {
    test('primary muscle receives more stress than synergist', () {
      final impulses = calculateImpulses(
        sets: buildStrengthSets(),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');
      final glutes = impulses.firstWhere((i) => i.muscleId == 'glutes');
      final hams = impulses.firstWhere((i) => i.muscleId == 'hamstrings');

      expect(quads.magnitude, greaterThan(glutes.magnitude));
      expect(glutes.magnitude, greaterThan(hams.magnitude));
    });

    test('returns one impulse per muscle in muscleMap', () {
      final impulses = calculateImpulses(
        sets: buildStrengthSets(),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      expect(impulses.length, 3);
    });

    test('all impulse timestamps equal sessionEndedAt', () {
      final impulses = calculateImpulses(
        sets: buildStrengthSets(),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      for (final i in impulses) {
        expect(i.timestamp, sessionEnd);
      }
    });

    test('higher RPE produces higher magnitude (same volume)', () {
      final high = calculateImpulses(
        sets: buildStrengthSets(strengthRpe: 10.0),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      final low = calculateImpulses(
        sets: buildStrengthSets(strengthRpe: 7.0),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final highQuads = high.firstWhere((i) => i.muscleId == 'quadriceps');
      final lowQuads = low.firstWhere((i) => i.muscleId == 'quadriceps');

      expect(highQuads.magnitude, greaterThan(lowQuads.magnitude));
    });

    test('RPE ratio 10/7 is preserved proportionally in output', () {
      final high = calculateImpulses(
        sets: buildStrengthSets(strengthRpe: 10.0),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      final low = calculateImpulses(
        sets: buildStrengthSets(strengthRpe: 7.0),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final hq = high.firstWhere((i) => i.muscleId == 'quadriceps').magnitude;
      final lq = low.firstWhere((i) => i.muscleId == 'quadriceps').magnitude;

      // Both below cap so ratio should be 10/7
      if (hq < 100 && lq > 0) {
        expect(hq / lq, closeTo(10.0 / 7.0, 0.05));
      }
    });

    test('4x10 @ RPE 8 at 75% e1RM yields F0 65-100 for primary', () {
      final impulses = calculateImpulses(
        sets: buildStrengthSets(
          count: 4,
          weightKg: 75.0,
          reps: 10,
          strengthRpe: 8.0,
        ),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');
      expect(quads.magnitude, greaterThanOrEqualTo(65.0));
      expect(quads.magnitude, lessThanOrEqualTo(100.0));
    });

    test('magnitude is capped at 100 for extreme volume', () {
      // 20 sets x 15 reps @ RPE 10 at 100% e1RM is far above max
      final sets = List.generate(
        20,
        (_) => LoggedSet(
          exerciseId: 'squat',
          weightKg: 100.0,
          reps: 15,
          strengthRpe: 10.0,
          completedAt: sessionEnd,
        ),
      );

      final impulses = calculateImpulses(
        sets: sets,
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      for (final i in impulses) {
        expect(i.magnitude, lessThanOrEqualTo(100.0));
        expect(i.magnitude, greaterThanOrEqualTo(0.0));
      }
    });

    test('magnitude is never negative', () {
      final impulses = calculateImpulses(
        sets: buildStrengthSets(strengthRpe: 5.0, weightKg: 1.0, reps: 1),
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );
      for (final i in impulses) {
        expect(i.magnitude, greaterThanOrEqualTo(0.0));
      }
    });

    test('50/50 mixed strength and timed sets stay strength classified', () {
      final impulses = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'squat',
            weightKg: 75.0,
            reps: 10,
            strengthRpe: 8.0,
            completedAt: sessionEnd,
          ),
          LoggedSet(
            exerciseId: 'squat',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            localRpe: 8.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: strengthExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');
      expect(quads.magnitude, closeTo(20.0, 0.001));
    });
  });

  group('calculateImpulses – ISOMETRIC HOLD', () {
    test('60s plank at local RPE 7 produces core fatigue around 10-15', () {
      final impulses = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            localRpe: 7.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: plankExercise,
        e1rm: e1rm, // Ignored for isometric
        sessionEndedAt: sessionEnd,
      );

      final core = impulses.firstWhere((i) => i.muscleId == 'core');
      expect(core.magnitude, greaterThanOrEqualTo(5.0));
      expect(core.magnitude, lessThanOrEqualTo(20.0));
    });

    test('3x60s plank at local RPE 8 produces meaningful fatigue', () {
      final impulses = calculateImpulses(
        sets: List.generate(
          3,
          (_) => LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            localRpe: 8.0,
            completedAt: sessionEnd,
          ),
        ),
        exercise: plankExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final core = impulses.firstWhere((i) => i.muscleId == 'core');
      // Should be noticeable but not extreme (3x single set value)
      expect(core.magnitude, greaterThanOrEqualTo(15.0));
      expect(core.magnitude, lessThanOrEqualTo(60.0));
    });

    test('longer isometric sets produce more fatigue', () {
      List<FatigueImpulse> impulsesFor(int seconds) => calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: seconds,
            localRpe: 7.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: plankExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final short = impulsesFor(30).firstWhere((i) => i.muscleId == 'core');
      final long = impulsesFor(90).firstWhere((i) => i.muscleId == 'core');

      expect(long.magnitude, greaterThan(short.magnitude));
    });

    test('isometric fatigue is capped by exercise.localFatigueCap', () {
      // Many long sets to hit the cap
      final impulses = calculateImpulses(
        sets: List.generate(
          20,
          (_) => LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 300, // 5 min each (capped at 5min)
            localRpe: 10.0,
            completedAt: sessionEnd,
          ),
        ),
        exercise: plankExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      for (final i in impulses) {
        expect(i.magnitude, lessThanOrEqualTo(85.0)); // plankExercise cap
      }
    });

    test('isometric fatigue is independent of e1rm', () {
      final lowE1rm = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            localRpe: 7.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: plankExercise,
        e1rm: 50.0,
        sessionEndedAt: sessionEnd,
      );

      final highE1rm = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'plank',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 60,
            localRpe: 7.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: plankExercise,
        e1rm: 200.0,
        sessionEndedAt: sessionEnd,
      );

      final lowCore = lowE1rm.firstWhere((i) => i.muscleId == 'core');
      final highCore = highE1rm.firstWhere((i) => i.muscleId == 'core');

      // Should be approximately equal (within floating point tolerance)
      expect(lowCore.magnitude, closeTo(highCore.magnitude, 0.001));
    });
  });

  group('calculateImpulses – CARDIO AEROBIC LOCAL', () {
    test(
      '10min treadmill moderate effort produces quad fatigue around 5 (not >60)',
      () {
        final impulses = calculateImpulses(
          sets: [
            LoggedSet(
              exerciseId: 'treadmill',
              weightKg: 0.0,
              reps: 0,
              durationSeconds: 600, // 10 min
              effortRpe: 5.0, // moderate
              completedAt: sessionEnd,
            ),
          ],
          exercise: treadmillExercise,
          e1rm: e1rm,
          sessionEndedAt: sessionEnd,
        );

        final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');
        expect(quads.magnitude, greaterThanOrEqualTo(2.0));
        expect(quads.magnitude, lessThanOrEqualTo(15.0));
        // Should NOT be >60 (the old bug)
        expect(quads.magnitude, lessThan(20.0));
      },
    );

    test('40min hard treadmill produces quad fatigue around 30-40', () {
      final impulses = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'treadmill',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 2400, // 40 min
            effortRpe: 8.0, // hard
            completedAt: sessionEnd,
          ),
        ],
        exercise: treadmillExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');
      expect(quads.magnitude, greaterThanOrEqualTo(20.0));
      expect(quads.magnitude, lessThanOrEqualTo(50.0));
    });

    test('cardio fatigue is independent of e1rm', () {
      final lowE1rm = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'treadmill',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 600,
            effortRpe: 6.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: treadmillExercise,
        e1rm: 50.0,
        sessionEndedAt: sessionEnd,
      );

      final highE1rm = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'treadmill',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 600,
            effortRpe: 6.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: treadmillExercise,
        e1rm: 200.0,
        sessionEndedAt: sessionEnd,
      );

      final lowQuads = lowE1rm.firstWhere((i) => i.muscleId == 'quadriceps');
      final highQuads = highE1rm.firstWhere((i) => i.muscleId == 'quadriceps');

      // Should be exactly equal
      expect(lowQuads.magnitude, closeTo(highQuads.magnitude, 0.001));
    });

    test('cardio fatigue is capped by exercise.localFatigueCap', () {
      // Very long hard session
      final impulses = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'treadmill',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 7200, // 2 hours
            effortRpe: 10.0, // max effort
            completedAt: sessionEnd,
          ),
        ],
        exercise: treadmillExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      for (final i in impulses) {
        expect(i.magnitude, lessThanOrEqualTo(60.0)); // treadmillExercise cap
      }
    });

    test('rowing machine (cardioMixed) uses cardioLocalMultiplier', () {
      final impulses = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'rowing',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 1800, // 30 min
            effortRpe: 7.0,
            completedAt: sessionEnd,
          ),
        ],
        exercise: rowingExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final lats = impulses.firstWhere((i) => i.muscleId == 'lats');
      final quads = impulses.firstWhere((i) => i.muscleId == 'quadriceps');

      // Both should have meaningful but capped fatigue
      expect(lats.magnitude, greaterThan(5.0));
      expect(quads.magnitude, greaterThan(5.0));
      expect(lats.magnitude, lessThanOrEqualTo(60.0));
      expect(quads.magnitude, lessThanOrEqualTo(60.0));
    });

    test('higher effort produces higher cardio fatigue', () {
      List<FatigueImpulse> impulsesFor(double effort) => calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'treadmill',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 1800, // 30 min
            effortRpe: effort,
            completedAt: sessionEnd,
          ),
        ],
        exercise: treadmillExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      final easy = impulsesFor(
        4.0,
      ).firstWhere((i) => i.muscleId == 'quadriceps');
      final hard = impulsesFor(
        8.0,
      ).firstWhere((i) => i.muscleId == 'quadriceps');

      expect(hard.magnitude, greaterThan(easy.magnitude));
    });
  });

  group('calculateImpulses – MOBILITY (no fatigue)', () {
    test('mobility exercises produce no local fatigue', () {
      final impulses = calculateImpulses(
        sets: [
          LoggedSet(
            exerciseId: 'stretching',
            weightKg: 0.0,
            reps: 0,
            durationSeconds: 300, // 5 min stretch
            completedAt: sessionEnd,
          ),
        ],
        exercise: mobilityExercise,
        e1rm: e1rm,
        sessionEndedAt: sessionEnd,
      );

      expect(impulses, isEmpty);
    });
  });

  group('calculateMetabolicLoad', () {
    test('calculates load from cardio session', () {
      final sets = [
        LoggedSet(
          exerciseId: 'treadmill',
          weightKg: 0.0,
          reps: 0,
          durationSeconds: 1800, // 30 min
          effortRpe: 6.0,
          completedAt: sessionEnd,
        ),
      ];

      final load = calculateMetabolicLoad(
        sets: sets,
        metabolicMultiplier: 1.0,
        defaultEffortRpe: 5.0,
      );

      // 30 min * 6.0 effort * 1.0 = 180
      expect(load, closeTo(180.0, 0.1));
    });

    test('uses default effort when not specified', () {
      final sets = [
        LoggedSet(
          exerciseId: 'treadmill',
          weightKg: 0.0,
          reps: 0,
          durationSeconds: 600, // 10 min
          completedAt: sessionEnd,
        ),
      ];

      final load = calculateMetabolicLoad(
        sets: sets,
        metabolicMultiplier: 1.0,
        defaultEffortRpe: 5.0,
      );

      // 10 min * 5.0 default * 1.0 = 50
      expect(load, closeTo(50.0, 0.1));
    });

    test('applies metabolicMultiplier', () {
      final sets = [
        LoggedSet(
          exerciseId: 'treadmill',
          weightKg: 0.0,
          reps: 0,
          durationSeconds: 600,
          effortRpe: 5.0,
          completedAt: sessionEnd,
        ),
      ];

      final load = calculateMetabolicLoad(
        sets: sets,
        metabolicMultiplier: 1.5,
        defaultEffortRpe: 5.0,
      );

      // 10 min * 5.0 * 1.5 = 75
      expect(load, closeTo(75.0, 0.1));
    });
  });

  group('calculateIsometricLoad', () {
    test('calculates load from isometric session', () {
      final sets = [
        LoggedSet(
          exerciseId: 'plank',
          weightKg: 0.0,
          reps: 0,
          durationSeconds: 180, // 3 min
          localRpe: 7.0,
          completedAt: sessionEnd,
        ),
      ];

      final load = calculateIsometricLoad(sets: sets, defaultLocalRpe: 7.0);

      // 3 min * 7.0 * 0.5 = 10.5
      expect(load, closeTo(10.5, 0.1));
    });
  });

  group('trainingStressForSet (legacy compatibility)', () {
    test('strength set uses weight * reps * rpe/10', () {
      final set = LoggedSet(
        exerciseId: 'squat',
        weightKg: 100.0,
        reps: 8,
        strengthRpe: 8.0,
        completedAt: sessionEnd,
      );

      final stress = trainingStressForSet(set);
      // 100 * 8 * 0.8 = 640
      expect(stress, closeTo(640.0, 0.1));
    });

    test('legacy rpe getter returns strengthRpe or 8.0', () {
      final setWithStrength = LoggedSet(
        exerciseId: 'squat',
        weightKg: 100.0,
        reps: 8,
        strengthRpe: 7.5,
        completedAt: sessionEnd,
      );
      expect(setWithStrength.rpe, 7.5);

      final setWithout = LoggedSet(
        exerciseId: 'treadmill',
        weightKg: 0.0,
        reps: 0,
        durationSeconds: 600,
        effortRpe: 6.0,
        completedAt: sessionEnd,
      );
      expect(setWithout.rpe, 8.0); // default fallback
    });
  });
}
