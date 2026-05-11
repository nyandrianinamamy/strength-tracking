# Follow-Up Request for GPT Pro

## Context

We are auditing the functional correctness of the training engine in the StrengthApp/Kotrana Flutter repository.

The app appears to contain a local pure Dart package, `packages/training_engine`, plus host-app integration under `lib/src/features/training_engine/`. The intended product idea is that training recommendations/readiness/fatigue are based on previous completed workout sets and Apple Health-style recovery data such as sleep and HRV.

I need you to verify whether that is actually true in the current source, and whether the implementation is functionally correct enough to trust.

## Question

Please audit the functional correctness of the training engine and its app integration.

Focus on these questions:

1. Does the training engine actually use previous completed sets to compute useful outputs?
   - e1RM / strength baseline.
   - localized muscle fatigue.
   - daily load and ACWR.
   - load recommendations / suggested weights.
   - dashboard or workout UI suggestions.
2. Does the training engine actually use Apple Health / HealthKit-style data?
   - sleep records.
   - HRV records.
   - readiness scoring.
   - HealthKit fetch/authorization wiring in the app.
   - whether this is production-wired, stubbed, partial, or only modeled in the pure engine.
3. Are the formulas and data flows internally consistent?
   - set/session mapping from app models to engine models.
   - RPE fallback and estimation behavior.
   - timed exercise handling.
   - exercise registry matching and synthetic exercise mapping.
   - primary vs secondary muscle contribution.
   - fatigue decay and cumulative fatigue.
   - progression safety gates and deload/maintain/increase logic.
4. Are there bugs, gaps, or misleading UI/product claims?
   - stale or placeholder profile defaults.
   - HealthKit toggle behavior vs actual data ingestion.
   - engine state persistence and bootstrap from historical sessions.
   - async failure modes when completing workouts.
   - whether suggestions shown in active workout/watch/dashboard really come from the engine.
5. What tests should be added or strengthened?

## Attached Sources

The archive `gpt-pro-training-engine-functional-audit-sources.zip` contains:

- `docs/gpt-pro-training-engine-functional-audit-prompt.md`: this prompt.
- `docs/app-feature-inventory.md`: current feature inventory, for context.
- `docs/e2e-web-flow-inventory.md`: current web E2E flow inventory, for context.
- `docs/ROADMAP.md` and `docs/ISSUE.md`: roadmap/planned-feature context.
- `docs/research/Algorithmic Modeling for Hypertrophy-Focused Resistance Training_ Load Auto-Regulation, Fatigue Decay, and 1RM Estimation.md`: design/research background for the intended algorithm.
- `pubspec.yaml`: app dependency surface.
- `lib/src/data/models/*.dart`: app data models for exercises, routines, completed sets, and sessions.
- `lib/src/data/seed/demo_seed_data.dart`: seeded exercise/routine/session data.
- `lib/src/features/workout/workout_controller.dart`: completed sessions are finalized here.
- `lib/src/features/workout/active_workout_screen.dart`: active workout UI and suggested weight usage.
- `lib/src/features/workout/workout_summary_screen.dart`: completed workout summary behavior.
- `lib/src/features/progress/progress_service.dart` and `progress_screen.dart`: PR/e1RM/progress outputs.
- `lib/src/features/dashboard/training_readiness_card.dart`, `dashboard_screen.dart`, and `muscle_heatmap_card.dart`: user-visible readiness/fatigue surfaces.
- `lib/src/features/training_engine/*.dart`: app-side adapter, controller, provider, HealthKit source, state repository, debug screen, and UI adapter.
- `lib/src/features/smart_planner/*.dart` and widgets: Smart Planner use of the training engine planner.
- `lib/src/features/watch/watch_sync_service.dart`: watch snapshot and suggested-weight flow.
- `packages/training_engine/lib/**`: pure training engine implementation.
- `packages/training_engine/test/**`: existing package tests.
- `integration_test/app_test.dart` and `integration_test/e2e_helpers.dart`: current web integration coverage.

Please cite attached filenames/paths for every claim.

## Known Facts and Caveats

- A local web E2E suite passed, but it does not prove native HealthKit/watch runtime correctness.
- The previous inventory intentionally caveated HealthKit/native surfaces as source-present but not runtime-verified.
- The app has roadmap items that still list progressive overload suggestions and HealthKit compliance/release testing as incomplete; check whether that conflicts with implemented engine code.
- The engine may have pure package support for HealthKit-style data even if app-level HealthKit ingestion is incomplete.
- Do not assume Apple Health data is actually being fetched on device unless the attached source shows it.

## Constraints

- Use only attached sources.
- Do not assume missing runtime behavior.
- Distinguish:
  - pure-engine capability;
  - app-side wiring;
  - visible user-facing behavior;
  - tested behavior;
  - planned/incomplete behavior.
- Do not rewrite app code; this is an audit.

## Desired Output

Please return:

1. A verdict table:
   - Area.
   - Verdict: correct / likely correct / partial / broken / unverified.
   - Source evidence.
   - Functional risk.
   - Recommended fix or test.
2. A data-flow trace from completed workout set -> engine state -> user-visible output.
3. A data-flow trace from Apple Health / sleep / HRV -> engine readiness -> user-visible output.
4. A list of concrete bugs or suspicious gaps with file/path citations.
5. A prioritized test plan for the training engine and host-app integration.
6. A short answer to: "Can we honestly say the app has a training engine based on previous sets plus Apple Health data?"

