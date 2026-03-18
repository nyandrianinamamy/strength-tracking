# UI Refactoring Design — Match Screen Mockups

**Date:** 2026-03-17
**Approach:** Foundation-first (theme -> shared widgets -> app shell -> screens)
**Verification:** Playwright screenshots against Screens/ reference images after each milestone

## 1. Theme & Typography

- Add Lexend font via `google_fonts` package
- Colors: primary `#257BF4`, surface `#F8FAFD`, ink/slate-900 `#0F172A`, border `#E2E8F0`
- Card border radius: 16px, border color `#E2E8F0`, subtle shadow
- Input border radius: 12px, focus ring primary blue
- Chip: rounded-full, no border when selected (primary fill), border when unselected
- Button styles: filled buttons rounded-full for CTAs, primary blue

## 2. App Shell / Bottom Navigation

- Bottom nav: uppercase labels, 10px font, bold weight
- Icons: outlined inactive, filled active
- Active color: primary blue, inactive: slate-400
- No indicator highlight (remove M3 indicator pill)

## 3. Dashboard Screen

- **Profile header:** CircleAvatar with primary border + "Welcome back," greeting + notification IconButton with red dot
- **Stats grid:** 2-column, cards show icon + label + large value + trending indicator ("+2" chip or "New" badge)
- **Next workout card:** Dark (slate-900) card, category in primary/light label, workout name large bold white, metadata row, primary "START SESSION" button with play icon
- **Recent workouts:** Card per workout with CircleAvatar icon, name, date/duration subtitle, volume trailing
- **Frequency calendar:** Already exists, minor polish (month selector with chevrons)
- **Recent PRs:** Trophy icon CircleAvatar, exercise name, date, weight x reps, 1RM estimate

## 4. Exercises Screen

- Search: gray fill, rounded-xl, search icon prefix
- Category chips: horizontal scroll, selected = primary fill + white text, unselected = white + border
- Section headers: left vertical blue bar (4px wide, 24px tall, rounded) + section title + exercise count on right
- Exercise cards: 64x64 placeholder image (rounded-lg) on left, name + muscles, popup menu on right

## 5. Routines Screen

- Search + category chips (same as exercises)
- "Create New Routine" card: dashed border, light primary/5 background, centered add icon + title + description
- Routine cards: icon placeholder on left (56x56, rounded, gray bg), name + "X exercises - Y min" metadata, circular play button on right (primary blue, size 40)

## 6. Active Workout Screen

- **Header area:** Close button left, exercise name center with "SET X OF Y" badge below, sync button right
- **Rest timer:** "REST TIMER" label in primary, large digital display with minute:second in bordered containers
- **Input grid:** 3 columns — Weight (kg) input, Reps input, LOG button (primary, check icon)
- **Add comment:** Full-width dashed border button with chat icon
- **Previous performance:** Grouped by date, set number + weight x reps + time, "PB" badge for records
- **Bottom bar:** Skip + Finish buttons (existing pattern works)

## 7. Workout Summary Screen

- **Hero:** Large CircleAvatar (128px) with primary border + premium badge, workout name below, "New Personal Record!" badge if PRs
- **Stats grid:** 3-column, each card: label (uppercase small), large bold value, sub-unit text, primary blue left border accent
- **PR highlights:** Horizontal scrollable cards with exercise name, weight x reps in primary, estimated 1RM
- **Exercise breakdown:** Cards with exercise name + set count badge (primary), set-by-set list below
- **RPE section:** Light primary/5 background card, "Easy"/"Hard" labels, visual progress bar with primary fill + draggable handle
- **Actions:** Full-width filled "Finish & Go Home" + outlined "View Progression Charts"

## 8. Progress Screen

- Tab nav: 3 tabs with underline indicator (primary blue border-bottom-2 for active)
- Stats cards: light primary/5 background, primary/10 border, large value + description
- Calendar: reuse shared WorkoutFrequencyCalendar

## 9. Editor Screens

### Exercise Editor
- Muscle groups: Wrap of pill buttons, selected = primary fill + white text, unselected = slate-200 bg
- Equipment: 2-column grid of checkbox items in pill containers
- Instructions: tall textarea (min-height 160px)

### Routine Editor
- Exercise cards: image placeholder + name + muscles + delete button, stepper row below (sets/reps/rest with small circular +/- buttons)
- Dashed "add more exercises" placeholder card
- Summary metrics: estimated duration + total volume with icons
- Full-width "Create Routine" / "Save" button at bottom

## Files Modified

- `lib/src/core/theme/app_theme.dart` — font, colors, component themes
- `lib/src/shared/widgets/common_widgets.dart` — new/updated shared widgets
- `lib/src/shared/widgets/app_shell_scaffold.dart` — bottom nav styling
- `lib/src/features/dashboard/dashboard_screen.dart`
- `lib/src/features/exercises/exercises_screen.dart`
- `lib/src/features/routines/routines_screen.dart`
- `lib/src/features/workout/active_workout_screen.dart`
- `lib/src/features/workout/workout_summary_screen.dart`
- `lib/src/features/progress/progress_screen.dart`
- `lib/src/features/exercises/exercise_editor_screen.dart`
- `lib/src/features/routines/routine_editor_screen.dart`
- `pubspec.yaml` — add google_fonts dependency
