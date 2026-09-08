# TestFlight 309 domain review

Reviewed source: `v1.0.31+309`, commit `e288c4984dc4ea9fe36468cd37fed64bdde42f47`.
Review date: 8 September 2026.

Scope: workout, routines, exercises, dashboard/progress, Smart Planner, Flutter
training-engine integration, and `packages/training_engine`. This report records
actionable defects found through code inspection and two executed reproductions.
It is not a guarantee that every execution path works. Production code was not
changed. Native lifecycle and authentication findings are in separate reports.

## Findings

### D1 — P2: history replay changes timed-workout fatigue

`packages/training_engine/lib/src/engine.dart:636-646` reconstructs every
`rpeEstimated` set with the legacy strength `rpe` field, discarding its
`effortRpe`, `localRpe`, and `intensityClass`. The Flutter adapter deliberately
supplies cardio effort 5 and local effort 7 at
`lib/src/features/training_engine/training_engine_adapter.dart:87-115`.
Reconstruction substitutes session RPE 8. The cardio calculator consumes that
strength fallback at
`packages/training_engine/lib/src/fatigue/impulse_calculator.dart:117-121`.

Executed reproduction: the same 20-minute cardio session produces fatigue
`19.58768450965083` through direct ingestion and `50.14447234470614` through
history bootstrap. A rebuild therefore changes the recovery calculation without
any change to the workout.

Repair: preserve typed intensity fields and backfill only the missing channel.
Verify direct ingestion, serialization/restart, and reconstruction from history
agree for strength, cardio, and isometric sets, including missing and explicit RPE.

### D2 — P2: exercise swaps can merge separate workout prescriptions

`lib/src/features/workout/active_workout_screen.dart:658-661` excludes only the
current exercise and archived exercises from the swap picker. Another exercise
already in the routine remains selectable.
`lib/src/features/workout/workout_controller.dart:313-318` accepts the duplicate.
Logging counts completed sets by `exerciseId` at lines 46-48 and 92-94; timed
exercise ownership and rest lookup also use the first matching exercise.

After swapping one slot to an exercise used by another slot, both prescriptions
share set counts, editing identifiers, and timer lookup. Automatic advancement
can skip intended sets. The routine editor already blocks duplicate additions;
the swap flow bypasses that constraint.

Repair: reject duplicate IDs in both the picker and controller, or introduce
stable prescription IDs throughout sets and timers if repeated exercises are an
intended feature. Cover swapping after sets have been logged, duplicate targets,
and strength/timed transitions.

### D3 — P2: planner time reductions disappear after adoption

`lib/src/features/smart_planner/smart_planner_controller.dart:338-348` copies sets,
repetitions, and rest into a routine but drops `PlannedExercise.isSupersetPair`.
Superset flags halve effective rest in the engine estimate. The saved routine
does not retain those semantics, and the workout uses full rest at
`lib/src/features/workout/active_workout_screen.dart:443-449`.

Repair: preserve and implement the execution semantics promised by the preview,
or stop using unsupported supersets for time bounding. Test preview, adoption,
persistence, and phone/Watch execution for equivalent prescriptions and rests.

### D4 — P2: bounded plans retain obsolete duration estimates

`packages/training_engine/lib/src/planner/time_bounder.dart:87-91`, 115-119,
and 141-143 changes exercises without updating `estimatedDuration`.
`PlannedSession.copyWith` retains the old estimate at
`packages/training_engine/lib/src/planner/session_generator.dart:145-159`.
Smart Planner then stores that stale value.

Executed reproduction: a 30-minute original session is reduced to 18 minutes
when recomputed, but the returned session still reports 30 minutes.

Repair: recompute duration whenever exercises change and explicitly report when
the requested maximum cannot be met. Test each adjustment pass and the adopted
routine's estimate, including an unachievable time limit.

### D5 — P2: personal-record identity becomes the newest set

`lib/src/features/progress/progress_service.dart:362-390` assigns the same current
rolling e1RM to every historical set of an exercise, then breaks every tie by
newest timestamp. An older 100 kg x 8 record followed by a recent 40 kg warm-up
can therefore show the warm-up's weight, repetitions, and date as the record.

