# App Feature Inventory

Date: 2026-05-11

This inventory describes the features present in the current StrengthApp/Kotrana source tree. It separates implemented app behavior from platform-specific integrations and planned work so later reviews do not overstate what the app can do today.

## Source Basis

- Routing and navigation: `lib/src/app/router.dart`, `lib/src/shared/widgets/app_shell_scaffold.dart`.
- State and persistence: `lib/src/data/models/*`, `lib/src/core/app_state_controller.dart`, `lib/src/core/app_bootstrap.dart`, `lib/src/data/repository/app_state_repository.dart`.
- Feature screens and controllers: `lib/src/features/**`.
- Training model package: `packages/training_engine/lib/**`.
- Current web E2E coverage: `docs/e2e-web-flow-inventory.md`, `integration_test/app_test.dart`.
- Product roadmap and known planned items: `docs/ROADMAP.md`, `docs/ISSUE.md`.

## App Identity and Platforms

- The Flutter app is named `strength_training_tracker` and described in `pubspec.yaml` as `Kotrana: Musculation`, an offline-first strength training tracker for iOS and the web.
- The main implemented Flutter shell targets web and iOS. The repository also contains native iOS Live Activity and Apple Watch companion code under `ios/`.
- The web app supports PWA assets and a web-only force-update action.

## Navigation and Route Surface

Implemented routes:

- `/onboarding`: first-run profile setup.
- `/`: dashboard.
- `/routines`: routine list.
- `/routine/new`: routine creation.
- `/routine/:routineId/edit`: routine editing.
- `/routine-groups`: routine group list.
- `/routine-groups/new`: routine group creation.
- `/routine-groups/:groupId/edit`: routine group editing.
- `/routines/smart-planner`: plan-generation wizard.
- `/exercises`: exercise list.
- `/exercise/new`: exercise creation.
- `/exercise/:exerciseId/edit`: exercise editing.
- `/workout/active`: active workout session.
- `/workout/:sessionId/summary`: completed workout summary.
- `/progress`: analytics/progress surface.
- `/settings`: profile, preferences, account, data, legal links.
- `/debug/training-engine`: conditional debug surface gated by `shouldShowTrainingEngineDebug()`.

Navigation behavior:

- Empty profiles are redirected to onboarding.
- Completed profiles are redirected away from onboarding to the dashboard.
- Shell navigation exposes Dashboard, Routines, Exercises, and Progress.
- The shell uses bottom navigation below wide layouts and a navigation rail on wider layouts.

## State, Storage, and Data Model

Core persisted state includes:

- Exercises.
- Routines.
- Routine groups.
- Workout sessions.
- User name.
- Preferred unit.
- Sex.
- Age.
- Weight.
- Fitness goal.
- Preferred language.
- Preferred theme.
- Active routine group id.
- HealthKit enabled flag.

Persistence behavior:

- Firebase initializes with Auth and Firestore when available.
- The app signs in anonymously if there is no Firebase user.
- Firestore stores the app state per authenticated user.
- SharedPreferences is used as a fallback if Firebase initialization fails.
- Existing SharedPreferences state is migrated to Firestore when cloud data is empty.
- Training-engine state is stored separately in SharedPreferences.
- Legacy compound muscle names are migrated to more specific muscles on bootstrap.

## Onboarding

Implemented:

- First-launch onboarding with required name entry.
- Optional profile step with sex, age, weight, and fitness goal.
- Unit selection between kilograms and pounds.
- Google sign-in from onboarding.
- Demo-data entry from onboarding.
- Redirect out of onboarding once profile setup is complete.

## Authentication and Accounts

Implemented:

- Anonymous Firebase Auth session as the default account mode.
- Google sign-in and link-account flows.
- Apple auth/link service helpers and localization strings exist, but the visible onboarding/settings UI exposes Google sign-in/link controls.
- Sign out.
- Delete current user through Firebase Auth.
- Account data deletion through the app state repository.

Platform notes:

