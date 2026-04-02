# Training Engine Dashboard Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ingest completed workouts into the persisted training engine and expose a real user-facing readiness card on the dashboard.

**Architecture:** Keep engine mutation behind the host-side `TrainingEngineController`, and call it from `WorkoutController.completeSession()` after the app session is finalized. Surface engine outputs with a small dashboard widget that reads the async training-engine providers and renders either a readiness summary or an empty state.

**Tech Stack:** Flutter, Riverpod, `flutter_test`, local `training_engine` package

---

### Task 1: Workout Completion Ingestion

**Files:**
- Modify: `lib/src/features/workout/workout_controller.dart`
- Modify: `test/controllers/routine_and_workout_controller_test.dart`

- [ ] **Step 1: Write the failing test**

Add a test proving that completing a workout also updates persisted training-engine state through the controller path.

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/controllers/routine_and_workout_controller_test.dart`
Expected: FAIL because workout completion does not yet trigger training-engine ingestion.

- [ ] **Step 3: Write minimal implementation**

Update `WorkoutController.completeSession()` to map the completed app session through `TrainingEngineAdapter` and call `TrainingEngineController.ingestSession(...)`.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/controllers/routine_and_workout_controller_test.dart`
Expected: PASS

### Task 2: Dashboard Readiness Card

**Files:**
- Create: `lib/src/features/dashboard/training_readiness_card.dart`
- Modify: `lib/src/features/dashboard/dashboard_screen.dart`
- Create: `test/features/dashboard/training_readiness_card_test.dart`

- [ ] **Step 1: Write the failing widget tests**

Add tests for:
- empty-state rendering when no engine sessions exist
- readiness summary rendering when the engine provider has data

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/dashboard/training_readiness_card_test.dart`
Expected: FAIL because the widget does not exist yet.

- [ ] **Step 3: Write minimal implementation**

Create `TrainingReadinessCard` as a small `ConsumerWidget` that reads `trainingEngineProvider` and `readinessProvider`, shows:
- title + short status label
- readiness score/tier when available
- empty state when the engine is still cold

Add the card to the dashboard under the existing fatigue section.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/dashboard/training_readiness_card_test.dart`
Expected: PASS

### Task 3: Focused Verification

**Files:**
- Verify only

- [ ] **Step 1: Run dashboard and controller-related tests**

Run: `flutter test test/controllers/routine_and_workout_controller_test.dart test/features/dashboard/training_readiness_card_test.dart test/features/training_engine/adapter_test.dart test/features/training_engine/training_engine_provider_test.dart test/features/training_engine/training_engine_controller_test.dart test/features/training_engine/integration_test.dart`
Expected: PASS

- [ ] **Step 2: Run targeted analyze**

Run: `flutter analyze lib/src/features/dashboard lib/src/features/workout lib/src/features/training_engine test/features/dashboard test/features/training_engine test/controllers/routine_and_workout_controller_test.dart`
Expected: PASS

- [ ] **Step 3: Summarize user-visible behavior**

Report exactly where the training engine is now used and what the dashboard shows when the user has no ingested training data yet.
