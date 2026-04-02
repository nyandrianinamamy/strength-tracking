import 'package:test/test.dart';
import 'package:training_engine/src/models/engine_exercise.dart';
import 'package:training_engine/src/models/enums.dart';
import 'package:training_engine/src/models/muscle_activation.dart';
import 'package:training_engine/src/planner/session_generator.dart';
import 'package:training_engine/src/planner/split_selector.dart';
import 'package:training_engine/src/planner/missed_session.dart';
import 'package:training_engine/src/planner/fatigue_substitution.dart';

// ---------------------------------------------------------------------------
// Shared fixtures
// ---------------------------------------------------------------------------

EngineExercise _makeExercise(
  String id,
  String primaryMuscle,
  MovementClass movement, {
  List<String> secondaryMuscles = const [],
}) {
  return EngineExercise(
    id: id,
    name: id,
    muscleMap: [
      MuscleActivation(
        muscleId: primaryMuscle,
        role: MuscleRole.primary,
        coefficient: 1.0,
      ),
      for (final m in secondaryMuscles)
        MuscleActivation(
          muscleId: m,
          role: MuscleRole.synergist,
          coefficient: 0.5,
        ),
    ],
    equipment: EquipmentClass.barbell,
    movement: movement,
  );
}

PlannedExercise _planned(String id, {int sets = 3}) => PlannedExercise(
      exerciseId: id,
      targetSets: sets,
      targetReps: 10,
      targetRpe: 8.0,
      restSeconds: 180,
    );

// ---------------------------------------------------------------------------
// Minimal registry for fatigue substitution tests
// ---------------------------------------------------------------------------

class MockRegistry implements ExerciseRegistryLookup {
  final Map<String, List<EngineExercise>> _byMuscle;

  MockRegistry(this._byMuscle);

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
  }) =>
      [];
}

// ---------------------------------------------------------------------------
// Helper to build a simple WeeklyPlan
// ---------------------------------------------------------------------------

WeeklyPlan _buildPlan({
  required List<PlannedSession> sessions,
  SplitType splitType = SplitType.pushPullLegs,
}) =>
    WeeklyPlan(
      sessions: sessions,
      splitType: splitType,
      weekStart: DateTime(2026, 4, 6), // Monday
    );

PlannedSession _buildSession(
  int day,
  SessionFocus focus,
  List<PlannedExercise> exercises,
) =>
    PlannedSession(
      dayOfWeek: day,
      focus: focus,
      exercises: exercises,
      estimatedDuration: const Duration(hours: 1),
    );

// ---------------------------------------------------------------------------
// Missed Session Tests
// ---------------------------------------------------------------------------