- On web, Google auth uses Firebase popup providers; Apple helper code also exists at the service layer.
- On native platforms, Google uses `google_sign_in`, and Apple helper code uses `sign_in_with_apple`.
- Web E2E treats third-party auth as a mocked failure path rather than opening real provider popups.

Required implementation work:

- Apple token revocation must be wired into the delete-account flow before it is counted as a completed user-facing account-deletion feature.

## Dashboard

Implemented:

- Profile header with user name.
- Settings shortcut.
- Total workout metric.
- Recent personal-record count.
- Muscle fatigue heatmap section.
- Training readiness card.
- Next-workout card.
- Active-workout or paused-workout card when a session is in progress.
- Recommended next routine from either the active routine group rotation or least-recently-trained routine fallback.
- Skip-next routine action when rotation allows it.
- Start/resume/review workout actions.
- Recent workouts list.
- Recent PR preview and navigation to Progress.
- Workout-frequency calendar with date-tap workout details.
- Conditional Engine Debug action.

## Exercises

Implemented:

- Exercise list with archived exercises hidden.
- Search by exercise name, primary muscles, and secondary muscles.
- Muscle filter chips.
- Exercise creation.
- Exercise editing.
- Exercise archiving.
- Strength and timed exercise types.
- Primary and secondary muscle assignment.
- Equipment and instruction fields.
- Optional exercise photo storage as base64.
- Exercise localization via translation keys for seeded exercises.

Known planned or incomplete:

- `docs/ISSUE.md` still lists "Add images for exercises" as incomplete, even though the model/editor contain optional photo support. This should be audited as a possible mismatch between implemented capability and product completeness.

## Routines

Implemented:

- Routine list with archived routines hidden.
- Routine creation.
- Routine editing.
- Routine archiving.
- Routine category normalization for strength, hypertrophy, and mobility.
- Estimated duration.
- Exercise picker inside routine editor.
- Search in routine editor picker.
- Multi-exercise routines.
- Per-exercise target sets.
- Per-exercise target reps.
- Per-exercise rest seconds.
- Per-exercise target duration for timed exercises.
- Routine exercise prescriptions persist exercise id, target sets, target reps, rest seconds, order, and timed target duration; they do not store recommended weight.
- Exercise reordering in routine editor.
- Starting a workout from a routine.
- Existing active session reuse when trying to start another routine.

## Routine Groups and Rotation

Implemented:

- Routine group list.
- Create, edit, and delete routine groups.
- Add routines to a group.
- Remove routines from a group.
- Reorder routines within a group.
- Mark a group as active rotation.
- Active group badge.
- One routine can belong to only one group at a time.
- Pending-routine rotation queue.
- Skip-next action rotates the queue when possible.
- Completing a workout marks the routine completed in all containing groups.
- Empty pending queue resets to the full group order.
- Archiving a routine removes it from routine groups.

## Smart Planner

Implemented:

- Wizard route for generating training plans.
- Day selection.
- Goal selection through the training-engine goal model.
- Maximum session duration selection.
- Preferred exercise selection.
- Excluded exercise selection.
- Weekly plan generation through `packages/training_engine`.
- Engine-aware adaptation: generation reads current engine fatigue, readiness,
  and ingested-session count; high-fatigue primary muscles reduce planned sets
  and adopted routine exercises carry Smart Planner engine-context metadata.
- Time-bounding generated sessions.
- Plan preview.
- Inline editing of generated exercise targets.
- Removing exercises from a generated plan.
- Swapping exercises through registry alternatives.
- Regenerating a plan.
- Adopting a generated plan into app routines and a routine group.

## Active Workout

Implemented:

