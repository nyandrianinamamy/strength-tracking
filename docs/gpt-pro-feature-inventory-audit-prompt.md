# Request for GPT Pro

## Context

I am auditing the current feature surface of a Flutter app repository named StrengthApp/Kotrana. A local feature inventory has been created in `docs/app-feature-inventory.md`. I need you to verify whether that inventory is correct, complete, and appropriately caveated based only on the attached source files.

The app is a strength training tracker for Flutter web and iOS. It includes exercise/routine/workout tracking, routine groups, a Smart Planner backed by a local `training_engine` package, progress analytics, settings/account/data controls, web/PWA surfaces, and native iOS/Apple Watch/Live Activity code.

## Question

Please verify the correctness of `docs/app-feature-inventory.md` against the attached sources.

Specifically:

1. Identify any feature listed in the inventory that is overstated, unsupported, or incorrectly described.
2. Identify any implemented feature present in the attached sources but missing from the inventory.
3. Identify any planned or partially implemented feature that the inventory should caveat more clearly.
4. Check whether the distinction between web-visible features, iOS/watchOS native integrations, debug surfaces, and roadmap/planned items is accurate.
5. Recommend precise edits to `docs/app-feature-inventory.md`.

## Attached Sources

The archive `gpt-pro-feature-inventory-sources.zip` contains:

- `docs/app-feature-inventory.md`: the inventory to audit.
- `docs/e2e-web-flow-inventory.md`: existing web E2E flow inventory and coverage notes.
- `docs/ROADMAP.md` and `docs/ISSUE.md`: roadmap and historical feature/bug notes.
- `pubspec.yaml`: app metadata and dependency surface.
- `lib/src/app/router.dart`: route map and redirect behavior.
- `lib/src/core/app_bootstrap.dart`: Firebase/local fallback/bootstrap/migration behavior.
- `lib/src/core/app_state_controller.dart`: app state provider.
- `lib/src/core/debug_surface.dart`, `lib/src/core/legal_links.dart`, `lib/src/core/utils/force_update*.dart`: debug/legal/web utility surfaces.
- `lib/src/data/models/*.dart`: persisted data model.
- `lib/src/data/repository/app_state_repository.dart`: Firestore/SharedPreferences repositories.
- `lib/src/data/seed/demo_seed_data.dart`: seeded exercises, routines, groups, and sessions.
- `lib/src/features/**`: app feature screens, controllers, services, and platform bridges.
- `lib/l10n/app_en.arb` and `lib/l10n/app_fr.arb`: user-visible localized strings.
- `integration_test/app_test.dart` and `integration_test/e2e_helpers.dart`: current automated web E2E coverage.
- `packages/training_engine/lib/**`: local training engine capabilities used by the app and Smart Planner.
- Selected iOS/watchOS Swift files under `ios/Runner`, `ios/StrengthAppLiveActivity`, `ios/WatchSessionManager.swift`, and `ios/StrengthAppWatch Watch App`.

Please cite attached filenames/paths for every correction or missing-feature claim.

## Known Facts and Caveats

- The local Flutter web E2E suite passed with `bash tool/ci/run_web_e2e.sh`.
- The inventory intentionally separates implemented source-level capabilities from roadmap items.
- Native iOS/watchOS features are present in source, but they were not runtime-verified in this task.
- Third-party auth popups are not treated as fully exercised by web E2E; tests cover mocked failure paths.
- Do not assume App Store readiness or native device correctness unless directly supported by attached source.
- Do not infer product features solely from package dependencies; distinguish dependency presence from visible app behavior.

## Constraints

- Use only the attached sources.
- Do not assume missing implementation details.
- Distinguish verified source facts from interpretation.
- Do not rewrite marketing copy.
- Do not propose new product ideas except where needed to clarify a missing caveat.

## Desired Output

Please return:

1. A table of inventory inaccuracies:
   - Inventory claim.
   - Verdict: correct / overstated / incomplete / missing caveat / wrong.
   - Source evidence.
   - Recommended exact edit.
2. A list of missing implemented features, if any, with source paths.
3. A list of features that should be moved to "planned/partial/native-only/debug-only", if any.
4. A short final confidence assessment of the inventory.

