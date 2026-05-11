# GPT Pro Audit Remediation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert the GPT Pro feature-inventory and training-engine audits into an ordered set of agent-sized remediation tasks with explicit functional requirements, tests, and acceptance checks.

**Architecture:** Treat completed workout history in `AppState` as the authoritative source for app-side training data, keep `packages/training_engine` pure Dart, and keep UI/product claims synchronized with actual runtime behavior. Documentation tasks correct overstatements first; P0 engine tasks then fix data loss, fake health data, and misleading recommendations before broader formula, platform, and E2E coverage work.

**Tech Stack:** Flutter, Riverpod, Firebase/Auth/Firestore-backed repositories, SharedPreferences, Flutter integration tests, pure Dart `training_engine` package tests, iOS method channels for Watch and Live Activity.

---

## Source Inputs

- `docs/gpt-pro-feature-inventory-audit-answer.md`
- `docs/gpt-pro-training-engine-functional-audit-answer.md`
- Current repo spot checks performed while drafting:
  - `web/manifest.json`, `web/privacy.html`, and `web/terms.html` exist in the current tree.
  - `lib/main.dart` initializes `workoutLiveActivityServiceProvider` and `watchSyncServiceProvider` on non-web iOS.

## Agent Operating Rules

- Work one task at a time. Do not combine unrelated tasks into one commit.
- Do not revert edits made by other agents. If a task touches a file already changed by another agent, inspect and adapt.
- Every code task must include a failing test first, then implementation, then passing verification.
- No skipped tests. Every task must include runnable deterministic local tests, and platform runtime verification is additional required evidence when the task touches platform behavior.
- Keep docs truthful, but documentation wording may not substitute for required implementation work.

## Priority Map

P0 tasks remove user-visible falsehoods or correctness risks:

- Task 1: Correct the app feature inventory.
- Task 2: Correct automated-coverage claims and convert shortcut claims into explicit coverage debt.
- Task 3: Make completed-session engine ingestion durable and reconciled.
- Task 4: Use captured profile fields in engine profile mapping and saved-state profile reconciliation.
- Task 5: Remove fake HealthKit recovery data from empty/denied fetch paths.
- Task 6: Use routine targets in visible load recommendations.
- Task 7: Fix deload/reduction direction labels in the UI.

P1 tasks make engine math and mapping behavior match product claims:

- Task 8: Select the best e1RM estimate while preserving previous top-set behavior.
- Task 9: Make ACWR truly daily.
- Task 10: Define and implement timed-exercise engine behavior.
- Task 11: Align the app RPE range with the engine RPE contract.
- Task 12: Close heatmap mapping and muscle-gating gaps.
- Task 13: Emit readiness flags for sleep and resting-heart-rate risks.

P2 tasks close broader product and runtime gaps:

- Task 14: Make Smart Planner adaptation claims true.
- Task 15: Align Progress analytics with the engine.
- Task 16: Verify iOS Watch and Live Activity runtime wiring.
- Task 17: Verify web/PWA/legal claims against current web assets.
- Task 18: Strengthen web E2E tests where current tests use state/controller shortcuts.
- Task 19: Run final full verification and update the plan completion ledger.

---

## Task 1: Correct the App Feature Inventory

**Category:** Documentation truthfulness
**Status:** Completed 2026-05-11. GPT-5.5 implementer updated the inventory; GLM verifier passed the Task 1 functional-requirement review. Commit: `0a40e15`.

**Files:**

- Modify: `docs/app-feature-inventory.md`
- Read: `docs/gpt-pro-feature-inventory-audit-answer.md`
- Read: `lib/main.dart`
- Read: `web/manifest.json`
- Read: `web/privacy.html`
- Read: `web/terms.html`

**Functional Requirements:**

- Routine features must not claim per-exercise recommended weight. Routine prescriptions persist only exercise id, sets, reps, rest, order, and timed duration.
- Active Workout must list implemented weight/reps prefill behavior: current-session set, previous completed same-exercise set, and engine suggestion when no current-session or previous completed set exists.
- Active Workout must list the progression hint card, same-primary-muscle swap/search, previous-performance panel, end-of-workout page, and rest-timer audio/iOS haptics.
- The planned section must not list auto-fill from last session or progressive overload suggestions as future-only work because those behaviors already exist in narrower implemented forms.
- Active Workout must say active UI exposes per-set comments. It must say `sessionNote` is modeled, controller-supported, and summary-displayed, but no active-workout session-note editor is visible.
- Workout Summary must not claim timed PR duration display in `WorkoutSummaryScreen`. Timed PR duration display belongs to Progress.
- Dashboard must own the workout-frequency calendar with date-tap details. Progress must only say it computes calendar-session data reused by Dashboard.
- Authentication must distinguish Google visible UI from Apple service helpers. Apple auth/link helpers and localization strings exist, but onboarding/settings visible UI exposes Google.
- Apple token revocation must be listed as required implementation work for delete-account flow, not as a completed user-facing feature.
- Settings must place Apple Health under iOS-only Integrations, not Profile.
- Settings sample-load action must say it appends exercises, routines, and routine groups, not sample sessions.
- Training-engine adapter status must say the app captures `age`, `weight`, and `fitnessGoal`, but the adapter currently uses only `sex`; Task 4 is required to close that implementation gap.
- Localization status must state the exercise list/search/routine picker and Smart Planner labels still use raw or hard-coded English text; this is an implementation gap, not an acceptable final state.
- Web/PWA section must be based on current repo files, not the older GPT Pro archive limitation. It must claim manifest and static privacy/terms pages exist because the files are present now.
- iOS native section must reflect current repo wiring: `lib/main.dart` initializes Watch and Live Activity services on non-web iOS, and Task 16 is required to prove runtime correctness on iOS/watchOS.
- Current Automated Coverage must say some E2E flows use controller/state seeding, and must not imply full UI-driving for Smart Planner generation/adoption.

**Steps:**

- [x] Edit `docs/app-feature-inventory.md` to satisfy every functional requirement above.
- [x] Run `rg -n "Per-exercise recommended weight|Auto-fill from last session|Progressive overload suggestions directly|Per-session note|Timed PR display|Workout frequency/calendar data|Apple sign-in and link-account flows|HealthKit toggle when supported|adapter uses conservative placeholder" docs/app-feature-inventory.md`.
- [x] Confirm every match is either gone or rewritten with the implementation-status wording required above.
- [x] Run `rg -n "manifest|privacy|terms|workoutLiveActivityServiceProvider|watchSyncServiceProvider" web lib/main.dart docs/app-feature-inventory.md`.
- [x] Commit only documentation changes for this task.