- Active workout route.
- Strength-set logging with weight and reps.
- Weight/reps prefill from the current-session set for the exercise, the previous completed same-exercise set, or an engine suggestion when neither current-session nor previous completed data exists.
- Progression hint card with suggested load and reason when training-engine recommendation data is available.
- Optional per-set RPE.
- Per-set comments exposed in the active workout UI.
- Timed exercise countdown flow.
- Timed manual logging.
- Rest timer behavior after logged sets, including audio cues and iOS haptics where supported.
- Edit logged set.
- Delete logged set with renumbering.
- `sessionNote` is modeled, supported by the workout controller, and displayed on the summary when present, but the active-workout UI does not expose a session-note editor.
- Skip/go-to exercise.
- Same-primary-muscle exercise swap/search.
- Previous-performance panel with recent sets and personal-best context.
- Auto-advance to next exercise after target sets are completed.
- End-of-workout page with add-exercise and finish-workout actions after the last exercise.
- Complete session and route to summary.
- Discard active session.
- Stale-session detection and resume/finish/discard handling.
- Swipe/back-guard behavior to avoid accidental active-workout exits.
- Active exercise heatmap support in the workout UI.

## Workout Summary and History

Implemented:

- Summary route for completed workout sessions.
- Missing-summary fallback.
- Routine and exercise summary details.
- Session duration.
- Strength and timed set display.
- Session PR extraction.
- Estimated one-rep max display for strength sets.
- Timed sessions can be routed to summary, but `WorkoutSummaryScreen` does not display timed PR durations; timed PR duration display belongs to Progress.
- Unit-aware weight display.
- Delete completed workout from summary.
- Finish-and-go-home action.

Not implemented as a dedicated feature:

- A full standalone workout-history screen with calendar/filter UI remains planned in `docs/ROADMAP.md`.

## Progress and Analytics

Implemented:

- Progress screen with Overview, Lifts, and Volume tabs.
- Average workout days per week.
- Active streak days.
- Progress computes calendar-session data reused by the Dashboard workout-frequency calendar.
- Personal-record list.
- Top lifts.
- Weekly volume.
- Current/rolling strength e1RM values sourced from the training engine state
  (`TrainingEngine.currentE1rm` over `TrainingState.e1rmHistory`).
- Timed exercise PR support based on duration.
- Recent PR and workout snapshot data reused by the dashboard.
- Clicking dashboard PR/progress actions routes to Progress.

Planned but not fully implemented:

- Rich exercise history detail.
- Long-range 1RM charts.
- Yearly heatmap.
- Body-weight trend tracking.
- Full PR timeline.

## Muscle Heatmap and Training Readiness

Implemented:

- Dashboard body heatmap with front and back views.
- Sex-aware body rendering.
- Muscle fatigue gradient and legend.
- Info sheet explaining heatmap calculation.
- Secondary muscles contribute at a reduced coefficient in engine mapping.
- Timed completed sets with a duration and mapped muscles contribute to engine
  fatigue, the dashboard heatmap, and the live active-workout heatmap preview.
- Training readiness card backed by the training engine provider.
- Training engine debug route, when enabled.

Training engine package capabilities present in source:

- Estimated 1RM formulas and composite estimator.
- Fatigue decay and impulse calculation.
- Muscle registry and normalization.
- Acute-to-chronic workload ratio helpers over aggregated local-calendar-day loads.
- Timed-set ingestion uses duration-based stress for fatigue and daily
  load/ACWR context, and timed-only sessions count as ingested when they
  contribute that state.
- Readiness scoring from sleep and HRV records.
- Load progression recommendations with safety gates and rounding.
- Planner split selection, session generation, time bounding, substitutions, and missed-session logic.

Integration caveat:

- The app maps captured profile fields into the training engine: sex, age, weight, and `fitnessGoal` are translated into the engine profile, with engine defaults used only when optional app fields are absent.
- Timed sets do not create e1RM history, last-top-set history, or visible
  strength load recommendations; those outputs remain strength-set only.

## Settings

Implemented sections:

- Profile.
- Preferences.
- Account.
- Data.
- Legal.
- App version.

Profile controls:

- Name.
- Sex.
- Age.
- Weight.
- Fitness goal chips.

iOS-only Integrations controls:

- Apple Health sleep/HRV toggle backed by the HealthKit integration path when supported by platform state.

Preference controls:

- Unit preference: kilograms or pounds.
- Language preference: Auto, English, French.
- Theme preference: Auto, light, dark.

Data controls:

- Load sample exercises, routines, and routine groups; this settings action does not append sample workout sessions.
- Clear exercises and routines.
- Clear workout history.
- Force update app on web.

