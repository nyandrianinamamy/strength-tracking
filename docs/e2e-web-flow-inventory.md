# Web E2E Flow Inventory

This file inventories end-to-end flows for the Flutter web app. It is a planning
artifact for expanding `integration_test/app_test.dart` and the CI runner in
`tool/ci/run_web_e2e.sh`.

## Scope

Target platform: Flutter web, running against Firebase Auth and Firestore
emulators.

Primary app entry points:

- `/onboarding`
- `/`
- `/routines`
- `/routine/new`
- `/routine/:routineId/edit`
- `/routine-groups`
- `/routine-groups/new`
- `/routine-groups/:groupId/edit`
- `/routines/smart-planner`
- `/exercises`
- `/exercise/new`
- `/exercise/:exerciseId/edit`
- `/workout/active`
- `/workout/:sessionId/summary`
- `/progress`
- `/settings`
- `/debug/training-engine`, only when the debug surface is enabled

Out of web E2E scope for the first pass:

- Apple Watch sync and watch-originated set logging.
- iOS Live Activities.
- HealthKit authorization, sleep, and HRV import.
- Native Apple sign-in UI.
- Camera capture as a native flow. Web image upload can still be covered if the
  browser test harness supports file picking.

## Current Web E2E Coverage

`integration_test/app_test.dart` already covers:

- Onboarding with minimal profile.
- Onboarding with full profile details.
- Exercise create, edit, and archive.
- Routine create with one exercise.
- Strength workout start, set logging, finish, and summary.
- Progress screen PR generation after a workout.
- Settings page rendering and profile persistence.
- Sex preference persistence.
- Account and data sections rendering.
- Progress PR unit display.
- Dashboard "View all" navigation to Progress.
- Workout summary hiding the session RPE slider.
- Exercise page keyboard-dismiss regression.

## Coverage Status

The web E2E suite passes, but not every covered product path is fully driven
through user interactions. Read the current suite as a mix of UI-driven flows,
route-rendering checks, and controller/state-backed assertions.

Task 19 final verification on 2026-05-12 ran
`bash tool/ci/run_web_e2e.sh` and passed with `All tests passed.` Root
Browser visual verification passed on onboarding demo, dashboard, engine debug,
routines, Smart Planner generation/adoption, exercises, and progress.

Fully UI-driven or primarily UI-driven flows in `integration_test/app_test.dart`
include:

- `visible grouped workout advances dashboard next up`: seeded routine-group
  fixture, then visible dashboard start, active-workout set logging, finish, and
  routine-group advancement assertion.
- `completes onboarding skipping About You page`: profile setup through the
  onboarding UI.
- `completes onboarding with full profile details`: full onboarding form and
  settings verification through visible controls.
- `create, verify, edit, and archive an exercise`: exercise CRUD through the UI.
- `create routine with exercise, verify in list`: routine creation from visible
  controls.
- `start workout, log set, finish, see summary`: strength workout start, set
  logging, finish, and summary navigation through visible controls.
- `completed workout produces a PR on progress screen`: workout completion
  through the UI, followed by progress-screen assertions.
- `onboarding redirect, validation, demo, and Google failure`: redirect,
  validation, demo data, and mocked Google failure through UI actions, with
  state readbacks for final assertions.
- `shell navigation, deep links, dashboard, and settings route`: route and shell
  navigation coverage, with a seeded active-session fixture for dashboard state.
- `exercise list search, filters, timed editor, and validation`: exercise list
  and editor behavior through UI controls after seeded fixture setup.
- `routine editor validation, multi-exercise edit, search, archive`: seeded
  exercise/routine fixture, visible routine-card edit entry, archive
  confirmation, and archived-state assertion.
- `routine groups create, edit, delete, and rotation advance`: seeded routines,
  visible group list/editor delete, create, edit, and delete interactions.
- `smart planner validation, generation, edits, and adopt`: seeded exercise
  fixture, visible Smart Planner entry point, wizard day/goal/preference
  interactions, generation preview, and visible adoption result on Routines.