**Acceptance Checks:**

- `docs/app-feature-inventory.md` separates implemented, service-scaffolded, source-present, runtime-verified, and planned features.
- No inventory statement contradicts the two GPT Pro audits or the current tree spot checks.

---

## Task 2: Correct Automated-Coverage Claims

**Category:** Test coverage truthfulness
**Status:** Completed 2026-05-11. GPT-5.5 worker left the coverage-doc edits; the orchestrator trimmed a local ignored-log reference; GLM verifier passed the Task 2 functional-requirement review. Commit: `43f0e9b`.

**Files:**

- Modify: `docs/e2e-web-flow-inventory.md`
- Modify: `docs/app-feature-inventory.md`
- Read: `integration_test/app_test.dart`
- Read: `integration_test/e2e_helpers.dart`

**Functional Requirements:**

- Coverage docs must identify which flows are fully UI-driven and which flows rely on direct state/controller setup.
- Smart Planner coverage must be described as route rendering and injected adopted-state assertions, and Task 18 must replace that with full UI-driven generation/adoption coverage.
- Routine archive, routine-group rotation, timed workout update, and Smart Planner adopted-state coverage must be checked against `integration_test/app_test.dart` and labeled honestly.
- The docs must preserve the fact that the web E2E suite passes, while avoiding language that says every feature path is fully exercised through user interactions.

**Steps:**

- [x] Add a "Coverage Status" section to `docs/e2e-web-flow-inventory.md`.
- [x] List each shortcut-backed flow with the source test name or nearby description from `integration_test/app_test.dart`.
- [x] Add a short "Required UI Coverage Work" list that maps directly to Task 18.
- [x] Run `rg -n "Smart Planner|controller|state seeding|shortcut|UI-driven|Coverage Status|Required UI Coverage Work" docs/e2e-web-flow-inventory.md docs/app-feature-inventory.md`.
- [x] Commit only coverage-doc changes for this task.

**Acceptance Checks:**

- A future reader can tell which E2E claims are true browser/user flows and which are state-backed flow assertions.
- The docs still point to `bash tool/ci/run_web_e2e.sh` as the current web verification command.

---

## Task 3: Make Completed-Session Engine Ingestion Durable

**Category:** P0 training-engine data integrity
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; GLM verifier passed Task 3; local verification passed `dart format`, package tests (`+61`), and Flutter tests (`+22`). Commit: `387ab41`.

**Files:**

- Modify: `packages/training_engine/lib/src/models/training_state.dart`
- Modify: `packages/training_engine/lib/src/engine.dart`
- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Modify: `lib/src/features/training_engine/training_engine_controller.dart`
- Modify: `lib/src/features/workout/workout_controller.dart`
- Test: `packages/training_engine/test/models/training_state_test.dart`
- Test: `packages/training_engine/test/engine_test.dart`
- Test: `test/features/training_engine/training_engine_provider_test.dart`
- Test: `test/features/training_engine/training_engine_controller_test.dart`
- Test: `test/controllers/routine_and_workout_controller_test.dart`

**Functional Requirements:**

- Completed sessions saved in `AppState` are the authoritative history for app-side training-engine reconstruction.
- Engine state must record which app workout session ids have been ingested.
- `TrainingEngine.ingestSession` must be idempotent by session id. Ingesting the same `EngineSession.id` twice must not duplicate e1RM estimates, fatigue impulses, daily load, ACWR updates, last-top-set history, or `sessionsIngested`.
- `loadTrainingEngine` must not return a restored saved state that is missing completed app sessions. It must reconcile saved engine state with `appState.completedSessions`.
- If completed session ids in `AppState` differ from the ids stored in engine state, the provider must rebuild engine state from current completed history or otherwise produce the exact same logical state as a clean rebuild.
- Failed fire-and-forget sync in `WorkoutController.completeSession` must not cause permanent engine data loss. A later provider load must repair the missing session from `AppState`.
- Deleting a completed session from app history must not leave that session contributing to engine state after reconciliation.
- Corrupted saved engine state must be cleared and rebuilt from app history.

**Steps:**

- [x] Add failing package tests for duplicate `EngineSession.id` ingestion and serialized `ingestedSessionIds` roundtrip.
- [x] Add failing provider tests for saved engine state with one completed session while `AppState` has two completed sessions.
- [x] Add a failing provider test for saved engine state containing a deleted session id that no longer appears in `AppState.completedSessions`.
- [x] Add a failing controller/workout test where engine save or ingest fails once and a later provider load ingests the completed session from `AppState`.
- [x] Implement `ingestedSessionIds` in `TrainingState`, with backward-compatible JSON parsing for older snapshots that lack the field.
- [x] Make engine ingestion idempotent by session id.
- [x] Update `loadTrainingEngine` reconciliation so restored state is accepted only when its ingested session ids exactly match current completed app session ids.
- [x] Keep HealthKit ingestion behavior unchanged in this task except for preserving records during rebuild; Task 5 owns HealthKit semantics.
- [x] Run `dart format packages/training_engine/lib/src/models/training_state.dart packages/training_engine/lib/src/engine.dart lib/src/features/training_engine/training_engine_provider.dart lib/src/features/training_engine/training_engine_controller.dart lib/src/features/workout/workout_controller.dart test/features/training_engine/training_engine_provider_test.dart test/features/training_engine/training_engine_controller_test.dart test/controllers/routine_and_workout_controller_test.dart packages/training_engine/test/models/training_state_test.dart packages/training_engine/test/engine_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/models/training_state_test.dart test/engine_test.dart`.
- [x] Run `flutter test test/features/training_engine/training_engine_provider_test.dart test/features/training_engine/training_engine_controller_test.dart test/controllers/routine_and_workout_controller_test.dart`.
- [x] Commit the durable-ingestion changes.

**Acceptance Checks:**

- Completing a workout, losing the immediate engine sync, and reloading the provider still yields an engine state that includes the completed session.
- Restored engine state no longer hides missed sessions or deleted sessions.

---

## Task 4: Map Captured Profile Fields Into the Engine

**Category:** P0 training-engine profile correctness
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests through a non-interactive Codex run after local subagent slots became stale; GLM proxy review passed Task 4; local verification passed Dart format, diff check, and Flutter tests (`+19`). Commit: `93b9c2c`.

**Files:**

