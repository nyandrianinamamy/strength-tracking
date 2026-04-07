# Live Heatmap During Workout — Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Make the muscle fatigue heatmap update in real-time as sets are logged, removed, or edited during an active workout.

**Architecture:** Add a read-only `previewFatigueWithSets()` method to `TrainingEngine` that computes fatigue from arbitrary sets without mutating state. Then create a `liveEngineHeatmapDataProvider` that merges the engine's persisted fatigue with a preview computed from the active session's sets. The heatmap widget switches to this live provider.

**Tech Stack:** Dart, Flutter, Riverpod, training_engine package

---

### Task 1: Add `previewFatigueWithSets` to TrainingEngine

**Files:**
- Modify: `packages/training_engine/lib/src/engine.dart` (after `fullFatigueMap` ~L253)
- Test: `packages/training_engine/test/engine_test.dart`

**Step 1: Write the failing test**

Add to `packages/training_engine/test/engine_test.dart` after the `fullFatigueMap` group:

```dart
group('TrainingEngine.previewFatigueWithSets', () {
  test('returns empty map for empty sets list', () {
    final engine = _engine();
    final map = engine.previewFatigueWithSets([]);
    expect(map, isEmpty);
  });

  test('returns fatigue for muscles targeted by given sets', () {
    final engine = _engine();
    final sets = [
      LoggedSet(
        exerciseId: 'barbell_back_squat',
        weightKg: 100.0,
        reps: 8,
        rpe: 8.0,
        completedAt: DateTime.utc(2026, 4, 1, 18, 0),
      ),
    ];
    final map = engine.previewFatigueWithSets(sets);
    expect(map, isNotEmpty);
    // Squat targets quadriceps
    expect(map['quadriceps'], isNotNull);
    expect(map['quadriceps']!.level, greaterThan(0.0));
  });

  test('merges preview with existing persisted fatigue', () {
    final engine = _engine();
    // Ingest a real session first
    engine.ingestSession(_session(endedAt: DateTime.utc(2026, 4, 1, 10, 0)));
    final baseline = engine.fullFatigueMap(DateTime.utc(2026, 4, 1, 18, 0));

    // Preview with additional sets
    final sets = [
      LoggedSet(
        exerciseId: 'barbell_back_squat',
        weightKg: 120.0,
        reps: 5,
        rpe: 9.0,
        completedAt: DateTime.utc(2026, 4, 1, 18, 0),
      ),
    ];
    final preview = engine.previewFatigueWithSets(
      sets,
      at: DateTime.utc(2026, 4, 1, 18, 0),
    );

    // Preview fatigue should be higher than baseline alone
    expect(
      preview['quadriceps']!.level,
      greaterThan(baseline['quadriceps']!.level),
    );
  });

  test('does not mutate engine state', () {
    final engine = _engine();
    engine.ingestSession(_session());
    final stateBefore = engine.state.fatigueLog.length;

    engine.previewFatigueWithSets([
      LoggedSet(
        exerciseId: 'barbell_back_squat',
        weightKg: 100.0,
        reps: 10,
        rpe: 9.0,
        completedAt: DateTime.now(),
      ),
    ]);

    expect(engine.state.fatigueLog.length, equals(stateBefore));
  });

  test('skips sets with unknown exercise IDs', () {
    final engine = _engine();
    final sets = [
      LoggedSet(
        exerciseId: 'totally_unknown_exercise',
        weightKg: 50.0,
        reps: 10,
        rpe: 7.0,
        completedAt: DateTime.now(),
      ),
    ];
    final map = engine.previewFatigueWithSets(sets);
    expect(map, isEmpty);
  });
});
```

**Step 2: Run test to verify it fails**

Run: `cd packages/training_engine && dart test test/engine_test.dart --name "previewFatigueWithSets"`
Expected: FAIL — method does not exist

**Step 3: Write the implementation**

Add to `packages/training_engine/lib/src/engine.dart` after `fullFatigueMap()` (~L253):

```dart
/// Returns a fatigue map that includes both persisted fatigue AND the
/// projected contribution from [previewSets], without mutating engine state.
///
/// Used for live heatmap updates during an active workout.
Map<String, fatigue_lib.FatigueStatus> previewFatigueWithSets(
  List<LoggedSet> previewSets, {
  DateTime? at,
}) {
  final now = at ?? DateTime.now();

  if (previewSets.isEmpty) {
    return fullFatigueMap(now);
  }

  // Group preview sets by exercise
  final setsByExercise = <String, List<LoggedSet>>{};
  for (final set in previewSets) {
    setsByExercise.putIfAbsent(set.exerciseId, () => []).add(set);
  }

  // Build temporary impulses from preview sets
  final previewImpulses = <String, List<FatigueImpulse>>{};
  for (final entry in setsByExercise.entries) {
    final exercise = registry.lookup(entry.key);
    if (exercise == null) continue;

    final e1rm = currentE1rm(entry.key) ?? 100.0;
    final impulses = impulse_lib.calculateImpulses(
      sets: entry.value,
      exercise: exercise,
      e1rm: e1rm,
      sessionEndedAt: now,
    );
    for (final impulse in impulses) {
      previewImpulses
          .putIfAbsent(impulse.muscleId, () => [])
          .add(impulse);
    }
  }

  // Merge persisted fatigue log with preview impulses
  final mergedLog = <String, List<FatigueImpulse>>{};
  for (final entry in _state.fatigueLog.entries) {
    mergedLog[entry.key] = List.of(entry.value);
  }
  for (final entry in previewImpulses.entries) {
    mergedLog.putIfAbsent(entry.key, () => []).addAll(entry.value);
  }

  return fatigue_lib.fullFatigueMap(
    mergedLog,
    now,
    age: _state.profile.age,
  );
}
```