- `timed workout flow and timed summary/progress records`: seeded timed active
  session fixture, visible timer controls, manual timed set logging, set edit
  dialog update, finish, summary, and progress assertions.
- `settings profile/preferences/account/data/legal actions`: settings rendering
  and several preference/account actions through UI controls, with direct state
  updates used for clear-history and clear-data assertions.

Shortcut-backed flows in `integration_test/app_test.dart` include:

- `active workout strength edit/delete, discard, and stale paths`: starts from a
  seeded active session and mixes visible controls with
  `workoutControllerProvider` calls for note/update/delete fallback paths.
- `workout summaries handle completed, delete, missing, and units`: seeded
  completed sessions drive summary/delete/missing/unit assertions.
- `training engine debug route renders when available`: seeded state plus route
  rendering, not a user-created training-engine scenario.

Task 18 UI Coverage Added:

1. Smart Planner route rendering and injected adopted-state assertions were
   replaced with a visible wizard generate/preference/adopt flow.
2. Routine-group rotation is covered through visible workout completion
   advancement; group create/edit/delete is covered through the visible group
   editor.
3. Routine archive coverage now uses the actual archive action and confirmation
   dialog.
4. Timed workout coverage now logs a manual timed set, edits its duration, saves
   the workout, checks the summary, and checks Progress through visible UI
   interactions.

Remaining UI Coverage Debt:

1. The strength active-workout edit/delete/stale-session regression still mixes
   visible controls with controller fallbacks for note/update/delete branches.
2. Settings clear-history and clear-data assertions still use direct state
   updates for fixture cleanup after rendering the visible controls.
3. Summary and debug-route tests remain seeded route/state coverage by design.

The gaps below are the candidate expansion set.

## Web E2E Harness Notes

- Runner: `tool/ci/run_web_e2e.sh` starts Firebase Auth and Firestore
  emulators, starts ChromeDriver on port `4444`, then runs
  `flutter drive --driver=test_driver/integration_test.dart
  --target=integration_test/app_test.dart -d web-server --browser-name=chrome`.
- Emulator constants live in `integration_test/e2e_helpers.dart`: project
  `myappv4`, Firestore `localhost:8081`, Auth `localhost:9099`.
- Test bootstrapping uses the real app path:
  `connectEmulators()`, `bootstrapTestApp(firestore: ..., auth: ...)`, then
  `pumpApp(tester, container)`.
- Emulator cleanup is per-test via `resetEmulators()`. `pumpApp` waits for the
  connectivity snackbar to dismiss, which is important before tapping web
  primary actions.
- Existing helpers already cover onboarding, tab navigation, settings
  navigation, exercise creation, routine creation, and a quick strength workout.
- This suite is Flutter widget/integration-test based. Prefer
  `find.text(...)`, `find.widgetWithText(...)`, `find.byIcon(...)`, and existing
  `ValueKey`s over DOM selectors. Current durable keys include
  `active-workout-weight-input`, `active-workout-reps-input`, and
  `active-workout-log-set-button`.
- There is no Playwright dependency or separate dev-server command for this
  path; Flutter owns the web server through `-d web-server`.

## First Expansion Implementation Notes

These notes turn the suggested first batch into concrete test paths. They are
intended to keep new E2E tests close to the existing `app_test.dart` style.

### Demo Data and Seeding

- The Settings data action `Load Sample Exercises & Routines` appends
  `DemoSeedData.initialState()` to the current state and sets an active routine
  group if none exists. The success snackbar is
  `Sample exercises & routines loaded`.
- For faster setup, tests can also seed through the app state controller after
  `pumpApp` by updating state with values from `DemoSeedData.initialState()`.
  This avoids long UI setup when a flow only needs populated exercises,
  routines, groups, or completed sessions.
- Demo seed gives known routine/group names useful for assertions:
  `Push Day`, `Pull Day`, `Leg Day`, `Full Body`, and
  `Push / Pull / Legs`.