- Modify: `lib/src/features/training_engine/training_engine_adapter.dart`
- Modify: `packages/training_engine/lib/src/engine.dart`
- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Test: `test/features/training_engine/adapter_test.dart`
- Test: `test/features/training_engine/training_engine_provider_test.dart`
- Test: `packages/training_engine/test/models/training_state_test.dart`

**Functional Requirements:**

- `TrainingEngineAdapter.toUserProfile(AppState)` must use `AppState.age` when present and default to 25 only when absent.
- It must use `AppState.weight` when present and default to 75.0 kg only when absent.
- It must map `AppState.fitnessGoal` as:
  - `strength` -> `HypertrophyGoal.strength`
  - `hypertrophy` -> `HypertrophyGoal.hypertrophy`
  - `general_fitness`, `endurance`, `weight_loss`, and empty values -> `HypertrophyGoal.general`.
- It must preserve current `sex` mapping and existing default experience, available days, and max session duration until those fields exist in `AppState`.
- Restoring a saved engine state must not permanently keep stale profile demographics after the user edits age, weight, sex, or fitness goal.
- Existing fatigue/e1RM/session history must remain available after a profile update. When Task 3 reconciliation rebuilds from completed history, the rebuilt state must preserve the same completed-session-derived training facts.

**Steps:**

- [x] Replace the current adapter test that expects hard-coded age/bodyweight/goal with failing tests for captured age, weight, sex, and fitness goal mapping.
- [x] Add a provider test where saved engine state has an old profile and current `AppState` has new age, weight, sex, and goal.
- [x] Implement adapter mapping for age, weight, and fitness goal.
- [x] Add profile update or rebuild logic in provider load so restored state reflects current app profile.
- [x] Update `docs/app-feature-inventory.md` so it states profile fields are mapped into the engine after this task.
- [x] Run `dart format lib/src/features/training_engine/training_engine_adapter.dart lib/src/features/training_engine/training_engine_provider.dart test/features/training_engine/adapter_test.dart test/features/training_engine/training_engine_provider_test.dart`.
- [x] Run `flutter test test/features/training_engine/adapter_test.dart test/features/training_engine/training_engine_provider_test.dart`.
- [x] Commit the profile-mapping changes.

**Acceptance Checks:**

- Engine baseline estimates and fatigue decay use the age/bodyweight/goal values the app already captures.
- A user profile edit changes the next loaded engine profile without deleting valid completed-session history.

---

## Task 5: Remove Fake HealthKit Data From Empty or Denied Fetches

**Category:** P0 HealthKit/readiness correctness
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests through a non-interactive Codex run; GLM proxy review passed Task 5; local verification passed Dart format, diff check, package tests (`+77`), and Flutter tests (`+20`). Commit: `88b223d`.

**Files:**

- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Modify: `lib/src/features/training_engine/healthkit_data_source.dart` if richer fetch status is needed
- Modify: `packages/training_engine/lib/src/engine.dart`
- Test: `test/features/training_engine/training_engine_provider_test.dart`
- Test: `packages/training_engine/test/engine_test.dart`
- Test: `packages/training_engine/test/readiness/readiness_test.dart`
- Test: `test/features/dashboard/training_readiness_card_test.dart`

**Functional Requirements:**

- When `healthKitEnabled` is true and HealthKit returns empty sleep/HRV lists, the provider must not ingest `DemoSeedData.seedSleep()` or `DemoSeedData.seedHrv()`.
- Demo sleep/HRV records may be used only by explicit demo-data flows, not by an empty HealthKit fetch.
- The app must distinguish "no samples", "unavailable/unsupported platform", "authorization denied", and "fetch error" enough for provider tests to assert behavior. This can be done with a result type or deterministic fake data source methods.
- A stale HealthKit refresh that returns empty lists must not silently erase previously fetched sleep/HRV history unless the product explicitly shows "no current health data" and tests cover that choice.
- `lastHealthKitFetch` semantics must be deterministic: either stamp attempted fetches with a status, or avoid repeated tight-loop refetching after empty results.
- Dashboard readiness must show limited-data or unavailable state when health data is absent. It must not show demo-like recovery values after a denied/empty HealthKit fetch.

**Steps:**

- [x] Add failing provider tests for HealthKit enabled with empty sleep/HRV results.
- [x] Add failing provider tests for fake denied/unavailable/error cases.
- [x] Add a failing engine test for previous health data plus empty refresh.
- [x] Remove provider fallback to `DemoSeedData.seedSleep()` and `DemoSeedData.seedHrv()`.
- [x] Implement deterministic stale-refresh behavior that preserves or explicitly clears old records according to the functional requirements.
- [x] Update readiness card tests for no-health-data and limited-data display.
- [x] Update `docs/app-feature-inventory.md` to remove any "HealthKit demo fallback" language after the code fix.
- [x] Run `dart format lib/src/features/training_engine/training_engine_provider.dart lib/src/features/training_engine/healthkit_data_source.dart packages/training_engine/lib/src/engine.dart test/features/training_engine/training_engine_provider_test.dart packages/training_engine/test/engine_test.dart packages/training_engine/test/readiness/readiness_test.dart test/features/dashboard/training_readiness_card_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/engine_test.dart test/readiness/readiness_test.dart`.
- [x] Run `flutter test test/features/training_engine/training_engine_provider_test.dart test/features/dashboard/training_readiness_card_test.dart`.
- [x] Commit the HealthKit/readiness changes.

**Acceptance Checks:**

- Empty, denied, unavailable, or failing HealthKit fetches never create fake sleep/HRV readiness data.
- Readiness UI truthfully reflects absent health data.

---

## Task 6: Use Routine Targets in Visible Load Recommendations

**Category:** P0 recommendation correctness
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; GLM proxy review passed Task 6; local verification passed Dart format, diff check, Flutter tests (`+20`), and package recommendation tests (`+11`). Commit: `81a210a`.

**Files:**

- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Modify: `lib/src/features/workout/active_workout_screen.dart`
- Modify: `packages/training_engine/lib/src/engine.dart`
- Test: `test/features/training_engine/training_engine_ui_adapter_test.dart`
- Test: `test/features/training_engine/training_engine_provider_test.dart`
- Test: `test/features/workout/active_workout_suggestion_test.dart`
- Test: `packages/training_engine/test/progression/recommendation_test.dart`

**Functional Requirements:**

