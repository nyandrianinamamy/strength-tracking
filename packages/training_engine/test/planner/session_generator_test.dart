import 'package:test/test.dart';
import 'package:training_engine/src/models/engine_exercise.dart';
import 'package:training_engine/src/models/enums.dart';
import 'package:training_engine/src/models/muscle_activation.dart';
import 'package:training_engine/src/planner/session_generator.dart';
import 'package:training_engine/src/planner/split_selector.dart';
import 'package:training_engine/src/planner/time_bounder.dart';

// ---------------------------------------------------------------------------
// Test fixtures
// ---------------------------------------------------------------------------

EngineExercise _makeExercise(
  String id,
  String primaryMuscle,
  MovementClass movement, {
  EquipmentClass equipment = EquipmentClass.barbell,
  List<String> secondaryMuscles = const [],
}) {
  final muscleMap = [
    MuscleActivation(muscleId: primaryMuscle, role: MuscleRole.primary, coefficient: 1.0),
    for (final m in secondaryMuscles)
      MuscleActivation(muscleId: m, role: MuscleRole.synergist, coefficient: 0.5),
  ];
  return EngineExercise(
    id: id,
    name: id,
    muscleMap: muscleMap,
    equipment: equipment,
    movement: movement,
  );
}

// ---------------------------------------------------------------------------
// Mock registry
// ---------------------------------------------------------------------------

class MockRegistry implements ExerciseRegistryLookup {
  final Map<String, List<EngineExercise>> _byMuscle;
  final Map<SessionFocus, List<EngineExercise>> _compounds;

  MockRegistry({
    Map<String, List<EngineExercise>>? byMuscle,
    Map<SessionFocus, List<EngineExercise>>? compounds,
  })  : _byMuscle = byMuscle ?? {},
        _compounds = compounds ?? {};

  @override
  List<EngineExercise> exercisesForMuscle(
    String muscleId, {
    Set<String>? excludeIds,
  }) {
    final all = _byMuscle[muscleId] ?? [];
    if (excludeIds == null || excludeIds.isEmpty) return all;
    return all.where((e) => !excludeIds.contains(e.id)).toList();
  }

  @override
  List<EngineExercise> compoundsForFocus(
    SessionFocus focus, {
    Set<String>? excludeIds,
  }) {
    final all = _compounds[focus] ?? [];
    if (excludeIds == null || excludeIds.isEmpty) return all;
    return all.where((e) => !excludeIds.contains(e.id)).toList();
  }
}

// ---------------------------------------------------------------------------
// Build a rich registry used in most tests
// ---------------------------------------------------------------------------