Legal controls:

- Privacy Policy link.
- Terms of Use link.

## Localization and Theming

Implemented:

- Flutter localization generation.
- English localization.
- French localization.
- Localized exercise names for seeded exercises.
- Language preference stored in app state.
- Light, dark, and system/auto theme modes.
- Google Fonts and centralized app colors/theme tokens.

Implementation gap:

- Exercise list/search/routine picker surfaces and Smart Planner labels still use raw or hard-coded English text in places. This is an implementation gap, not an acceptable final localization state.

## Demo and Seed Data

Implemented:

- Complete seeded exercise library through `DemoSeedData.seedExercises()`.
- Seed routines: Push Day, Pull Day, Leg Day, Full Body.
- Seed routine group: Push / Pull / Legs.
- Seed completed sessions for dashboard/progress demonstrations.
- Settings action to append sample exercises, routines, and routine groups.
- Onboarding action to start with demo data.

## Web/PWA Features

Implemented:

- Web build target.
- PWA manifest at `web/manifest.json`.
- Web splash/icon generation.
- Force-update app action using a web-specific implementation.
- Static privacy and terms pages at `web/privacy.html` and `web/terms.html`.
- Browser notification support for rest timer completion when permissions and page visibility allow it.

Verification basis:

- `test/web/web_assets_test.dart` verifies the manifest identity, installable icon files, web index manifest metadata, static privacy/terms pages, and this inventory's web asset claims.
- `test/core/legal_links_test.dart` verifies the Settings legal-link URLs resolve to the deployed web privacy and terms pages.

## iOS Native Features

Implemented in source:

- iOS Live Activity service bridge from Flutter through method channel `com.strengthapp/live_activity`.
- Live Activity payload for active workout state, current exercise, set progress, rest timer, and session metadata.
- Native Swift Live Activity manager and widgets under `ios/Runner` and `ios/StrengthAppLiveActivity`.
- Apple Watch connectivity bridge through method/event channels.
- Watch snapshot model for active workout state.
- Watch UI for current session, strength exercise, and timed exercise.
- Watch-to-phone quick set logging messages.
- Watch localization files.
- `lib/main.dart` initializes `workoutLiveActivityServiceProvider` and `watchSyncServiceProvider` on non-web iOS.

Audit caveat:

- Task 16 source-level verification on 2026-05-12 passed fake-channel tests for idempotent Watch initialization, Watch snapshot payloads with and without engine suggested weights, Watch-originated quick set logging, Live Activity active-workout payload shape, Live Activity end calls, and method-channel failure tolerance.
- Task 16 build verification on 2026-05-12 passed `flutter build ios --debug --no-codesign`; the build detected the Watch companion app.
- Task 16 equivalent device-lab runtime smoke on 2026-05-12 passed on the paired `17 Pro + watch 26.3` simulator (`FDFE9890-3387-4E10-9BEE-1EC387EF14E5`) with `flutter drive --driver=test_driver/integration_test.dart --target=integration_test/native_runtime_wiring_test.dart -d FDFE9890-3387-4E10-9BEE-1EC387EF14E5 --debug --no-pub`. The smoke test invoked the real iOS native MethodChannel handlers for Watch `isWatchPaired`, `isWatchReachable`, `sendSessionUpdate`, and `sendSessionEnd`, plus Live Activity `syncWorkout` and `endWorkout`, using active-workout payloads with completed sets, suggested-weight and null-suggestion Watch snapshots, rest timer metadata, and session metadata.
- Physical iPhone/Apple Watch runtime smoke verification is still blocked as of 2026-05-12. `flutter devices` found `iPhone 14 Pro Mamy` and `Apple Watch S9`, but the physical-device path cannot mount the developer disk image while the device is locked. A refresh with `xcrun devicectl device info ddiServices --device 9960CCE6-61E7-5C0B-AC41-0973BE159420` failed with `kAMDMobileImageMounterDeviceLocked`. The native integrations are runtime-verified through the paired simulator equivalent device-lab smoke, but not yet on the user's physical iPhone/Watch hardware.

