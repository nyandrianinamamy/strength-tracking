# Apple Watch Companion — Design Document

**Date:** 2026-03-19
**Status:** Approved

## Overview

Native Swift WatchOS companion app for StrengthApp that displays workout information and allows set logging from the wrist during active sessions. Phone starts the workout; Watch joins automatically.

## Architecture

### Communication Stack

```
Flutter (Dart) ←MethodChannel→ Swift (iOS) ←WCSession→ Swift (WatchOS)
                "com.strengthapp/watch"
```

- **WatchSyncService** (Dart): listens to `AppStateController`, pushes session snapshots over MethodChannel
- **WatchSessionManager** (Swift, iOS): WCSession delegate, bridges Dart ↔ Watch
- **WorkoutSessionManager** (Swift, WatchOS): receives snapshots, caches locally, sends logged sets back

### Data Flow

**Phone → Watch** (on session start + after every state change):
- Full session snapshot with all exercises, completed sets, locale, unit, weight increment

**Watch → Phone** (on set log):
- `log_set` message with exerciseId, setNumber, weightKg, reps, completedAt timestamp

**Session lifecycle:**
- Phone creates active session → Watch wakes and displays workout
- Phone sends `session_end` → Watch shows "Workout Complete" briefly → idle state

## Data Contracts

### Session Update (Phone → Watch)

```json
{
  "type": "session_update",
  "session": {
    "routineId": "abc-123",
    "routineName": "Push Day",
    "startedAt": "2026-03-19T10:30:00Z",
    "currentExerciseIndex": 1,
    "exercises": [
      {
        "exerciseId": "ex-1",
        "name": "Bench Press",
        "exerciseType": "strength",
        "targetSets": 4,
        "targetReps": 8,
        "targetDurationSeconds": null,
        "restSeconds": 90,
        "recommendedWeightKg": 80.0,
        "completedSets": [
          { "setNumber": 1, "weightKg": 80.0, "reps": 8, "completedAt": "2026-03-19T10:35:00Z" },
          { "setNumber": 2, "weightKg": 80.0, "reps": 7, "completedAt": "2026-03-19T10:38:12Z" }
        ]
      }
    ]
  },
  "locale": "en",
  "unit": "kg",
  "weightIncrement": 2.5
}
```

### Log Set (Watch → Phone)

```json
{
  "type": "log_set",
  "exerciseId": "ex-1",
  "setNumber": 3,
  "weightKg": 82.5,
  "reps": 8,
  "completedAt": "2026-03-19T10:41:30Z"
}
```

### Log Timed Set (Watch → Phone)

```json
{
  "type": "log_timed_set",
  "exerciseId": "ex-5",
  "setNumber": 2,
  "durationSeconds": 45,
  "completedAt": "2026-03-19T10:50:00Z"
}
```

### Session End (Phone → Watch)

```json
{
  "type": "session_end"
}
```

## WatchOS UI

### Single Screen Layout (per exercise, swipeable)

```
┌──────────────────────────┐
│                          │
│    ⏱ Resting: 1:30       │  ← Rest timer pill (visible after logging)
│                          │
│       SET 3/4            │  ← Set progress
│  Barbell Back Squat      │  ← Exercise name (bold)
│    100kg  x  8 reps      │  ← Weight (accent color) + reps
│                          │
│  ┌────────────────────┐  │
│  │     LOG SET        │  │  ← Blue button
│  │ CONFIRM WEIGHT &   │  │
│  │      REPS          │  │
│  └────────────────────┘  │
│                          │
│  NEXT          SESSION   │
│  Bench Press     12:45   │  ← Next exercise + elapsed time
│         • ● •            │  ← Page dots
└──────────────────────────┘
```

### Timed Exercise Layout

```
┌──────────────────────────┐
│                          │
│       SET 2/3            │
│      Plank Hold          │
│                          │
│       0:45               │  ← Countdown (large)
│                          │
│  ┌────────────────────┐  │
│  │      START         │  │  ← Tap to start → becomes STOP
│  └────────────────────┘  │
│                          │
│  NEXT          SESSION   │
│  Crunches        12:45   │
│         • ● •            │
└──────────────────────────┘
```