- The visible active-workout suggestion path must pass target reps from the current `RoutineExercise` into `TrainingEngine.recommendLoad` using `TargetParams`.
- For a routine exercise with `targetReps: 5`, the engine must evaluate progression against a 5-rep target range, not the default 10-12 or 8-12 movement target.
- The target RPE must be explicit. If the app has no routine-level target RPE, use the existing engine default of 8.0 and make that default visible in tests.
- Existing debug provider behavior may still request default recommendations by exercise id, but the active-workout UI must use routine-aware recommendation parameters.
- Weight prefill priority must remain deterministic: current-session previous set, then previous completed same-exercise set, then routine-aware engine suggestion, then blank.
- Recommendation tests must include a seeded strength routine case with 5-6 rep work that progresses when the routine target is met.

**Steps:**

- [x] Add a failing provider/widget test for routine target reps affecting recommendation direction and suggested weight.
- [x] Add a failing active-workout test for the prefill priority when previous app set and engine suggestion disagree.
- [x] Introduce a typed provider parameter such as exercise id plus target reps/target RPE, or another local pattern that passes `TargetParams` without stringly-typed parsing.
- [x] Update `ActiveWorkoutScreen` to call the routine-aware recommendation provider for the current prescription.
- [x] Keep the current exercise-id-only provider only for debug/default contexts that do not know the routine target.
- [x] Run `dart format lib/src/features/training_engine/training_engine_provider.dart lib/src/features/workout/active_workout_screen.dart test/features/training_engine/training_engine_provider_test.dart test/features/workout/active_workout_suggestion_test.dart packages/training_engine/test/progression/recommendation_test.dart`.
- [x] Run `flutter test test/features/training_engine/training_engine_provider_test.dart test/features/workout/active_workout_suggestion_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/progression/recommendation_test.dart`.
- [x] Commit the routine-target recommendation changes.

**Acceptance Checks:**

- Active workout suggestions respect routine prescriptions.
- A 5-rep routine no longer waits for a 10-12 rep default before recommending progression.

---

## Task 7: Fix Deload and Reduction Direction Labels

**Category:** P0 user-facing recommendation safety
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; GLM proxy review initially found a compile/import blocker and missing label-copy test, then passed after the orchestrator fixed and re-tested; local verification passed Dart format, diff check, Flutter adapter tests (`+11`), and package safety/recommendation tests (`+32`). Commit: `33437c3`.

**Files:**

- Modify: `lib/src/features/training_engine/training_engine_ui_adapter.dart`
- Modify: `lib/src/features/workout/active_workout_screen.dart`
- Test: `test/features/training_engine/training_engine_ui_adapter_test.dart`
- Test: `packages/training_engine/test/progression/safety_gates_test.dart`
- Test: `packages/training_engine/test/progression/recommendation_test.dart`

**Functional Requirements:**

- A recommendation that lowers the suggested weight below `previousWeightKg` must map to `EngineSuggestionDirection.down`, regardless of `PerformanceDelta.maintenance`.
- A safety gate with `GateAction.deload`, `GateAction.reduceLoad`, or `GateAction.suggestAlternative` must never display as "hold steady" in the active workout progression hint.
- A true maintain recommendation with unchanged suggested weight may display as hold.
- A progression recommendation with increased suggested weight must display as up.
- Direction mapping must be covered for high fatigue, ACWR danger, low readiness, clear maintain, and clear progression cases.

**Steps:**

- [x] Add failing UI-adapter tests for reduced suggested weights with `PerformanceDelta.maintenance`.
- [x] Add failing recommendation tests for fatigue over 60, fatigue over 80, ACWR danger, and readiness below 30.
- [x] Update `TrainingEngineUiAdapter.toWeightSuggestion` to derive direction from gate action and suggested-vs-previous weight; use `delta` only as display magnitude after direction is determined.
- [x] Update active-workout direction copy for the reduction, deload, alternative, maintain, and progression states.
- [x] Run `dart format lib/src/features/training_engine/training_engine_ui_adapter.dart lib/src/features/workout/active_workout_screen.dart test/features/training_engine/training_engine_ui_adapter_test.dart packages/training_engine/test/progression/safety_gates_test.dart packages/training_engine/test/progression/recommendation_test.dart`.
- [x] Run `flutter test test/features/training_engine/training_engine_ui_adapter_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/progression/safety_gates_test.dart test/progression/recommendation_test.dart`.
- [x] Commit the recommendation-label changes.

**Acceptance Checks:**

- Safety reductions are labeled as reductions/deloads in the UI.
- No safety-gated reduced load can be presented to the user as a steady/hold suggestion.

---

## Task 8: Select Best Estimated e1RM for e1RM History

**Category:** P1 engine formula correctness
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; orchestrator added missing weight and reps tie-breaker coverage; GLM proxy review passed Task 8; local verification passed Dart format, diff check, and package engine/e1RM tests (`+68`). Commit: `7f62db4`.

**Files:**

- Modify: `packages/training_engine/lib/src/engine.dart`
- Test: `packages/training_engine/test/engine_test.dart`
- Test: `packages/training_engine/test/e1rm/composite_estimator_test.dart`

**Functional Requirements:**

- Within one engine session, e1RM history must store the set that produces the highest composite e1RM for an exercise.
- `lastTopSets` may continue to store the heaviest working set for previous-weight prefill and load progression context.
- If two sets produce effectively equal e1RM, the tie-breaker must be deterministic: prefer higher confidence, then heavier weight, then higher reps.
- Existing rolling e1RM behavior must remain stable after the best estimate is chosen.

**Steps:**

- [x] Add a failing engine test where a lighter higher-rep set has higher composite e1RM than the heaviest set.
- [x] Add a failing tie-breaker test for equal e1RM values.
- [x] Update e1RM selection in `TrainingEngine.ingestSession` while preserving `lastTopSets`.
- [x] Run `dart format packages/training_engine/lib/src/engine.dart packages/training_engine/test/engine_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/engine_test.dart test/e1rm/composite_estimator_test.dart`.
- [x] Commit the e1RM selection changes.

**Acceptance Checks:**

- e1RM history represents the best estimated strength performance in a session.
- Previous-weight behavior still uses the intended top working set.

---

## Task 9: Make ACWR Daily

**Category:** P1 load-model correctness
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; orchestrator tightened remaining debug wording; GLM proxy review passed Task 9; local verification passed Dart format, diff check, wording scan, and package ACWR/engine tests (`+84`). Commit: `8c4a66b`.

**Files:**

- Modify: `packages/training_engine/lib/src/engine.dart`
- Modify: `packages/training_engine/lib/src/acwr/ewma.dart`
- Modify: `packages/training_engine/lib/src/models/daily_load.dart`
- Test: `packages/training_engine/test/acwr/acwr_test.dart`
- Test: `packages/training_engine/test/engine_test.dart`