### Routine Groups

- Routes: list `/routine-groups`, create `/routine-groups/new`, edit
  `/routine-groups/:groupId/edit`.
- Entry points: Routines screen has `Groups`; the groups empty state has
  `Create Group`; the app bar add icon has tooltip `New group`.
- Editor controls: `Group Name`, `Use as active rotation`, `Add Routines`,
  `Create Group`, `Save Changes`, and `Delete Group`.
- Creation is disabled until the group has a non-empty name and at least two
  routines. Build the prerequisite routines first or seed with demo data.
- The add-routine picker is a modal bottom sheet titled `Add Routine`; tap
  routine names such as `Push Day` and `Pull Day`.
- Reordering uses `ReorderableListView` with cards keyed by routine id and a
  drag-handle icon, so prefer `tester.drag` from the visible routine card/handle
  rather than relying on text order alone.
- Delete uses a confirmation dialog titled `Delete group?` with `Cancel` and
  `Delete`; after confirm, assert the group name is gone and the active group
  badge/rotation text no longer references it.
- Group cards display the group name, `Active` when selected, routine count,
  routine-name chips, and current-cycle text. The active rotation advancement
  path should finish a workout from the active group's next routine, then assert
  the `Current cycle` text changed.

### Smart Planner

- Route: `/routines/smart-planner`; entry point on the routines screen is
  `Smart Planner`.
- Wizard controls: app bar title `Smart Planner`, close icon, bottom `Cancel` /
  `Back`, `Next`, `Skip`, and `Generate`.
- Step 1 `Next` is disabled until at least one day chip is selected. Day chips
  are `Mon`, `Tue`, `Wed`, `Thu`, `Fri`, `Sat`, `Sun`.
- Step 2 has goal segments and a duration selector; use visible goal text plus
  duration controls instead of assuming a fixed generated split.
- Step 3 uses checkbox tiles keyed as `preferred_<exercise.id>` and
  `excluded_<exercise.id>`. If a test seeds exercises, stable ids make these
  keys a good selector.
- Preview controls are `Regenerate` and `Adopt Plan`; adoption should land back
  in routines with newly created routine cards. Use generated routine names and
  exercise names as assertions, not only the route.
- Swap alternatives are presented in a bottom sheet. This is a harder path
  because alternatives depend on available compatible exercises; seed multiple
  exercises in the same muscle/type family before testing it.

### Active Workout

- Route: `/workout/active`. With no active session, assert the empty state and
  `Discard Session` route branch are not accidentally available.
- Start paths: dashboard `Start Session`/`Resume Session`, routines card play
  icon, and the persistent bottom start bar `Start`/`Resume`.
- Strength logging uses the keyed fields
  `active-workout-weight-input` and `active-workout-reps-input`, then the keyed
  `active-workout-log-set-button`. The RPE modal must be confirmed with
  `Save and Log Set`; dismissing it should leave no logged set.
- Logged set actions open from the set row overflow/tap sheet. The sheet actions
  are `Edit Set` and `Delete Set`; edit dialogs are titled like `Edit Set 1`
  and contain `Weight (...)`, `Reps`, `RPE`, `Cancel`, and `Save`.
- Timed exercises show `Countdown`, `Start`/`Pause`/`Resume`, `Reset`, a manual
  `Manual (min)` field with hint `0`, and `Log`. Create or seed a routine whose
  exercise has `exerciseType: timed` and `targetDurationSeconds > 0`.
- Finish/discard branch: end-of-workout `Finish Workout` opens a bottom sheet
  with `Finish & Save`, `Keep Training`, and `Discard Session`. `Finish & Save`
  routes to `/workout/:sessionId/summary`; discard returns to `/`.
- Stale-session branch: a stale active session opens `Resume Stale Session` with
  `Resume`, `Finish Now`, and `Discard`. This is best seeded by setting
  `lastActivityAt` far enough in the past on an active `WorkoutSession`.