- START → countdown begins → button becomes STOP
- Countdown hits 0 → auto-logs set, haptic buzz, shows rest timer
- STOP tapped early → logs partial duration

### Idle State (no active workout)

```
┌──────────────────────────┐
│                          │
│      StrengthApp         │
│                          │
│   No active workout      │
│   Start one on your      │
│        iPhone            │
│                          │
└──────────────────────────┘
```

### Interaction

- **Swipe left/right** to navigate between exercises (horizontal paging with page dots)
- **Digital Crown** adjusts weight or reps:
  - Tap weight or reps to select it
  - Scroll Crown to increment/decrement
  - Weight steps by `weightIncrement` (2.5kg or 5lbs)
  - Reps steps by 1
  - Haptic at min/max boundaries (weight ≥ 0, reps ≥ 1)
- **Tap "Log Set"** to confirm and log
- **Pull down** from top → reveals "Force Sync" button → tap to confirm → haptic confirmation

### Haptics

- **Rest timer**: haptic tap at 3, 2, 1 seconds remaining
- **Set logged**: confirmation haptic
- **Force sync**: confirmation haptic
- **Timed exercise complete**: buzz when countdown hits 0
- **Crown boundaries**: haptic at min/max values
- **Connection restored**: haptic tap

## Offline Behavior

### When Watch loses connection to phone:

1. Watch keeps working from cached session data in UserDefaults
2. Sets logged offline are queued locally with `completedAt` timestamps
3. Rest timer and session elapsed timer keep working (timestamp-based computation)

### When connection restores:

1. Watch sends queued `log_set` messages via `WCSession.transferUserInfo` (guaranteed FIFO delivery)
2. Phone processes them through `WorkoutController.logSet()`
3. Phone sends updated session snapshot → Watch replaces its cache
4. Duplicate set detection by matching `exerciseId + setNumber` — phone wins

### Force Sync

- Pull down from top of screen → "Force Sync" button appears
- Tap to confirm → sends all queued sets + requests fresh snapshot
- Pull down without tapping → retracts automatically

### What the Watch does NOT do offline:

- Cannot start a new workout
- Cannot add/remove exercises
- Cannot end the session

## Error States

| State | Watch Display |
|-------|-------------|
| No phone paired | "Open StrengthApp on your iPhone" |
| Phone app not installed | "Install StrengthApp on your iPhone" |
| No active session | "No active workout — Start one on your iPhone" |
| Connection lost mid-workout | Disconnected icon in corner, workout continues from cache |
| Connection restored | Icon disappears, haptic confirmation |
| Force sync fails | "Sync failed — try again" toast, auto-dismisses |
| Session ended on phone | "Workout Complete" for 3 seconds → idle state |

## Localization (EN/FR)

Phone sends `locale` in session payload. Watch uses hardcoded Swift dictionary keyed by locale.

| Key | EN | FR |
|-----|----|----|
| resting | Resting | Repos |
| set_of | SET %d/%d | SERIE %d/%d |
| log_set | LOG SET | VALIDER |
| confirm_weight_reps | CONFIRM WEIGHT & REPS | CONFIRMER POIDS & REPS |
| next | NEXT | SUIVANT |
| session | SESSION | SESSION |
| reps | reps | reps |
| force_sync | Force Sync | Forcer la synchro |
| sync_failed | Sync failed — try again | Echec synchro — reessayer |
| no_active_workout | No active workout | Aucun entrainement actif |
| start_on_iphone | Start one on your iPhone | Lancez-en un sur votre iPhone |
| workout_complete | Workout Complete | Entrainement termine |
| start | START | DEMARRER |
| stop | STOP | STOP |

Exercise names come pre-translated from the phone's existing translation system.

## Weight Pre-fill Logic

- First set of an exercise → use `recommendedWeightKg` from routine prescription
- Subsequent sets → use weight from the previous completed set
- If no recommendation and no previous set → default to 0

## Technology

- **WatchOS app**: SwiftUI + WCSession (Watch Connectivity)
- **iOS bridge**: Swift WCSession delegate + FlutterMethodChannel
- **Dart bridge**: MethodChannel service integrated with AppStateController
- **Minimum targets**: iOS 15.0+, WatchOS 8.0+
- **Local cache**: UserDefaults on Watch
- **No Firebase on Watch** — all data flows through the phone