**Functional Requirements:**

- `DailyLoad` must mean aggregated local-calendar-day load. Multiple sessions on the same local calendar date must aggregate into one daily load before ACWR calculation.
- Ingesting two sessions on the same day must yield the same ACWR state as ingesting one combined day-load with the same total volume.
- Rebuilding from completed history must produce deterministic daily-load and ACWR state regardless of session insertion order.
- Debug labels, inventory wording, and exposed model descriptions must describe true daily aggregation.

**Steps:**

- [x] Add a failing ACWR test comparing two same-day sessions against one combined same-day load.
- [x] Add a failing engine bootstrap test with out-of-order same-day sessions.
- [x] Implement daily aggregation and deterministic EWMA recomputation from the aggregate daily-load list.
- [x] Update debug labels, inventory wording, and exposed model descriptions to describe true daily aggregation.
- [x] Run `dart format packages/training_engine/lib/src/engine.dart packages/training_engine/lib/src/acwr/ewma.dart packages/training_engine/lib/src/models/daily_load.dart packages/training_engine/test/acwr/acwr_test.dart packages/training_engine/test/engine_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/acwr/acwr_test.dart test/engine_test.dart`.
- [x] Commit the ACWR aggregation changes.

**Acceptance Checks:**

- ACWR is a daily workload metric rather than an accidental per-session metric.
- Same-day multiple sessions no longer inflate acute/chronic workload updates.

---

## Task 10: Define and Implement Timed-Exercise Engine Behavior

**Category:** P1 timed workout correctness
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; GLM proxy review passed Task 10 with JSON compatibility and mixed-session checks; local verification passed Dart format, diff check, Flutter adapter/provider/integration tests (`+33`), and package engine/fatigue tests (`+65`). Commit: `3041d88`.

**Files:**

- Modify: `lib/src/features/training_engine/training_engine_adapter.dart`
- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Modify: `packages/training_engine/lib/src/models/logged_set.dart`
- Modify: `packages/training_engine/lib/src/engine.dart`
- Modify: `packages/training_engine/lib/src/fatigue/impulse_calculator.dart`
- Test: `test/features/training_engine/adapter_test.dart`
- Test: `test/features/training_engine/training_engine_provider_test.dart`
- Test: `packages/training_engine/test/engine_test.dart`
- Test: `packages/training_engine/test/fatigue/impulse_calculator_test.dart`

**Functional Requirements:**

- Timed completed sets must not be silently ignored by engine ingestion.
- Timed sets must contribute to muscle fatigue and readiness/load context through a duration-based stress calculation.
- Timed sets must not produce e1RM estimates or strength load recommendations in this task.
- Live active-workout heatmap preview must include timed exercise fatigue contribution when a timed set has duration and mapped muscles.
- Timed-only sessions must count as ingested sessions for durability/reconciliation if they contribute to fatigue/load state.
- Product docs must say exactly which engine outputs timed exercises affect.

**Steps:**

- [x] Add failing adapter tests for a timed-only completed session becoming an engine session with timed stress information.
- [x] Add failing engine/fatigue tests showing a plank-like timed set increases core fatigue but does not create an e1RM entry.
- [x] Add failing provider test for live heatmap preview with a timed active set.
- [x] Implement a timed-set representation in the engine boundary without breaking existing strength `LoggedSet` JSON compatibility.
- [x] Update fatigue impulse calculation to support duration-based stress for timed sets.
- [x] Update `docs/app-feature-inventory.md` with the final timed-engine behavior.
- [x] Run `dart format lib/src/features/training_engine/training_engine_adapter.dart lib/src/features/training_engine/training_engine_provider.dart packages/training_engine/lib/src/models/logged_set.dart packages/training_engine/lib/src/engine.dart packages/training_engine/lib/src/fatigue/impulse_calculator.dart test/features/training_engine/adapter_test.dart test/features/training_engine/training_engine_provider_test.dart packages/training_engine/test/engine_test.dart packages/training_engine/test/fatigue/impulse_calculator_test.dart`.
- [x] Run `flutter test test/features/training_engine/adapter_test.dart test/features/training_engine/training_engine_provider_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/engine_test.dart test/fatigue/impulse_calculator_test.dart`.
- [x] Commit the timed-exercise engine changes.

**Acceptance Checks:**

- Timed workout data influences fatigue/readiness where appropriate.
- Timed workout data does not create bogus strength estimates.

---

## Task 11: Align App RPE Range With Engine Contract

**Category:** P1 app/engine scale consistency
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; GLM proxy review passed Task 11 with explicit no-silent-clamp and timed-set interaction checks; local verification passed Dart format, diff check, Flutter RPE/adapter tests (`+12`), and package model tests (`+14`). Commit: `949ac6a`.

**Files:**

- Modify: `lib/src/data/models/completed_set.dart`
- Modify: `lib/src/features/workout/active_workout_screen.dart`
- Modify: `lib/src/features/training_engine/training_engine_adapter.dart`
- Modify: `packages/training_engine/lib/src/models/logged_set.dart`
- Test: `test/features/workout/active_workout_rpe_test.dart`
- Test: `test/features/training_engine/adapter_test.dart`
- Test: `packages/training_engine/test/models/session_models_test.dart`

**Functional Requirements:**

- User-entered RPE values must not be silently changed during engine mapping.
- The supported strength RPE contract must be 5-10 from active-workout UI through engine ingestion.
- Active workout UI, `CompletedSet` documentation, adapter validation, `LoggedSet`, and e1RM formulas must all enforce the same 5-10 contract.
- Legacy completed sets with RPE below 5 must remain stored in app history but must be excluded from engine e1RM estimation through an explicit, tested migration/adapter rule.

**Steps:**

- [x] Add failing tests that expose the current silent clamp from app RPE 1-4 to engine RPE 5.
- [x] Implement the 5-10 strength RPE contract across UI, app model docs, adapter validation, engine model validation, and e1RM estimation.
- [x] Update model docs and validation to match the 5-10 contract.
- [x] Update adapter mapping so no user-provided RPE is silently mutated without a visible migration rule.
- [x] Run `dart format lib/src/data/models/completed_set.dart lib/src/features/workout/active_workout_screen.dart lib/src/features/training_engine/training_engine_adapter.dart packages/training_engine/lib/src/models/logged_set.dart test/features/workout/active_workout_rpe_test.dart test/features/training_engine/adapter_test.dart packages/training_engine/test/models/session_models_test.dart`.
- [x] Run `flutter test test/features/workout/active_workout_rpe_test.dart test/features/training_engine/adapter_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/models/session_models_test.dart`.
- [x] Commit the RPE contract changes.