### Settings, Account, Data, and Legal

- Route: `/settings`; dashboard gear icon pushes this route.
- Profile fields/controls: `Your Name`, `Male`, `Female`, `Age`, `Weight`,
  goal chips `Strength`, `Hypertrophy`, `Endurance`, `Weight Loss`, and
  `General Fitness`.
- Preferences controls: unit segments `KG`/`LBS`, language `Auto`/`EN`/`FR`,
  and theme `Auto`/light icon/dark icon. Unit changes should be asserted again
  in workout inputs, summary, dashboard, or progress rather than only settings.
- Account controls: email/password, `Continue with Apple`, `Continue with Google`, `Sign Out`,
  and `Delete Account`. Google paths should be treated as failure/snackbar paths
  under emulator/web unless the provider is explicitly mocked.
- Data controls: `Load Sample Exercises & Routines`,
  `Clear Exercises & Routines`, `Clear Workout History`, and web-only
  `Force Update App`.
- Clear-data dialog: title `Clear Exercises & Routines?`, body says workout
  history is kept, actions `Cancel` and `Clear`, success snackbar
  `Exercises & routines cleared`.
- Clear-history dialog: title `Clear Workout History?`, actions `Cancel` and
  `Clear`, success snackbar `Workout history cleared`; routine groups should
  remain and pending rotation should reset to `routineIds`.
- Legal controls: `Privacy Policy` and `Terms of Use` call the platform URL
  opener. In this integration-test harness, these should be covered by verifying
  the buttons render or by injecting/mocking the URL opener in a separate test.

### Shell, Dashboard, and Deep Links

- App shell routes under the shell are `/`, `/routines`, `/exercises`,
  `/progress`, and conditionally `/debug/training-engine`.
- Bottom navigation is used below width `1000`; navigation rail is used at
  width `1000` and above. Labels are Dashboard, Routines, Exercises, Progress.
- Deep links to shell routes redirect to `/onboarding` when `userName` is empty
  and are allowed after onboarding. `/onboarding` redirects back to `/` after
  profile completion.
- Dashboard actions: settings gear opens `/settings`, Recent PRs metric and
  `View Progress`/`View All` actions go to `/progress`, and `Engine Debug`
  appears only when the debug surface is enabled.
- Dashboard active-workout card shows `Session in progress` or `Workout paused`
  and routes to `/workout/active` through `Resume Session`/`Review Session`.

## Candidate E2E Flows

### Onboarding and Session Bootstrap

- Redirect behavior: empty profile routes to `/onboarding`; completed profile
  redirects away from `/onboarding` to `/`.
- Welcome page validation: `Next` disabled until name is entered.
- Minimal onboarding: enter name, skip optional profile fields, choose unit,
  land on dashboard.
- Full onboarding: choose sex, age, weight, fitness goal, unit, then verify
  persisted values in settings.
- Demo mode: tap `Try with demo data`, verify dashboard, exercises, routines,
  routine groups, and progress are populated.
- Google sign-in failure path on emulator or mocked web provider: snackbar is
  shown and the user stays on onboarding.

### App Shell and Navigation

- Mobile-width shell: bottom navigation switches Dashboard, Routines,
  Exercises, and Progress.
- Desktop-width shell: navigation rail switches the same tabs.
- Deep-link access after onboarding: direct load of `/routines`, `/exercises`,
  `/progress`, and `/settings`.
- Back/close behavior from modal routes: editors and active workout return to
  the expected shell route without losing persisted state.

### Dashboard

- Empty dashboard state: no routines yet, next-workout card prompts routine
  creation, readiness and fatigue cards show empty states.
- Populated dashboard state: metrics, recent PRs, next routine, active routine
  group, fatigue heatmap, and readiness card render.
- Metric navigation: Recent PRs card opens `/progress`.
- Settings gear opens `/settings`.
- Active workout state: paused/in-progress workout appears on dashboard and can
  resume through `/workout/active`.