Repair: separate current estimated strength from historical best-set identity.
Keep the engine-owned estimate where appropriate, but identify the historical
record from the historical performance. Test an older strong set followed by
weaker recent sets. Existing tests check the numerical e1RM source without
checking which set/date is presented as the record.

### D6 — P2: archived default exercises remain in generated plans

`lib/src/features/smart_planner/planner_registry_adapter.dart:10-18` starts with
the complete default registry and skips archived app exercises without removing
their existing default entries. Archiving a built-in exercise leaves it eligible
for generation. Adoption finds the ID already exists and retains the archived
app record.

Repair: exclude archived IDs from planner selection, including default IDs.
Verify generation, manual plan edits, and adoption do not reintroduce them.
Preserve archived exercise records referenced by workout history.

### D7 — P2: cached derivatives ignore edits to existing inputs

`lib/src/features/training_engine/training_engine_provider.dart:69-74` reuses
saved derivatives when completed-session ID sets match. Editing a custom
exercise's muscle assignment changes the new registry but leaves saved fatigue
calculated from the previous assignment. The unused `updateRpe` controller API
would have the same cache problem if connected to a history editor.

Repair: use a versioned fingerprint of session contents and relevant exercise
metadata, or rebuild from canonical history after those mutations. Test an
existing custom exercise's changed muscle assignment without changing session
IDs, and existing session edits if that API is retained.

## Removal candidates

These are candidate removals after a final caller and persisted-data review, not
permission to delete fields from stored records.

- `WorkoutController.resumeActive`, `skipExercise`, `updateSessionNote`, and
  `updateRpe`: no app or test callers were found in the tagged source.
- `loadRecommendationProvider`: no callers found.
- `engineWeightSuggestionProvider`: test callers only; production uses the
  routine-aware suggestion provider. Migrate relevant tests before removal.
- Flutter `TrainingEngineController.ingestSleep` and `ingestHrv`: no production
  callers. Health fetching ingests directly into the engine.
- Engine `handleMissedSession` and `adjustSessionForFatigue`, their helper modules,
  and wrapper APIs: no app callers; package tests exercise them. Remove only if
  these unconnected features are outside the intended product scope. The
  missed-session helper also ignores its `now` argument despite documenting
  date-aware behavior.

Keep Smart Planner, the training engine, heatmap, readiness, and progress paths:
the iOS app calls them. Debug UI is a separate product choice. Do not remove
historical workout fields or archived exercises because their mutation API is
unused. iOS-only cleanup does not justify deleting shared domain behavior.

## Executed reproduction

The read-only diagnostic is `tool/review/verify_training_replay.dart`. From the
repository root, after resolving `packages/training_engine` dependencies, run:

```bash
dart --packages=packages/training_engine/.dart_tool/package_config.json tool/review/verify_training_replay.dart
```

It uses fixed synthetic inputs, does not read user data, and writes no files.
It checks direct/replayed cardio fatigue and bounded/recomputed duration. It
returns exit code 1 when either invariant fails. The reviewed TestFlight baseline
fails both checks, as expected:

```json
{
  "cardioReplay": {
    "passed": false,
    "directFatigue": 19.58768450965083,
    "replayedFatigue": 50.14447234470614
  },
  "boundedDuration": {
    "passed": false,
    "originalSeconds": 1800,
    "storedSeconds": 1800,
    "recomputedSeconds": 1080,
    "supersetApplied": true
  }
}
```

These checks are not registered as passing baseline tests. Keep their expected
invariants when implementing the repairs; do not change expected values to
accept the current divergence.

## Test fixture repairs

The baseline engine failure came from ingesting a fixed March 2026 session and
querying readiness at the live date, after ACWR had decayed to unavailable. The
focused test now queries at its fixture session's end. The original assertion is
unchanged, and the focused test passed.

The four dashboard failures mixed an April 2026 workout with current health data.
`test/features/dashboard/training_readiness_card_test.dart` now uses one recent
per-test timestamp for app session, engine session, and health records. Original
assertions are unchanged. The main review's verification record owns the final
rerun results.

Production defects D1-D7 remain open for the proposed implementation phase.