**Acceptance Checks:**

- There is one documented RPE contract from UI through engine.
- A user-entered low RPE cannot be silently converted into a harder set.

---

## Task 12: Close Heatmap Mapping and Muscle-Gating Gaps

**Category:** P1 fatigue visibility and recommendation safety
**Status:** Completed 2026-05-11. GPT-5.5 implementer left usable code and tests despite a silent-close handoff; GLM proxy review passed Task 12; local verification passed Dart format, diff check, Flutter heatmap tests (`+14`), and package muscle/engine tests (`+74`). Commit: `d381042`.

**Files:**

- Modify: `lib/src/features/training_engine/training_engine_ui_adapter.dart`
- Modify: `packages/training_engine/lib/src/engine.dart`
- Modify: `packages/training_engine/lib/src/fatigue/muscle_registry.dart`
- Test: `test/features/training_engine/training_engine_ui_adapter_test.dart`
- Test: `packages/training_engine/test/fatigue/muscle_registry_test.dart`
- Test: `packages/training_engine/test/engine_test.dart`
- Test: `test/features/dashboard/muscle_heatmap_card_test.dart`

**Functional Requirements:**

- Every canonical muscle in `defaultMuscles` must map to at least one deterministic `flutter_body_heatmap` `Muscle` through a tested closest-region mapping.
- Unknown or custom muscles must not crash heatmap mapping.
- Load recommendation safety gates must consider all primary muscles for an exercise, not only the first primary muscle.
- High-coefficient synergists must influence recommendation gating if their fatigue is materially higher than the primary muscles.
- The selected recommendation fatigue input must be deterministic and covered by tests.

**Steps:**

- [x] Add a failing heatmap adapter coverage test over every `defaultMuscles` entry.
- [x] Add failing recommendation tests for multiple primary muscles and high-fatigue synergists.
- [x] Update the UI adapter mapping so every `defaultMuscles` entry maps to at least one heatmap muscle.
- [x] Update `TrainingEngine.recommendLoad` to use max or weighted fatigue across relevant muscle activations rather than first-primary only.
- [x] Run `dart format lib/src/features/training_engine/training_engine_ui_adapter.dart packages/training_engine/lib/src/engine.dart packages/training_engine/lib/src/fatigue/muscle_registry.dart test/features/training_engine/training_engine_ui_adapter_test.dart packages/training_engine/test/fatigue/muscle_registry_test.dart packages/training_engine/test/engine_test.dart test/features/dashboard/muscle_heatmap_card_test.dart`.
- [x] Run `flutter test test/features/training_engine/training_engine_ui_adapter_test.dart test/features/dashboard/muscle_heatmap_card_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/fatigue/muscle_registry_test.dart test/engine_test.dart`.
- [x] Commit the heatmap and gating changes.

**Acceptance Checks:**

- Engine fatigue is visible when the heatmap package can represent it.
- Recommendation safety no longer ignores fatigued primary/synergist muscles beyond the first primary muscle.

---

## Task 13: Emit Readiness Flags for Sleep and Resting-Heart-Rate Risks

**Category:** P1 readiness correctness
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed red-green code and tests; GLM proxy review passed Task 13 with API-compatibility and dashboard-copy checks; local verification passed Dart format, diff check, package readiness tests (`+33`), and dashboard widget tests (`+5`). Commit: `bc71043`.

**Files:**

- Modify: `packages/training_engine/lib/src/readiness/composite_readiness.dart`
- Modify: `packages/training_engine/lib/src/readiness/sleep_scorer.dart`
- Modify: `packages/training_engine/lib/src/readiness/hrv_scorer.dart`
- Modify: `packages/training_engine/lib/src/engine.dart`
- Modify: `lib/src/features/dashboard/training_readiness_card.dart`
- Test: `packages/training_engine/test/readiness/readiness_test.dart`
- Test: `test/features/dashboard/training_readiness_card_test.dart`

**Functional Requirements:**

- `ReadinessFlag.acuteSleepDeprivation` must be emitted when recent sleep data crosses the existing scorer's acute sleep deprivation threshold.
- `ReadinessFlag.risingRestingHr` must be emitted when HRV/resting-heart data indicates the existing rising resting HR condition.
- Existing ACWR danger and cold-start flags must keep working.
- Dashboard readiness must expose these flags with user-facing text that does not overclaim medical diagnosis.
- Limited-data confidence must remain honest when sleep or HRV data is missing.

**Steps:**

- [x] Add failing pure engine readiness tests for low sleep and rising resting HR flags.
- [x] Add failing dashboard readiness card tests for the new flag messages.
- [x] Return enough structured scorer information for `computeReadiness` to emit the flags.
- [x] Update dashboard rendering for the new flags.
- [x] Run `dart format packages/training_engine/lib/src/readiness/composite_readiness.dart packages/training_engine/lib/src/readiness/sleep_scorer.dart packages/training_engine/lib/src/readiness/hrv_scorer.dart packages/training_engine/lib/src/engine.dart lib/src/features/dashboard/training_readiness_card.dart packages/training_engine/test/readiness/readiness_test.dart test/features/dashboard/training_readiness_card_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/readiness/readiness_test.dart`.
- [x] Run `flutter test test/features/dashboard/training_readiness_card_test.dart`.
- [x] Commit the readiness-flag changes.

**Acceptance Checks:**

- Readiness flags listed in engine enums are actually emitted when their conditions occur.
- Dashboard copy remains fitness guidance, not medical advice.

---

## Task 14: Make Smart Planner Adaptation Claims True

**Category:** P2 planner/product consistency
**Status:** Completed 2026-05-11. GPT-5.5 implementer completed the engine-aware planner path; the orchestrator removed the silent engine-context fallback, updated async Smart Planner call sites and adoption tests, and GLM proxy review passed Task 14. Local verification passed Dart format on touched Dart files, diff check, focused Smart Planner tests (`+17`), package planner tests (`+27`), and focused analyzer checks. Commit: `65bd56d`.

**Files:**

