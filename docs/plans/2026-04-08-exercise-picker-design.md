# Exercise Picker Bottom Sheet — Design

**Date:** 2026-04-08
**Status:** Approved

## Problem

Adding, swapping, and creating exercises requires too many screens and taps — both in the routine editor and during active workouts. Creating a new exercise mid-flow forces a full navigation detour.

## Solution

A unified **bottom sheet exercise picker** (`ExercisePickerSheet`) reused across all contexts: routine editor, active workout, and exercise swap.

## Component: ExercisePickerSheet

### Layout (top to bottom)

1. **Drag handle** + title ("Add Exercise" / "Swap Exercise")
2. **Search bar** — text field with debounced filtering (300ms)
3. **Exercise list** — scrollable, sorted by usage frequency
   - Each row: circular **thumbnail** (40px) + **exercise name** + **primary muscle tag chips**
   - When search query has no match: a **"Create \[query\]"** row appears at the top
4. **Quick Create inline form** — expands on tap:
   - Name (pre-filled from search query)
   - Primary muscle group (dropdown/chips)
   - "Create" button — creates and selects in one step
   - All other fields (instructions, secondary muscles, equipment, photo) filled in later via exercise editor

### Behavior

- Opens as modal bottom sheet (70% height, draggable to full) via `showExercisePickerSheet()`
- On exercise tap: returns selected exercise, dismisses sheet
- Shared single function across all call sites

### Thumbnails

- Circular avatar, 40px diameter
- If `photoBase64` exists: decode and display
- If no photo: colored icon based on primary muscle group (muscle-to-icon+color map)

### Search

- Debounced at 300ms, case-insensitive substring match on exercise name
- Empty search: all exercises sorted by usage frequency
- No match: "Create \[query\]" row only

### Animations

- Standard Material `showModalBottomSheet` with `DraggableScrollableSheet`
- Quick-create form expands with `AnimatedCrossFade`

## Integration Points

### Routine Editor

- "Add Exercise" button calls `showExercisePickerSheet()` instead of navigating away
- Each exercise row gets a **swap icon** — opens picker, replaces exercise while preserving sets/reps/rest config
- Reorder and delete unchanged

### Active Workout Screen

- **"Add Exercise" button** at bottom of exercise list — opens picker, appends exercise with default config
- Each exercise header gets a **swap icon** — preserves already-logged sets, adds new exercise going forward

### Exercise List Screen

- No changes — remains the full exercise management screen

## Data & State

### Exercise usage tracking

- Add `lastUsedAt` (DateTime?) and `useCount` (int) to the Exercise model
- Updated on each completed set log
- Picker sorts by `useCount` desc, `lastUsedAt` as tiebreaker
- Defaults to null/0 for existing exercises (no migration needed)

### Quick-create flow

- Creates minimal Exercise (id, name, primaryMuscles) via existing `ExerciseController.addExercise()`
- Immediately available app-wide, syncs to Firestore as usual

### Swap behavior

- **Routine editor:** replaces `exerciseId` in `RoutineExercise`, preserves `targetSets`, `targetReps`, `restSeconds`
- **Active workout:** marks remaining planned sets for old exercise as skipped, inserts new exercise at same position

## Localization

All new strings go through the existing l10n system: picker title, "Create" button, search placeholder, muscle group labels.
