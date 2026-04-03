# Training Engine Host Integration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add durable host-app integration for the training engine with separate engine-state persistence, real adapter/profile mapping, and verified provider behavior.

**Architecture:** Keep `training_engine` as the pure package boundary and finish app-side integration in `lib/src/features/training_engine/`. The app will load `AppState`, build a `TrainingEngine`, restore a serialized engine snapshot when present, and otherwise bootstrap from completed workout history once. Persistence for engine state lives in a dedicated repository separate from `AppStateRepository`.

**Tech Stack:** Flutter, Riverpod, SharedPreferences, `flutter_test`, `dart:convert`, local pure Dart package `training_engine`

---

### Task 1: Add Adapter Coverage

**Files:**
- Create: `test/features/training_engine/adapter_test.dart`
- Modify: `lib/src/features/training_engine/training_engine_adapter.dart`

- [ ] **Step 1: Write the failing adapter tests**

Add tests for:
- `toUserProfile(AppState)` maps `bodyGender` and default values
- `toEngineExercise()` resolves registry matches by id/name
- `toEngineExercise()` builds a synthetic exercise from app muscles when no registry match exists

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/training_engine/adapter_test.dart`
Expected: FAIL because `toUserProfile()` and/or uncovered mapping behavior is missing.

- [ ] **Step 3: Write minimal implementation**

Implement `toUserProfile(AppState)` in `lib/src/features/training_engine/training_engine_adapter.dart` and keep exercise/session mapping behavior localized in that adapter.

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/training_engine/adapter_test.dart`
Expected: PASS

### Task 2: Add Engine State Repository + Provider Tests

**Files:**
- Create: `lib/src/features/training_engine/training_engine_state_repository.dart`
- Create: `test/features/training_engine/training_engine_provider_test.dart`
- Modify: `lib/src/features/training_engine/training_engine_provider.dart`

- [ ] **Step 1: Write the failing provider/repository tests**

Add tests for:
- empty repository -> provider bootstraps from completed app sessions
- saved engine snapshot -> provider restores snapshot and does not double-bootstrap
- repository roundtrip persists serialized engine state

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/training_engine/training_engine_provider_test.dart`
Expected: FAIL because no engine-state repository/provider wiring exists yet.

- [ ] **Step 3: Write minimal implementation**

Create a dedicated engine-state repository abstraction plus in-memory and SharedPreferences implementations. Update `training_engine_provider.dart` to:
- read `appStateControllerProvider`
- build registry with custom exercises
- build profile from `TrainingEngineAdapter`
- restore engine snapshot when present
- otherwise bootstrap from completed sessions

- [ ] **Step 4: Run test to verify it passes**

Run: `flutter test test/features/training_engine/training_engine_provider_test.dart`
Expected: PASS

### Task 3: Save/Load Integration Surface

**Files:**
- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Modify: `lib/src/features/training_engine/healthkit_data_source.dart`

- [ ] **Step 1: Wire provider dependencies cleanly**

Add the repository providers needed for engine-state persistence and keep the HealthKit data source stub injectable.

- [ ] **Step 2: Run focused integration smoke tests**

Run: `flutter test test/features/training_engine/integration_test.dart`
Expected: PASS

### Task 4: Clean Local Analyze Issues

**Files:**
- Modify: `packages/training_engine/lib/src/fatigue/muscle_registry.dart`
- Modify: `packages/training_engine/lib/src/progression/safety_gates.dart`
- Modify: `packages/training_engine/lib/training_engine.dart`
- Modify: training-engine test files only when needed for warnings

- [ ] **Step 1: Fix training-engine-local warnings/infos**

Remove the unused import, simplify constructor style where linted, drop unnecessary library name, and remove training-engine-local unused imports/locals.

- [ ] **Step 2: Run targeted verification**

Run: `flutter analyze`
Expected: remaining issues, if any, are outside this feature slice or pre-existing unrelated package infos.

### Task 5: Final Verification

**Files:**
- Verify only

- [ ] **Step 1: Run focused app tests**

Run: `flutter test test/features/training_engine/adapter_test.dart test/features/training_engine/training_engine_provider_test.dart test/features/training_engine/integration_test.dart`
Expected: PASS

- [ ] **Step 2: Run package tests**

Run: `cd packages/training_engine && dart test`
Expected: PASS

- [ ] **Step 3: Summarize completion and any residual analyze noise**

Report exactly what was implemented, what was verified, and any remaining unrelated analyzer output.