- Modify: `lib/src/features/smart_planner/smart_planner_controller.dart`
- Modify: `lib/src/features/smart_planner/planner_registry_adapter.dart`
- Modify: `lib/src/features/smart_planner/smart_planner_screen.dart`
- Modify: `lib/src/features/smart_planner/widgets/plan_preview.dart`
- Modify: `lib/src/data/models/routine_exercise.dart`
- Modify: `packages/training_engine/lib/src/planner/session_generator.dart`
- Modify: `docs/app-feature-inventory.md`
- Test: `test/features/smart_planner/smart_planner_adoption_test.dart`
- Test: `test/features/smart_planner/smart_planner_controller_test.dart`
- Test: `test/features/smart_planner/smart_planner_integration_test.dart`
- Test: `packages/training_engine/test/planner/session_generator_test.dart`
- Test: `packages/training_engine/test/planner/dynamic_adjustments_test.dart`

**Functional Requirements:**

- Smart Planner must read current training engine fatigue/readiness/history and alter the generated plan accordingly.
- At minimum, high-fatigue muscles must reduce, delay, or substitute relevant exercises in generated sessions.
- Adopted routines must carry enough metadata for tests to prove the generated plan used engine context.
- Smart Planner docs and UI copy must describe the tested engine-aware adaptation behavior.

**Steps:**

- [x] Add failing tests for high-fatigue engine state affecting Smart Planner generation.
- [x] Implement engine-aware planner input through the controller and planner adapter.
- [x] Update docs/UI to describe the implemented engine-aware adaptation.
- [x] Update Smart Planner tests and inventory wording.
- [x] Run `dart format lib/src/data/models/routine_exercise.dart lib/src/features/smart_planner/smart_planner_controller.dart lib/src/features/smart_planner/planner_registry_adapter.dart lib/src/features/smart_planner/smart_planner_screen.dart lib/src/features/smart_planner/widgets/plan_preview.dart packages/training_engine/lib/src/planner/session_generator.dart test/features/smart_planner/smart_planner_adoption_test.dart test/features/smart_planner/smart_planner_controller_test.dart test/features/smart_planner/smart_planner_integration_test.dart packages/training_engine/test/planner/session_generator_test.dart packages/training_engine/test/planner/dynamic_adjustments_test.dart`.
- [x] Run `flutter test test/features/smart_planner/smart_planner_controller_test.dart test/features/smart_planner/smart_planner_integration_test.dart test/features/smart_planner/smart_planner_adoption_test.dart`.
- [x] Run `cd packages/training_engine && dart test test/planner/session_generator_test.dart test/planner/dynamic_adjustments_test.dart`.
- [x] Commit the Smart Planner consistency changes.

**Acceptance Checks:**

- Smart Planner behavior and wording agree on engine-aware adaptation.
- Code and tests prove current-fatigue adaptation before any screen or doc describes it.

---

## Task 15: Align Progress Analytics With the Engine

**Category:** P2 analytics consistency
**Status:** Completed 2026-05-11. GPT-5.5 implementer moved Progress and Dashboard current/rolling e1RM display to engine-owned rolling e1RM values; the orchestrator localized the dashboard label and removed analyzer noise in the touched provider test; GLM proxy review passed Task 15. Local verification passed Dart format on touched Dart files, diff check, focused Progress/provider tests (`+27`), focused analyzer checks, and web E2E. Commit: `513cd4f`.

**Files:**

