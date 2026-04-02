# Engine Hard Switch Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace all remaining legacy fatigue and recommendation paths with the training-engine providers so dashboard, workout, and watch surfaces all use the same engine-derived data.

**Architecture:** Add one app-side adapter layer that maps training-engine fatigue and load recommendations into the dashboard/workout/watch UI shapes. Migrate callers to those engine-backed providers, then delete the legacy `muscle_heatmap_service` and `adaptive_progression_service` implementations and their tests.

**Tech Stack:** Flutter, Riverpod, `training_engine`, `flutter_body_heatmap`, widget tests, provider tests

---

### Task 1: Add Engine UI Adapters

**Files:**
- Create: `lib/src/features/training_engine/training_engine_ui_adapter.dart`
- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Test: `test/features/training_engine/training_engine_ui_adapter_test.dart`

- [ ] Add a failing test that maps engine fatigue statuses into body-heatmap muscle data and converts load recommendations into the app suggestion shape.
- [ ] Run: `flutter test test/features/training_engine/training_engine_ui_adapter_test.dart`
- [ ] Implement the minimal adapter and provider helpers to satisfy the test.
- [ ] Re-run: `flutter test test/features/training_engine/training_engine_ui_adapter_test.dart`

### Task 2: Switch Dashboard And Workout Heatmaps

**Files:**
- Modify: `lib/src/features/dashboard/muscle_heatmap_card.dart`
- Modify: `lib/src/features/workout/active_workout_screen.dart`
- Delete: `lib/src/features/dashboard/muscle_heatmap_service.dart`
- Test: `test/features/dashboard/muscle_heatmap_card_test.dart`
- Delete/replace: `test/features/dashboard/muscle_heatmap_service_test.dart`

- [ ] Add failing tests that prove dashboard and active workout heatmaps render engine-backed fatigue data rather than raw AppState heuristics.
- [ ] Run the focused heatmap tests and verify they fail for the expected missing engine-backed behavior.
- [ ] Update the dashboard and workout heatmaps to read the engine-backed fatigue provider/adapter.
- [ ] Remove the legacy muscle heatmap service and update tests.
- [ ] Re-run the focused heatmap tests.

### Task 3: Switch Workout And Watch Recommendations

**Files:**
- Modify: `lib/src/features/workout/active_workout_screen.dart`
- Modify: `lib/src/features/watch/watch_sync_service.dart`
- Delete: `lib/src/features/progress/adaptive_progression_service.dart`
- Test: `test/features/watch/watch_sync_service_test.dart`
- Test: `test/features/workout/active_workout_rpe_test.dart`
- Delete/replace: `test/features/progress/adaptive_progression_service_test.dart`

- [ ] Add failing tests that prove workout/watch suggestions now come from engine-backed load recommendations.
- [ ] Run the focused recommendation tests and verify they fail for the expected legacy-path reason.
- [ ] Replace the legacy progression service calls with the engine-backed recommendation provider/adapter.
- [ ] Remove the legacy progression service and update or delete obsolete tests.
- [ ] Re-run the focused recommendation tests.

### Task 4: Full Verification

**Files:**
- Verify: `lib/src/features/dashboard/*`
- Verify: `lib/src/features/workout/*`
- Verify: `lib/src/features/watch/*`
- Verify: `lib/src/features/training_engine/*`

- [ ] Run: `flutter test test/features/training_engine test/features/dashboard test/features/watch test/features/workout test/controllers/routine_and_workout_controller_test.dart`
- [ ] Run: `flutter analyze lib/src/features/dashboard lib/src/features/workout lib/src/features/watch lib/src/features/training_engine test/features/dashboard test/features/watch test/features/workout test/controllers/routine_and_workout_controller_test.dart`
- [ ] Confirm there are no remaining runtime references to `muscleHeatmapServiceProvider` or `adaptiveProgressionServiceProvider`.