- Stale active session state: stale prompt offers resume, finish now, and
  discard paths.
- Debug surface enabled: Engine Debug action opens `/debug/training-engine`.

### Exercises

- Empty exercise list renders the empty state.
- Create strength exercise: name, primary muscles, secondary muscles,
  equipment, instructions, save, and verify list grouping.
- Create timed exercise: switch type to timed, save without strength-only
  fields that should not be required, and verify it appears in the list.
- Save validation: strength exercise cannot be saved with no primary muscle.
- Search by name filters results.
- Muscle chips filter results and `All` resets the filter.
- Edit exercise: rename, change type, muscles, equipment, instructions, and
  verify the updated list item.
- Archive exercise from list menu and verify it is removed from available
  exercises and routine pickers.
- Optional photo flow: add image, replace image, remove image, and verify list
  thumbnail behavior. This may need a browser/file-upload capable harness.
- Keyboard/focus behavior on web: typing in search or editor fields does not
  block action buttons after scrolling.

### Routines

- Empty routine library renders no-active-group and no-routine states.
- Create routine with a strength exercise: name, category, add exercise, adjust
  sets, reps, rest, save.
- Create routine with a timed exercise: add timed exercise, adjust duration and
  rest, save.
- Save validation: cannot save a routine with no exercises.
- Add multiple exercises to a routine.
- Remove exercise from routine before save.
- Reorder routine exercises and verify the order persists after reopening.
- Edit routine: rename, change category, update exercise prescription, add and
  remove exercises, save.
- Archive routine from the editor and verify it disappears from routine list,
  routine group picker, and dashboard next-workout candidates.
- Search routines by name.
- Filter routines by category and reset to `All`.
- Start workout from routine card and land on `/workout/active`.
- Routine picker search inside routine editor filters available exercises.

### Routine Groups

- Empty routine groups screen renders create prompt.
- Create group requires a name and at least two routines.
- Create active group with ordered routines and verify it appears on dashboard
  and routines screen.
- Add routines through the bottom sheet picker.
- Reorder routines in a group and verify order persists.
- Remove routine from a group and verify save validation updates.
- Edit group name and active-toggle state.
- Delete group and verify it is removed and active group state is updated.
- Group cards display active badge, routine count, assigned routine names, and
  pending cycle text.
- Starting and finishing workouts advances the active group's pending rotation.

### Smart Planner

- Open Smart Planner from routines screen.
- Step 1 validation: `Next` disabled until at least one day is selected.
- Step 1 day selection: select and deselect multiple training days.
- Step 2 goal/duration: choose goal and adjust target duration.
- Step 3 preferences: mark preferred exercises and excluded exercises.
- Generate plan with no preferences.
- Generate plan with preferences and exclusions.
- Preview generated plan: expand sessions and verify sessions, exercises,
  target sets/reps, supersets, and day labels.
- Edit generated exercise prescription in preview.
- Remove an exercise from generated plan.
- Swap an exercise using the alternatives sheet.
- Regenerate plan and verify preview updates.
- Adopt plan and verify routines are created and visible in `/routines`.
- Cancel/close wizard returns to routines without adopting.
- Back button from preview returns to wizard state.

### Active Workout

- Direct `/workout/active` with no active session shows empty state.
- Start strength workout from dashboard next-workout card.
- Start strength workout from routine card.
- Log strength set: weight, reps, RPE modal, optional comment, current-session
  set list, rest timer.
- Cancel RPE modal and verify no set is logged.
- Add comment before logging a set and verify comment state clears after log.
- Edit logged strength set: weight, reps, and RPE.
- Delete logged set from long-press or overflow path.
- Previous performance appears after completing a prior session.
- Suggested load appears when training engine data is available.
- Swap current exercise from active workout and verify the page updates.
- Page through multiple exercises, including keyboard dismissal on page switch.
- Auto-switch prompt after completing target sets: stay here vs switch now.
- End-of-workout page: add exercise path opens routine editor; finish path opens
  finish confirmation.