- Modify: `lib/src/features/dashboard/dashboard_screen.dart`
- Modify: `lib/src/features/dashboard/persistent_start_session.dart`
- Modify: `lib/src/features/progress/progress_service.dart`
- Modify: `lib/src/features/progress/progress_screen.dart`
- Modify: `lib/src/features/training_engine/training_engine_provider.dart`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_fr.arb`
- Modify: `lib/l10n/app_localizations.dart`
- Modify: `lib/l10n/app_localizations_en.dart`
- Modify: `lib/l10n/app_localizations_fr.dart`
- Modify: `docs/app-feature-inventory.md`
- Test: `test/services/progress_service_test.dart`
- Test: `test/features/training_engine/training_engine_provider_test.dart`
- Verify: `integration_test/app_test.dart` through `tool/ci/run_web_e2e.sh`

**Functional Requirements:**

- Progress e1RM analytics must read `TrainingEngine.currentE1rm` or `TrainingState.e1rmHistory` through providers and match engine rolling behavior.
- Progress must not compute a competing direct e1RM value for any number labeled as current or rolling e1RM.
- Timed PR display must remain in Progress and must not be confused with strength e1RM.
- Dashboard recent PR/progress snapshots must remain consistent after the wording/source change.

**Steps:**

- [x] Add failing tests that compare Progress e1RM output against engine state.
- [x] Update Progress service/provider wiring to read engine state for current or rolling e1RM.
- [x] Update docs and UI copy to identify engine state as the source for current or rolling e1RM.
- [x] Run `dart format lib/src/features/dashboard/dashboard_screen.dart lib/src/features/dashboard/persistent_start_session.dart lib/src/features/progress/progress_service.dart lib/src/features/progress/progress_screen.dart lib/src/features/training_engine/training_engine_provider.dart lib/l10n/app_localizations.dart lib/l10n/app_localizations_en.dart lib/l10n/app_localizations_fr.dart test/services/progress_service_test.dart test/features/training_engine/training_engine_provider_test.dart`.
- [x] Run `flutter test test/services/progress_service_test.dart test/features/training_engine/training_engine_provider_test.dart`.
- [x] Run `bash tool/ci/run_web_e2e.sh`.
- [x] Commit the Progress analytics changes.

**Acceptance Checks:**

- A user can tell that current or rolling Progress e1RM comes from persisted engine state.
- Tests lock engine state as the source of truth.

---

## Task 16: Verify iOS Watch and Live Activity Runtime Wiring

**Category:** P2 native integration verification
**Status:** Completed 2026-05-12. GPT-5.5 implementers added source-level Watch/Live Activity tests, fixed Watch snapshots to send `null` when no engine suggestion exists, and added an equivalent device-lab native runtime smoke for the paired `17 Pro + watch 26.3` simulator. GLM proxy review passed Task 16 and accepted the paired-simulator smoke under the plan's equivalent-device-lab requirement while preserving the physical iPhone/Watch blocker note. Local verification passed Dart format, diff check, focused Watch/Live Activity tests (`+16`), focused analyzer checks, `flutter build ios --debug --no-codesign`, and `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/native_runtime_wiring_test.dart -d FDFE9890-3387-4E10-9BEE-1EC387EF14E5 --debug --no-pub`. Commit: recorded in git history after this ledger update.

**Files:**

- Modify: `lib/main.dart`
- Modify: `lib/src/features/watch/watch_sync_service.dart`
- Modify: `lib/src/features/live_activity/workout_live_activity_service.dart`
- Modify: `ios/Runner/StrengthLiveActivityManager.swift`
- Modify: `ios/WatchSessionManager.swift`
- Test: `test/features/watch/watch_sync_service_test.dart`
- Test: `test/features/live_activity/workout_live_activity_service_test.dart`
- Test: `integration_test/native_runtime_wiring_test.dart`
- Modify: `docs/app-feature-inventory.md`

**Functional Requirements:**

- Keep the current fact that `lib/main.dart` initializes Watch and Live Activity services on non-web iOS.
- Services must initialize exactly once per app process and must tolerate method-channel failures without crashing app startup.
- Watch snapshots must include engine suggested weights when available and must omit or null them when no engine suggestion exists.
- Watch-originated quick set logging must be verified with fake method/event channels in Dart tests.
- Live Activity payloads must include active workout state, current exercise, set progress, rest timer, and session metadata when an active session exists.
- Runtime verification on physical iPhone/Apple Watch or an equivalent device-lab run must prove Watch and Live Activity wiring works beyond Dart fake-channel tests.
- Docs must record the passing runtime verification device/run, date, and tested flows.

**Steps:**

- [x] Add or update tests proving initialization is idempotent.
- [x] Add or update fake-channel tests for watch snapshot suggested weights.
- [x] Add or update fake-channel tests for Live Activity payload shape during active workout and after workout end.
- [x] Run `flutter test test/features/watch/watch_sync_service_test.dart test/features/live_activity/workout_live_activity_service_test.dart`.
- [x] Run `flutter build ios --debug --no-codesign`.
- [x] Run and record the physical iPhone/Apple Watch or device-lab smoke verification for Watch sync and Live Activity updates.
- [x] Update `docs/app-feature-inventory.md` with the passing verification device/run, date, and tested flows.
- [x] Commit the native wiring verification changes.

**Acceptance Checks:**

- Source-level initialization is tested.
- iOS/watchOS runtime wiring is verified on hardware or an equivalent device-lab run.

---

## Task 17: Verify Web/PWA and Legal Asset Claims

**Category:** P2 web documentation and smoke coverage

**Files:**

- Modify: `web/manifest.json`
- Modify: `web/privacy.html`
- Modify: `web/terms.html`
- Modify: `web/index.html`
- Modify: `docs/app-feature-inventory.md`
- Test: `test/core/legal_links_test.dart`
- Test: `test/web/web_assets_test.dart`

**Functional Requirements:**

- Inventory must claim PWA manifest and static privacy/terms pages only after tests prove the current files are present and linked correctly.
- Settings legal links must resolve to the intended privacy and terms destinations for web.
- The web manifest must identify the app as Kotrana, include installable icons, and avoid stale product wording.
- Privacy/terms pages must match source-supported HealthKit behavior and must not claim unsupported HealthKit writes.

**Steps:**

- [ ] Add tests for `legal_links.dart` that cover the web legal URLs.
- [ ] Verify `web/manifest.json`, `web/privacy.html`, and `web/terms.html` content against current product capabilities.
- [ ] Update docs or web static copy where claims are stale.
- [ ] Run `flutter test test/core/legal_links_test.dart`.
- [ ] Run `flutter build web`.
- [ ] Commit the web/PWA verification changes.

**Acceptance Checks:**

- Web asset claims in inventory are backed by current files.
- Legal/static copy does not overstate native or health-data behavior.

---

## Task 18: Strengthen Web E2E Tests for Shortcut-Backed Flows

**Category:** P2 E2E coverage completeness

**Files:**

- Modify: `integration_test/app_test.dart`
- Modify: `integration_test/e2e_helpers.dart`
- Modify: `docs/e2e-web-flow-inventory.md`
- Test command: `bash tool/ci/run_web_e2e.sh`

**Functional Requirements:**

- Smart Planner generation/adoption must be covered through visible wizard interactions, not only route rendering plus injected adopted state.
- Routine archive behavior must be covered through the visible UI.
- Routine-group completion advancement must be covered by completing a workout through visible app flows.
- Timed set logging/update/summary must remain covered by visible interactions.
- No target-flow assertion may depend on direct state/controller shortcuts after this task.
- The E2E suite must remain deterministic and pass on web.

**Steps:**

- [ ] Add failing or currently-missing UI-driven E2E coverage for Smart Planner wizard generation and adoption.
- [ ] Convert the highest-value controller/state shortcut flows to visible UI flows.
- [ ] Remove state/controller shortcuts from the target-flow assertions covered by this task.
- [ ] Run `dart format integration_test/app_test.dart integration_test/e2e_helpers.dart`.
- [ ] Run `flutter analyze integration_test/app_test.dart integration_test/e2e_helpers.dart`.
- [ ] Run `bash tool/ci/run_web_e2e.sh`.
- [ ] Use Browser against the local web build when a web UI failure needs visual diagnosis.
- [ ] Commit the E2E coverage changes.

**Acceptance Checks:**

- The E2E docs and actual tests agree.
- Smart Planner adoption has a real browser/user-path test.

---

## Task 19: Final Verification and Completion Ledger

**Category:** Release-quality verification

**Files:**

- Modify: `docs/superpowers/plans/2026-05-11-gpt-pro-audit-remediation-plan.md`
- Modify: `docs/app-feature-inventory.md`
- Modify: `docs/e2e-web-flow-inventory.md`

**Functional Requirements:**

- Every task in this plan must be marked complete only after its own tests pass.
- Final verification must include package tests, Flutter unit/widget tests for touched areas, analyzer checks, and web E2E tests.
- The final inventory must match the implemented behavior after all code tasks.
- The final E2E inventory must match the implemented tests after all E2E tasks.
- No test skip may be introduced as a way to pass verification.

**Steps:**

- [ ] Run `cd packages/training_engine && dart test`.
- [ ] Run `flutter test`.
- [ ] Run `flutter analyze`.
- [ ] Run `bash tool/ci/run_web_e2e.sh`.
- [ ] Open the web app with Browser and verify the affected flows render and navigate.
- [ ] Mark completed tasks in this plan with dates and commit hashes.
- [ ] Commit the final ledger/doc updates.

**Acceptance Checks:**

- All local verification commands pass.
- The repository contains a truthful feature inventory, truthful E2E coverage inventory, and implemented fixes for GPT Pro's P0/P1/P2 audit categories.
