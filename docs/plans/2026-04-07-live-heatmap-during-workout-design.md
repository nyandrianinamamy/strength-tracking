# Live Heatmap During Workout — Design

**Date:** 2026-04-07
**Issue:** Muscle fatigue heatmap not updated after logging a set

## Problem

The muscle heatmap on the dashboard only reflects completed sessions. When a user logs, removes, or edits a set during an active workout, the heatmap stays stale until the session is completed and ingested by the training engine.

## Root Cause

- `logSet()` / `deleteSet()` / `updateSet()` only update `AppState` (active session).
- The heatmap reads from `engineHeatmapDataProvider` → `fatigueMapProvider` → `trainingEngineProvider`.
- The engine only ingests completed sessions (via `_syncTrainingEngine` in `completeSession()`).
- Result: no fatigue data flows from in-progress sets to the heatmap.

## Design

### Approach: Stateless preview fatigue merged at the provider layer

The engine's fatigue system is built on pure functions (`calculateImpulses`, `fullFatigueMap`, `currentFatigue`). We exploit this by computing a "preview" fatigue contribution from the active session's sets and merging it with the engine's persisted fatigue — without mutating engine state.

### New engine method: `previewFatigueWithSets`

Add a read-only method to `TrainingEngine` that:

1. Takes a list of `LoggedSet` grouped by exercise, plus a timestamp.
2. For each exercise, looks up the `EngineExercise` in the registry and the current e1RM.
3. Calls `calculateImpulses()` to generate temporary fatigue impulses.
4. Merges these temporary impulses with the persisted `fatigueLog`.
5. Calls `fullFatigueMap()` on the merged log.
6. Returns the result without touching `_state`.

This is a pure read — no mutation, no persistence, no side effects.

### New provider: `liveEngineHeatmapDataProvider`

A `FutureProvider<Map<Muscle, MuscleData>>` that:

1. Watches `trainingEngineProvider` (for the engine instance + persisted fatigue).
2. Watches `appStateControllerProvider` (for the active session's sets).
3. If no active session or no sets → delegates to the existing `engineHeatmapDataProvider`.
4. If active session has sets → calls `engine.previewFatigueWithSets(...)` and adapts to `Map<Muscle, MuscleData>` via the UI adapter.

### Widget change

`MuscleHeatmapCard` switches from `engineHeatmapDataProvider` to `liveEngineHeatmapDataProvider`.

### Why this handles add/remove/update

The provider is derived from the **current snapshot** of `appStateControllerProvider.activeSession.completedSets`. Any mutation (add, remove, edit) to that list triggers a Riverpod rebuild, which recomputes the preview from scratch. No special invalidation calls needed in `WorkoutController`.

## Files to modify

| File | Change |
|------|--------|
| `packages/training_engine/lib/src/engine.dart` | Add `previewFatigueWithSets()` method |
| `lib/src/features/training_engine/training_engine_provider.dart` | Add `liveEngineHeatmapDataProvider` |
| `lib/src/features/dashboard/muscle_heatmap_card.dart` | Switch to `liveEngineHeatmapDataProvider` |
| `packages/training_engine/test/engine_test.dart` | Test `previewFatigueWithSets()` |

## Non-goals

- Real-time e1RM updates during workout (out of scope).
- Persisting preview fatigue (the engine ingests the full session on completion as before).
- Changing the `completeSession` → `ingestSession` flow.