## Health, Sleep, HRV, and BLE

Implemented or scaffolded:

- Training engine models and ingestion paths for sleep and HRV.
- HealthKit data source integration point with explicit empty, unavailable, denied, and error fetch statuses.
- HealthKit enabled flag in app state.
- BLE dependency in `pubspec.yaml`.

Caveat:

- The current visible Flutter web app does not expose full HealthKit/BLE workflows. These should be treated as native/platform integration surfaces, not fully verified web features.
- Empty or denied HealthKit fetches do not populate demo sleep/HRV records; demo readiness inputs are limited to explicit demo-data flows.

## Notifications and Rest Timer

Implemented:

- Rest timer scheduling abstraction.
- Web notification implementation.
- Stub/native conditional export.
- Rest timer information is included in Live Activity payloads.
- Active-workout rest timer completion can use audio cues and iOS haptics where supported.

## Debug and Developer Surfaces

Implemented:

- Conditional `/debug/training-engine` route.
- Dashboard Engine Debug action when the debug surface is enabled.
- Reset/re-bootstrap control in the debug screen.
- Training engine state repository.

Production caveat:

- `docs/ROADMAP.md` still lists removal/gating of public debug surfaces as a platform-quality item.

## Current Automated Coverage

Web E2E tests now cover:

- Onboarding minimal and full profile paths.
- Onboarding redirect, validation, demo data, and mocked Google failure.
- Shell navigation and deep links.
- Exercise CRUD, search, filters, timed exercise creation, validation.
- Routine CRUD, including routine archive through the visible archive action and
  confirmation dialog.
- Routine group create, edit, delete, and visible rotation-route rendering.
- Routine-group dashboard next-up advancement through visible workout
  completion.
- Smart Planner validation, wizard day/goal/preference interactions,
  generation preview, and visible adoption into routines.
- Strength workout start/log/edit/delete/discard/stale paths, with some
  edit/delete fallbacks using workout controller calls.
- Timed workout timer controls, visible manual timed-set logging, visible timed
  set duration edit, summary, and progress records.
- Workout summary delete, missing summary, and unit display.
- Settings profile/preferences/account/data/legal surface.
- Progress PR generation and units.
- Dashboard progress navigation.
- Debug route behavior when available.
- Some web E2E flows use controller or state seeding rather than fully UI-driving
  every listed path, so this should be read as web-flow/state coverage rather
  than complete user-interaction coverage for every feature. See
  `docs/e2e-web-flow-inventory.md` for the flow-by-flow coverage status.

Recent local verification:

- Task 19 final verification on 2026-05-12 passed
  `cd packages/training_engine && dart test` (`+453`), `flutter test`
  (`+188`), `flutter analyze` (`No issues found!`), and
  `bash tool/ci/run_web_e2e.sh` (`All tests passed.`). Root Browser visual
  verification passed on onboarding demo, dashboard, engine debug, routines,
  Smart Planner generation/adoption, exercises, and progress.

## Planned or Not Fully Implemented Features

The following are listed as roadmap or issue items and should not be described as fully shipped unless source inspection proves otherwise:

- Superset/circuit support.
- Warmup set tagging.
- Drop/failure set tagging.
- Apple token revocation wired into the delete-account flow.
- Plate calculator.
- In-workout notes per exercise.
- Workout timer pause/resume separate from timed exercise timers.
- Full workout history screen.
- Exercise history detail screen.
- 1RM progression charts.
- Volume per muscle group analytics UI.
- Yearly training frequency heatmap.
- Body-weight tracking and trend chart.
- Personal-record timeline.
- Routine templates/presets beyond demo seed routines.
- Duplicate routine action.
- Routine scheduling by weekday outside Smart Planner output.
- Mesocycle/program support.
- Broader/richer alternative recommendations beyond Smart Planner registry substitutes and active-workout same-primary-muscle swaps.
- Workout summary sharing.
- JSON/CSV export and import.
- Public profile sharing.
- Store submission and release-quality compliance tasks.
