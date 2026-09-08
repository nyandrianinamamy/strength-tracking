# Training engine

Pure Dart domain logic used by the iOS app for fatigue, readiness, load
suggestions, workout history and Smart Planner. The app adapter lives in
`lib/src/features/training_engine/` at the repository root.

Live ingestion and `bootstrapFromHistory` use the same normalization. Typed
strength, local and cardio effort values are retained. Only a missing estimated
strength RPE is backfilled from session RPE or 8.

The app calls `boundSessionToTime(..., allowSupersets: false)`: phone and Watch
workouts execute ordinary rests, so preview estimates must not assume paired
rests. The result always contains a recomputed duration and `fitsWithinLimit`;
a false result must be shown to the user rather than presented as meeting the
requested limit.

## Retained package APIs without app callers

`handleMissedSession`, `adjustSessionForFatigue` and the corresponding
`TrainingEngine` methods remain exported and covered by package tests. They are
not connected to the iOS planner or Watch. They are retained as package APIs;
removing them is a separate API change, not part of the platform cleanup.

`handleMissedSession` currently interprets remaining sessions by numeric
`dayOfWeek > missedDay`. Its `now` argument does not filter by absolute date or
handle week wrapping. It also does not recompute session durations. Do not use
it for automatic calendar rescheduling without implementing and testing those
semantics. Consumers of planner transformation APIs should recompute durations
from returned exercises before displaying them.

The package still supports superset estimates for consumers that implement
paired rests. This does not enable supersets in the app.