- Finish confirmation: keep training, finish and save, discard session.
- Close active workout to dashboard and resume active session later.
- Stale session prompt: resume, finish now, discard.
- Timed workout flow: start countdown, pause, resume, reset, manual timed log,
  edit timed set, delete timed set, finish summary.
- Invalid input paths: empty/invalid weight, reps, duration, or RPE does not log
  or corrupt state.

### Workout Summary

- Completed strength summary shows routine name, duration, volume, exercise
  count, set list, and PR highlights.
- Completed timed summary shows timed set details without strength-only 1RM
  assumptions.
- No-PR summary shows the empty PR card.
- `Finish & Go Home` returns to dashboard.
- Delete workout from summary confirms deletion and returns home.
- Missing session deep link shows summary-unavailable empty state.
- Preferred unit affects summary volume and set display.

### Progress

- Empty progress shows empty/no-data states for PRs and volume.
- Overview tab shows workout days, active streak, and personal records after
  workouts.
- Lifts tab shows best set, estimated 1RM, and achieved date.
- Volume tab shows weekly volume chart and list.
- Timed exercise records appear as duration-based records.
- Unit preference switch from settings updates Progress values.
- Multiple workout history produces sorted/updated PRs and volume.
- Dashboard "View all" and PR metric navigation both land on Progress.

### Settings

- Profile: edit name with debounce and verify dashboard updates.
- Profile: edit age and weight, clear age/weight, invalid values are ignored.
- Profile: change sex and fitness goal.
- Preferences: switch unit, language, and theme.
- Unit preference affects workout inputs, summary, dashboard, and progress.
- Language preference changes visible labels after rebuild.
- Theme preference changes light/dark/auto rendering.
- Account signed-in state renders sign out and delete controls
  actions.
- Link Google account failure path shows snackbar without state loss.
- Switch account confirmation cancel and confirm paths.
- Sign out/reset confirmation cancel and confirm paths; confirm returns to
  onboarding.
- Delete account confirmation cancel and confirm paths; confirm returns to
  onboarding.
- Load sample data adds demo exercises, routines, groups, and active group.
- Clear exercises/routines/history confirmation cancel and confirm paths.
- Clear workout history preserves routines/groups and resets group pending
  rotation.
- Web-only force update button appears on web.
- Legal links: Privacy Policy and Terms of Use trigger external URL open.
- App version renders.

### Training Engine Debug Surface

This route is conditional and should be tested only with the debug surface
enabled.

- Dashboard Engine Debug button opens `/debug/training-engine`.
- Empty engine state renders useful empty guidance.
- Engine loading failure renders useful error text.
- Persisted state summary renders sorted sessions and snapshot metadata.
- Fatigue rows render sorted from highest to lowest.
- Recommendation rows render exercise details.
- Raw serialized snapshot section renders.
- Completed workout syncs into engine-backed debug/readiness/fatigue surfaces.

### Persistence, Offline, and Emulator Boundaries

- State persists across app rebuild/reload within the emulator-backed user.
- Emulator reset gives a clean state between tests.
- Sign out returns to onboarding without recreating an anonymous auth session.
- Firestore-backed state loads after replacing local state from cloud.
- Connectivity snackbar does not block primary web actions.
- Local fallback path after Firebase initialization failure, if injectable in
  test harness.

## Suggested First Expansion Batch

The next high-value web E2E additions should be:

1. Demo mode bootstrap, because it creates broad data coverage cheaply.
2. Routine groups create/edit/delete and active rotation advancement.
3. Smart Planner full generate/edit/adopt flow.
4. Timed exercise creation plus timed workout logging.
5. Settings data actions: load sample data, clear data, clear workout history.
6. Active workout edit/delete set and finish/discard branches.

These cover the largest currently-missing product paths without requiring real
OAuth, native iOS APIs, or file upload support.