void main() {
  group('handleMissedSession', () {
    test('redistributes 75% of sets when >=2 sessions remain', () {
      // Plan: Mon(1) push, Wed(3) pull, Fri(5) legs
      // Miss Monday (day 1); Wed and Fri remain → 75% redistribution
      final mondayExercises = [
        _planned('bench', sets: 4),
        _planned('ohp', sets: 3),
        _planned('tricep', sets: 3),
      ]; // 10 total sets → 75% = 7.5 → 8 redistributed

      final plan = _buildPlan(sessions: [
        _buildSession(1, SessionFocus.push, mondayExercises),
        _buildSession(3, SessionFocus.pull, [_planned('pullup', sets: 3)]),
        _buildSession(5, SessionFocus.legs, [_planned('squat', sets: 3)]),
      ]);

      final updated = handleMissedSession(plan, 1, DateTime(2026, 4, 6, 8));

      // Total sets across remaining sessions should increase
      final originalRemainingSets = plan.sessions
          .where((s) => s.dayOfWeek > 1)
          .fold<int>(0, (sum, s) => sum + s.exercises.fold(0, (a, e) => a + e.targetSets));

      final updatedRemainingSets = updated.sessions
          .where((s) => s.dayOfWeek > 1)
          .fold<int>(0, (sum, s) => sum + s.exercises.fold(0, (a, e) => a + e.targetSets));

      expect(updatedRemainingSets, greaterThan(originalRemainingSets));

      // Missed session itself should be unchanged
      final missedInUpdated =
          updated.sessions.firstWhere((s) => s.dayOfWeek == 1);
      expect(
        missedInUpdated.exercises.fold<int>(0, (a, e) => a + e.targetSets),
        equals(10),
      );
    });

    test('redistributes 50% of sets when only 1 session remains', () {
      // Miss day 1; only day 3 remains
      final mondayExercises = [
        _planned('bench', sets: 4),
        _planned('ohp', sets: 4),
      ]; // 8 total → 50% = 4

      final plan = _buildPlan(sessions: [
        _buildSession(1, SessionFocus.push, mondayExercises),
        _buildSession(3, SessionFocus.pull, [_planned('pullup', sets: 3)]),
      ]);

      final originalWedSets = plan.sessions
          .firstWhere((s) => s.dayOfWeek == 3)
          .exercises
          .fold<int>(0, (a, e) => a + e.targetSets);

      final updated = handleMissedSession(plan, 1, DateTime(2026, 4, 6, 8));

      final updatedWedSets = updated.sessions
          .firstWhere((s) => s.dayOfWeek == 3)
          .exercises
          .fold<int>(0, (a, e) => a + e.targetSets);

      // 50% of 8 = 4 extra sets
      expect(updatedWedSets - originalWedSets, equals(4));
    });

    test('no redistribution if week is over (no sessions after missed day)', () {
      // Miss the last session of the week
      final plan = _buildPlan(sessions: [
        _buildSession(1, SessionFocus.push, [_planned('bench', sets: 3)]),
        _buildSession(3, SessionFocus.pull, [_planned('pullup', sets: 3)]),
        _buildSession(5, SessionFocus.legs, [_planned('squat', sets: 3)]),
      ]);

      final updated = handleMissedSession(plan, 5, DateTime(2026, 4, 10));

      // Plan should be unchanged
      for (int i = 0; i < plan.sessions.length; i++) {
        expect(
          updated.sessions[i].exercises.fold<int>(0, (a, e) => a + e.targetSets),
          equals(
            plan.sessions[i].exercises.fold<int>(0, (a, e) => a + e.targetSets),
          ),
        );
      }
    });

    test('returns unchanged plan if missedDay is not in plan', () {
      final plan = _buildPlan(sessions: [
        _buildSession(1, SessionFocus.push, [_planned('bench', sets: 3)]),
        _buildSession(3, SessionFocus.pull, [_planned('pullup', sets: 3)]),
      ]);

      final updated = handleMissedSession(plan, 2, DateTime(2026, 4, 7));

      expect(updated.sessions.length, equals(plan.sessions.length));
    });

    test('adds extra sets to matching-focus sessions preferentially', () {
      // Plan: push(1), push(3), pull(5)
      // Miss push on day 1 → remaining are push(3) and pull(5)
      // Extra sets should go to push(3) preferentially
      final plan = _buildPlan(sessions: [
        _buildSession(
            1, SessionFocus.push, [_planned('bench', sets: 4), _planned('ohp', sets: 4)]),
        _buildSession(3, SessionFocus.push, [_planned('incline', sets: 3)]),
        _buildSession(5, SessionFocus.pull, [_planned('pullup', sets: 3)]),
      ]);

      final original3Sets = plan.sessions
          .firstWhere((s) => s.dayOfWeek == 3)
          .exercises
          .fold<int>(0, (a, e) => a + e.targetSets);
      final original5Sets = plan.sessions
          .firstWhere((s) => s.dayOfWeek == 5)
          .exercises
          .fold<int>(0, (a, e) => a + e.targetSets);

      final updated = handleMissedSession(plan, 1, DateTime(2026, 4, 6, 8));

      final updated3Sets = updated.sessions
          .firstWhere((s) => s.dayOfWeek == 3)
          .exercises
          .fold<int>(0, (a, e) => a + e.targetSets);
      final updated5Sets = updated.sessions
          .firstWhere((s) => s.dayOfWeek == 5)
          .exercises
          .fold<int>(0, (a, e) => a + e.targetSets);

      // Push(3) should receive extra sets
      expect(updated3Sets, greaterThan(original3Sets));
      // Pull(5) should NOT receive extra sets (different focus, push(3) matches)
      expect(updated5Sets, equals(original5Sets));
    });
  });

  // ---------------------------------------------------------------------------
  // Fatigue Substitution Tests
  // ---------------------------------------------------------------------------

  group('adjustSessionForFatigue', () {
    test('replaces exercise when secondary muscle is fatigued (>50)', () {
      // bench_press: primary=pectorals, secondary=triceps
      // incline_press: primary=pectorals (no triceps secondary) → valid substitute
      final benchPress = _makeExercise(
        'bench_press',
        'pectorals',
        MovementClass.compoundUpper,
        secondaryMuscles: ['triceps'],
      );
      final inclinePress = _makeExercise(
        'incline_press',
        'pectorals',
        MovementClass.compoundUpper,
        // No triceps secondary → suitable substitute
      );

      final registry = MockRegistry({
        'pectorals': [benchPress, inclinePress],
      });

      final session = PlannedSession(
        dayOfWeek: 1,
        focus: SessionFocus.push,
        exercises: [_planned('bench_press')],
        estimatedDuration: const Duration(hours: 1),
      );

      final fatigueMap = {'triceps': 75.0}; // >50 → substitute

      final result = adjustSessionForFatigue(session, fatigueMap, registry);

      expect(result.session.exercises.length, equals(1));
      expect(
        result.session.exercises[0].exerciseId,
        equals('incline_press'),
        reason: 'bench_press should be replaced by incline_press',
      );
      expect(result.substitutions, isNotEmpty);
      expect(
        result.substitutions[0],
        contains('bench_press'),
      );
      expect(
        result.substitutions[0],
        contains('incline_press'),
      );
    });

    test('no substitution when muscles are recovered (fatigue <= 50)', () {
      final benchPress = _makeExercise(
        'bench_press',
        'pectorals',
        MovementClass.compoundUpper,
        secondaryMuscles: ['triceps'],
      );

      final registry = MockRegistry({
        'pectorals': [benchPress],
      });

      final session = PlannedSession(
        dayOfWeek: 1,
        focus: SessionFocus.push,
        exercises: [_planned('bench_press')],
        estimatedDuration: const Duration(hours: 1),
      );

      final fatigueMap = {'triceps': 30.0}; // ≤50 → no substitution

      final result = adjustSessionForFatigue(session, fatigueMap, registry);

      expect(result.session.exercises[0].exerciseId, equals('bench_press'));
      expect(
        result.substitutions.where((s) => s.startsWith('Replaced')),
        isEmpty,
      );
    });

    test('primary fatigue >60 adds warning, not substitution', () {
      final squat = _makeExercise('squat', 'quadriceps', MovementClass.compoundLower);

      final registry = MockRegistry({'quadriceps': [squat]});

      final session = PlannedSession(
        dayOfWeek: 1,
        focus: SessionFocus.legs,
        exercises: [_planned('squat')],
        estimatedDuration: const Duration(hours: 1),
      );

      final fatigueMap = {'quadriceps': 80.0}; // >60 → warning only

      final result = adjustSessionForFatigue(session, fatigueMap, registry);

      // Exercise should NOT be substituted
      expect(result.session.exercises[0].exerciseId, equals('squat'));
      // But a warning should be present
      expect(
        result.substitutions.any((s) => s.startsWith('Warning')),
        isTrue,
      );
    });

    test('no changes when fatigueMap is empty', () {
      final benchPress = _makeExercise(
        'bench_press',
        'pectorals',
        MovementClass.compoundUpper,
        secondaryMuscles: ['triceps'],
      );
      final registry = MockRegistry({'pectorals': [benchPress]});

      final session = PlannedSession(
        dayOfWeek: 1,
        focus: SessionFocus.push,
        exercises: [_planned('bench_press')],
        estimatedDuration: const Duration(hours: 1),
      );

      final result = adjustSessionForFatigue(session, {}, registry);

      expect(result.session.exercises[0].exerciseId, equals('bench_press'));
      expect(result.substitutions, isEmpty);
    });

    test('multiple exercises: only fatigued-secondary exercises are replaced', () {
      final deadlift = _makeExercise(
        'deadlift',
        'hamstrings',
        MovementClass.compoundLower,
        secondaryMuscles: ['erector_spinae'],
      );
      final legCurl = _makeExercise(
        'leg_curl',
        'hamstrings',
        MovementClass.isolation,
        // No erector_spinae secondary
      );
      final squat = _makeExercise('squat', 'quadriceps', MovementClass.compoundLower);

      final registry = MockRegistry({
        'hamstrings': [deadlift, legCurl],
        'quadriceps': [squat],
      });

      final session = PlannedSession(
        dayOfWeek: 1,
        focus: SessionFocus.legs,
        exercises: [_planned('deadlift'), _planned('squat')],
        estimatedDuration: const Duration(hours: 1),
      );

      // erector_spinae fatigued → deadlift should be replaced; squat unaffected
      final fatigueMap = {'erector_spinae': 70.0};

      final result = adjustSessionForFatigue(session, fatigueMap, registry);

      expect(result.session.exercises.length, equals(2));
      expect(
        result.session.exercises[0].exerciseId,
        equals('leg_curl'),
        reason: 'deadlift replaced by leg_curl (avoids erector_spinae)',
      );
      expect(
        result.session.exercises[1].exerciseId,
        equals('squat'),
        reason: 'squat unchanged',
      );
      expect(result.substitutions, hasLength(1));
    });
  });
}