MockRegistry _buildRichRegistry() {
  final chestEx1 = _makeExercise('bench_press', 'pectorals', MovementClass.compoundUpper,
      secondaryMuscles: ['anterior_deltoid', 'triceps']);
  final chestEx2 = _makeExercise('incline_press', 'pectorals', MovementClass.compoundUpper);
  final shoulderEx1 = _makeExercise('ohp', 'anterior_deltoid', MovementClass.compoundUpper,
      secondaryMuscles: ['triceps']);
  final shoulderEx2 = _makeExercise('lateral_raise', 'anterior_deltoid', MovementClass.isolation);
  final tricepEx1 = _makeExercise('tricep_pushdown', 'triceps', MovementClass.isolation);
  final tricepEx2 = _makeExercise('skull_crusher', 'triceps', MovementClass.isolation);
  final backEx1 = _makeExercise('pullup', 'lats', MovementClass.compoundUpper,
      secondaryMuscles: ['biceps', 'rear_deltoid']);
  final backEx2 = _makeExercise('row', 'lats', MovementClass.compoundUpper,
      secondaryMuscles: ['biceps']);
  final backEx3 = _makeExercise('lat_pulldown', 'lats', MovementClass.isolation);
  final bicepEx1 = _makeExercise('barbell_curl', 'biceps', MovementClass.isolation);
  final bicepEx2 = _makeExercise('hammer_curl', 'biceps', MovementClass.isolation);
  final rearDeltEx = _makeExercise('face_pull', 'rear_deltoid', MovementClass.isolation);
  final quadEx1 = _makeExercise('squat', 'quadriceps', MovementClass.compoundLower,
      secondaryMuscles: ['glutes', 'hamstrings']);
  final quadEx2 = _makeExercise('leg_press', 'quadriceps', MovementClass.compoundLower);
  final hamstringEx1 = _makeExercise('rdl', 'hamstrings', MovementClass.compoundLower,
      secondaryMuscles: ['glutes']);
  final hamstringEx2 = _makeExercise('leg_curl', 'hamstrings', MovementClass.isolation);
  final gluteEx = _makeExercise('hip_thrust', 'glutes', MovementClass.isolation);
  final calfEx = _makeExercise('calf_raise', 'calves', MovementClass.isolation);

  return MockRegistry(
    byMuscle: {
      'pectorals': [chestEx1, chestEx2],
      'anterior_deltoid': [shoulderEx1, shoulderEx2],
      'triceps': [tricepEx1, tricepEx2],
      'lats': [backEx1, backEx2, backEx3],
      'biceps': [bicepEx1, bicepEx2],
      'rear_deltoid': [rearDeltEx],
      'quadriceps': [quadEx1, quadEx2],
      'hamstrings': [hamstringEx1, hamstringEx2],
      'glutes': [gluteEx],
      'calves': [calfEx],
    },
    compounds: {
      SessionFocus.push: [chestEx1, shoulderEx1],
      SessionFocus.pull: [backEx1, backEx2],
      SessionFocus.legs: [quadEx1, hamstringEx1],
    },
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // ── generateWeeklyPlan ────────────────────────────────────────────────────

  group('generateWeeklyPlan – full body', () {
    test('generates 3 sessions for 3 non-consecutive days', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 3, 5]); // Mon/Wed/Fri
      final plan = generateWeeklyPlan(config, registry);

      expect(plan.splitType, equals(SplitType.fullBody));
      expect(plan.sessions.length, equals(3));
    });

    test('full body session has push, pull, and leg compounds', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 3, 5]);
      final plan = generateWeeklyPlan(config, registry);

      for (final session in plan.sessions) {
        expect(session.focus, equals(SessionFocus.fullBody));
        expect(session.exercises, isNotEmpty);

        final ids = session.exercises.map((e) => e.exerciseId).toSet();
        // Should include at least one push compound (bench_press or ohp)
        expect(
          ids.any((id) => ['bench_press', 'ohp'].contains(id)),
          isTrue,
          reason: 'Full body should include a push compound',
        );
        // Should include at least one pull compound
        expect(
          ids.any((id) => ['pullup', 'row'].contains(id)),
          isTrue,
          reason: 'Full body should include a pull compound',
        );
        // Should include at least one leg compound
        expect(
          ids.any((id) => ['squat', 'rdl'].contains(id)),
          isTrue,
          reason: 'Full body should include a leg compound',
        );
      }
    });
  });

  group('generateWeeklyPlan – PPL push day', () {
    test('PPL split selected for 3 consecutive days', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 2, 3]);
      final plan = generateWeeklyPlan(config, registry);

      expect(plan.splitType, equals(SplitType.pushPullLegs));
      expect(plan.sessions[0].focus, equals(SessionFocus.push));
    });

    test('push day contains chest, shoulders, and triceps exercises', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 2, 3]);
      final plan = generateWeeklyPlan(config, registry);

      final pushSession = plan.sessions[0];
      expect(pushSession.focus, equals(SessionFocus.push));
      final ids = pushSession.exercises.map((e) => e.exerciseId).toSet();

      expect(
        ids.any((id) => ['bench_press', 'incline_press'].contains(id)),
        isTrue,
        reason: 'Push day should include chest exercise',
      );
      expect(
        ids.any((id) => ['ohp', 'lateral_raise'].contains(id)),
        isTrue,
        reason: 'Push day should include shoulder exercise',
      );
      expect(
        ids.any((id) => ['tricep_pushdown', 'skull_crusher'].contains(id)),
        isTrue,
        reason: 'Push day should include tricep exercise',
      );
    });

    test('pull day contains back and biceps exercises', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 2, 3]);
      final plan = generateWeeklyPlan(config, registry);

      final pullSession = plan.sessions[1];
      expect(pullSession.focus, equals(SessionFocus.pull));
      final ids = pullSession.exercises.map((e) => e.exerciseId).toSet();

      expect(
        ids.any((id) => ['pullup', 'row', 'lat_pulldown'].contains(id)),
        isTrue,
        reason: 'Pull day should include back exercise',
      );
      expect(
        ids.any((id) => ['barbell_curl', 'hammer_curl'].contains(id)),
        isTrue,
        reason: 'Pull day should include bicep exercise',
      );
    });

    test('legs day contains quad, hamstring, glute, calf exercises', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 2, 3]);
      final plan = generateWeeklyPlan(config, registry);

      final legsSession = plan.sessions[2];
      expect(legsSession.focus, equals(SessionFocus.legs));
      final ids = legsSession.exercises.map((e) => e.exerciseId).toSet();

      expect(
        ids.any((id) => ['squat', 'leg_press'].contains(id)),
        isTrue,
        reason: 'Legs day should include quad exercise',
      );
      expect(
        ids.any((id) => ['rdl', 'leg_curl'].contains(id)),
        isTrue,
        reason: 'Legs day should include hamstring exercise',
      );
      expect(ids.contains('hip_thrust'), isTrue,
          reason: 'Legs day should include glute exercise');
      expect(ids.contains('calf_raise'), isTrue,
          reason: 'Legs day should include calf exercise');
    });
  });

  group('generateWeeklyPlan – excluded exercises', () {
    test('respects excludedExercises', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(
        availableDays: [1, 2, 3],
        excludedExercises: ['bench_press', 'squat'],
      );
      final plan = generateWeeklyPlan(config, registry);

      for (final session in plan.sessions) {
        for (final ex in session.exercises) {
          expect(ex.exerciseId, isNot(equals('bench_press')));
          expect(ex.exerciseId, isNot(equals('squat')));
        }
      }
    });

    test('preferred exercises appear first when available', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(
        availableDays: [1, 2, 3],
        preferredExercises: ['incline_press'],
      );
      final plan = generateWeeklyPlan(config, registry);

      // On push day, incline_press should be present (it's preferred for chest)
      final pushSession = plan.sessions.firstWhere(
        (s) => s.focus == SessionFocus.push,
      );
      expect(
        pushSession.exercises.any((e) => e.exerciseId == 'incline_press'),
        isTrue,
      );
    });
  });

  group('generateWeeklyPlan – upper/lower split', () {
    test('4 days → upperLower split', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 2, 4, 5]);
      final plan = generateWeeklyPlan(config, registry);

      expect(plan.splitType, equals(SplitType.upperLower));
      expect(plan.sessions[0].focus, equals(SessionFocus.upper));
      expect(plan.sessions[1].focus, equals(SessionFocus.lower));
      expect(plan.sessions[2].focus, equals(SessionFocus.upper));
      expect(plan.sessions[3].focus, equals(SessionFocus.lower));
    });
  });

  group('generateWeeklyPlan – sets and reps', () {
    test('exercises have positive targetSets and targetReps', () {
      final registry = _buildRichRegistry();
      final config = PlannerConfig(availableDays: [1, 2, 3]);
      final plan = generateWeeklyPlan(config, registry);

      for (final session in plan.sessions) {
        for (final ex in session.exercises) {
          expect(ex.targetSets, greaterThan(0));
          expect(ex.targetReps, greaterThan(0));
          expect(ex.restSeconds, greaterThan(0));
        }
      }
    });
  });

  // ── Time Bounder ──────────────────────────────────────────────────────────

  group('boundSessionToTime', () {
    PlannedSession makeSession(List<PlannedExercise> exercises) =>
        PlannedSession(
          dayOfWeek: 1,
          focus: SessionFocus.push,
          exercises: exercises,
          estimatedDuration: Duration.zero,
        );

    test('session under time limit is returned unchanged', () {
      // One compound exercise, 3 sets, 45+180=225s per set → 675s total (< 1h)
      final exercises = [
        const PlannedExercise(
          exerciseId: 'bench_press',
          targetSets: 3,
          targetReps: 8,
          targetRpe: 8.0,
          restSeconds: 180,
        ),
      ];
      final session = makeSession(exercises);
      final result = boundSessionToTime(session, const Duration(hours: 1));

      expect(result.adjustments, isEmpty);
      expect(result.session.exercises.length, equals(1));
      expect(result.session.exercises[0].targetSets, equals(3));
    });

    test('pass 1: reduces isolation rest when over limit', () {
      // 6 isolation exercises × 3 sets × (30+120)s = 2700s > 20 min limit
      // Actually let's use restSeconds=100 (> 90) to trigger pass 1
      final isoExercises = List.generate(
        6,
        (i) => PlannedExercise(
          exerciseId: 'iso_$i',
          targetSets: 3,
          targetReps: 12,
          targetRpe: 8.5,
          restSeconds: 100, // > 90 → pass 1 target
        ),
      );
      final session = makeSession(isoExercises);
      // Total: 6 × 3 × (30+100) = 2340s. Set limit to 2000s to force pass 1.
      final result = boundSessionToTime(session, const Duration(seconds: 2000));

      expect(
        result.adjustments.any((a) => a.contains('isolation')),
        isTrue,
        reason: 'Pass 1 should note reduced isolation rest',
      );
      for (final ex in result.session.exercises) {
        expect(ex.restSeconds, lessThanOrEqualTo(100));
      }
    });

    test('pass 2: pairs exercises as supersets when still over limit', () {
      // Create exercises with compound rest (≥120s) so pass 1 does not touch
      // them, but total duration exceeds limit.
      final exercises = List.generate(
        4,
        (i) => PlannedExercise(
          exerciseId: 'compound_$i',
          targetSets: 4,
          targetReps: 8,
          targetRpe: 8.0,
          restSeconds: 180, // compound-level rest
        ),
      );
      // Total: 4 × 4 × (45+180) = 3600s. Set limit to 2000s.
      final session = makeSession(exercises);
      final result = boundSessionToTime(session, const Duration(seconds: 2000));

      expect(
        result.adjustments.any((a) => a.contains('superset')),
        isTrue,
        reason: 'Pass 2 should note superset pairing',
      );
      final supersetCount =
          result.session.exercises.where((e) => e.isSupersetPair).length;
      expect(supersetCount, greaterThan(0));
    });

    test('pass 3: trims isolation sets when still over limit', () {
      // Many isolation exercises with 3 sets each, very tight time limit.
      final exercises = List.generate(
        8,
        (i) => PlannedExercise(
          exerciseId: 'iso_$i',
          targetSets: 3,
          targetReps: 12,
          targetRpe: 8.5,
          restSeconds: 90, // already at minimum – pass 1 won't help
        ),
      );
      // Total: 8 × 3 × (30+90) = 2880s. Set limit to 1200s to force all passes.
      final session = makeSession(exercises);
      final result = boundSessionToTime(session, const Duration(seconds: 1200));

      expect(
        result.adjustments.any((a) => a.contains('Trimmed')),
        isTrue,
        reason: 'Pass 3 should note trimmed sets',
      );
      final trimmedSets =
          result.session.exercises.where((e) => e.targetSets < 3).length;
      expect(trimmedSets, greaterThan(0));
    });

    test('adjustments list describes changes applied', () {
      final exercises = List.generate(
        8,
        (i) => PlannedExercise(
          exerciseId: 'iso_$i',
          targetSets: 3,
          targetReps: 12,
          targetRpe: 8.5,
          restSeconds: 90,
        ),
      );
      final session = makeSession(exercises);
      final result = boundSessionToTime(session, const Duration(seconds: 800));

      expect(result.adjustments, isNotEmpty);
      for (final adj in result.adjustments) {
        expect(adj, isNotEmpty);
      }
    });
  });
}