**Step 4: Run tests to verify they pass**

Run: `cd packages/training_engine && dart test test/engine_test.dart --name "previewFatigueWithSets"`
Expected: All 5 tests PASS

**Step 5: Commit**

```bash
git add packages/training_engine/lib/src/engine.dart packages/training_engine/test/engine_test.dart
git commit -m "feat(engine): add previewFatigueWithSets for live heatmap"
```

---

### Task 2: Add `liveEngineHeatmapDataProvider`

**Files:**
- Modify: `lib/src/features/training_engine/training_engine_provider.dart` (after `engineHeatmapDataProvider` ~L145)

**Step 1: Write the provider**

Add after `engineHeatmapDataProvider` in `training_engine_provider.dart`:

```dart
/// Returns heatmap data that includes real-time fatigue from the active
/// workout session. Falls back to [engineHeatmapDataProvider] when there
/// is no active session or no logged sets.
final liveEngineHeatmapDataProvider = FutureProvider<Map<Muscle, MuscleData>>((
  ref,
) async {
  final appState = ref.watch(appStateControllerProvider);
  final activeSession = appState.activeSession;
  final activeSets = activeSession?.completedSets ?? [];

  // No active workout — use the standard engine-only heatmap
  if (activeSets.isEmpty) {
    return ref.watch(engineHeatmapDataProvider.future);
  }

  final engine = await ref.watch(trainingEngineProvider.future);
  if (engine.state.sessionsIngested == 0 && activeSets.isEmpty) {
    return <Muscle, MuscleData>{};
  }

  // Convert app CompletedSets to engine LoggedSets
  final adapter = ref.watch(trainingEngineAdapterProvider);
  final engineSets = activeSets
      .where((s) => s.reps > 0)
      .map((s) => LoggedSet(
            exerciseId: s.exerciseId,
            weightKg: s.weightKg,
            reps: s.reps,
            rpe: s.rpe ?? 8.0,
            completedAt: s.completedAt,
          ))
      .toList();

  final fatigueMap = engine.previewFatigueWithSets(engineSets);
  return ref.watch(trainingEngineUiAdapterProvider).toHeatmapData(fatigueMap);
});
```

Note: This requires adding the `LoggedSet` import. The file already imports `package:training_engine/training_engine.dart` which exports `LoggedSet`.

Also need to add the import for `CompletedSet` model — but since we access it through `appState.activeSession.completedSets`, and the `appStateControllerProvider` is already imported, no new imports are needed.

**Step 2: Verify it compiles**

Run: `cd /Users/mamy/Project/StrengthApp && flutter analyze lib/src/features/training_engine/training_engine_provider.dart`
Expected: No analysis errors

**Step 3: Commit**

```bash
git add lib/src/features/training_engine/training_engine_provider.dart
git commit -m "feat: add liveEngineHeatmapDataProvider for real-time heatmap"
```

---

### Task 3: Switch `MuscleHeatmapCard` to live provider

**Files:**
- Modify: `lib/src/features/dashboard/muscle_heatmap_card.dart:15`

**Step 1: Update the provider reference**

Change line 15 from:

```dart
final fatigue = ref.watch(engineHeatmapDataProvider).maybeWhen(
```

to:

```dart
final fatigue = ref.watch(liveEngineHeatmapDataProvider).maybeWhen(
```

**Step 2: Verify it compiles**

Run: `flutter analyze lib/src/features/dashboard/muscle_heatmap_card.dart`
Expected: No analysis errors

**Step 3: Commit**

```bash
git add lib/src/features/dashboard/muscle_heatmap_card.dart
git commit -m "feat: wire MuscleHeatmapCard to live heatmap provider"
```

---

### Task 4: Manual smoke test

**Step 1: Run the app**

Run: `flutter run` (or use an existing simulator session)

**Step 2: Verify behavior**

1. Open dashboard — heatmap should display normally (baseline from completed sessions)
2. Start a workout and log a set for an exercise (e.g. squat)
3. Navigate back to dashboard — heatmap should now show increased fatigue on the targeted muscles (quads, glutes, etc.)
4. Go back to workout, delete the set
5. Check dashboard — heatmap should return to baseline
6. Log a set, then edit its weight/reps
7. Check dashboard — heatmap should reflect the updated values
8. Complete the workout — heatmap should still look correct (engine ingests the session as before)

**Step 3: Commit design doc and plan**

```bash
git add docs/plans/2026-04-07-live-heatmap-during-workout-design.md docs/plans/2026-04-07-live-heatmap-during-workout-plan.md
git commit -m "docs: add design and plan for live heatmap during workout"
```
