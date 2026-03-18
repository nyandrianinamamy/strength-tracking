# UI Refactoring Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Refactor all screens to faithfully match the mockups in `Screens/` directory.

**Architecture:** Foundation-first approach — update theme and shared widgets first, then refactor each screen top-down. No behavior changes, only visual. Verify each milestone with Playwright screenshots against `Screens/*.png`.

**Tech Stack:** Flutter 3.x, google_fonts (Lexend), Riverpod, GoRouter. Playwright for visual verification on `localhost:8080`.

---

### Task 1: Add google_fonts dependency and configure Lexend font

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/src/core/theme/app_theme.dart`
- Modify: `lib/src/app/app.dart`

**Step 1: Add google_fonts to pubspec.yaml**

In `pubspec.yaml`, add under dependencies:
```yaml
  google_fonts: ^6.2.1
```

**Step 2: Run flutter pub get**

Run: `flutter pub get`
Expected: Dependencies resolved successfully

**Step 3: Update app_theme.dart with Lexend font and refined tokens**

Replace entire `lib/src/core/theme/app_theme.dart` with:
- Lexend as default text theme via `GoogleFonts.lexendTextTheme()`
- Colors: primary `#257BF4`, surface `#F8FAFD`, ink `#0F172A`, border `#E2E8F0`
- Card: borderRadius 16, border `#E2E8F0`, elevation 0, subtle shadow via `CardThemeData`
- Input: borderRadius 12, subtle border
- Chip: no side border when selected, rounded-full
- NavigationBar: no indicator, uppercase label style, slate-400 inactive, primary active
- AppBar: transparent/surface background for shell screens

**Step 4: Update app.dart to use the theme**

Ensure `app.dart` applies `AppTheme.light()` and the google_fonts text theme.

**Step 5: Hot restart and Playwright screenshot**

Run Playwright to screenshot `localhost:8080` — verify font changed globally.

**Step 6: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/src/core/theme/app_theme.dart lib/src/app/app.dart
git commit -m "feat: add Lexend font and refine theme tokens"
```

---

### Task 2: Update shared widgets (common_widgets.dart)

**Files:**
- Modify: `lib/src/shared/widgets/common_widgets.dart`

**Step 1: Update PageSection widget**

Add a left vertical blue bar (4px wide, 24px tall, rounded-full) before the title text. Accept optional `trailing` widget for counts/actions on the right.

**Step 2: Update MetricCard widget**

Redesign to match designs: icon top-right (not top-left), label in small uppercase, large bold value, trending indicator as a small chip/badge (accepts `badge` widget parameter). Primary blue accent on left border.

**Step 3: Update EmptyStateCard**

Add dashed border variant (accepts `dashed` bool parameter) for "create new" placeholder cards with centered icon + title + description layout.

**Step 4: Add new shared widgets**

- `SectionHeader` — title with left blue bar + optional trailing count
- `DashedBorderCard` — card with dashed border, light primary/5 bg, centered content
- `StatCard` — compact stat display with label/value/subtext and optional left border accent
- `DigitalTimer` — minutes:seconds display in bordered containers
- `CategoryChips` — horizontal scrollable chips with selected/unselected styling

**Step 5: Hot restart and verify widgets compile**

Run: `flutter analyze`
Expected: No errors

**Step 6: Commit**

```bash
git add lib/src/shared/widgets/common_widgets.dart
git commit -m "feat: update shared widgets to match design system"
```

---

### Task 3: Update App Shell / Bottom Navigation

**Files:**
- Modify: `lib/src/shared/widgets/app_shell_scaffold.dart`

**Step 1: Restyle bottom NavigationBar**

- Remove M3 indicator pill (set `indicatorColor: Colors.transparent`)
- Labels: uppercase, 10px, bold (FontWeight.w700)
- Active color: primary blue, inactive: slate-400 (`Color(0xFF94A3B8)`)
- Icon theme: outlined icons when inactive, filled when active (use separate icon pairs in destinations)

**Step 2: Update destination icons**

```
Dashboard: Icons.home_outlined / Icons.home_rounded
Routines:  Icons.fitness_center_outlined / Icons.fitness_center_rounded
Exercises: Icons.list_alt_outlined / Icons.list_alt_rounded
Progress:  Icons.insights_outlined / Icons.insights_rounded
```

Use `NavigationDestination(selectedIcon:, icon:)` for active/inactive pairs.

**Step 3: Playwright screenshot of bottom nav**

Verify: uppercase labels, no indicator pill, correct colors.

**Step 4: Commit**

```bash
git add lib/src/shared/widgets/app_shell_scaffold.dart
git commit -m "feat: polish bottom navigation to match designs"
```

---

### Task 4: Refactor Dashboard Screen

**Files:**
- Modify: `lib/src/features/dashboard/dashboard_screen.dart`

**Step 1: Add profile header**

Replace the current "Train with intent" heading with:
- Row: CircleAvatar (48px, primary blue border-2, placeholder person icon) on left
- Column: "Welcome back," in small gray text, "Alex" in bold large text
- Trailing: IconButton notification bell with small red dot (using Stack + Positioned + 8px red Container)

**Step 2: Restyle stats grid**

Update MetricCard usage to show:
- "Workouts: 12" with "+2" trending chip (small Container with primary/10 bg, primary text, up arrow)
- "New PRs: 3" with "New" badge (small primary filled container)

**Step 3: Restyle Next Workout card**

- Keep dark bg (slate-900 `#0F172A`)
- Category label: uppercase, primary blue, small, letter-spacing 1.5
- Workout name: `headlineSmall`, white, bold, italic (`fontStyle: FontStyle.italic`)
- Metadata: "60-75 mins - 6 Exercises" with schedule icon
- Button: "START SESSION" with play arrow icon, primary blue

**Step 4: Restyle Recent Workouts section**

- Use updated PageSection with blue bar
- Cards: CircleAvatar with fitness icon, name bold, date/duration subtitle, volume + "Volume" trailing

**Step 5: Polish Frequency Calendar**

- Add month selector row: left chevron, "March 2026" center, right chevron (non-functional, visual only for now)

**Step 6: Restyle Recent PRs section**

- Trophy CircleAvatar (primary/10 bg, primary icon)
- Exercise name, date subtitle
- Weight x reps + 1RM trailing

**Step 7: Playwright screenshot and compare with `Screens/dashboard_with_frequency/screen.png`**

**Step 8: Commit**

```bash
git add lib/src/features/dashboard/dashboard_screen.dart
git commit -m "feat: refactor dashboard to match design mockup"
```

---

### Task 5: Refactor Exercises Screen

**Files:**
- Modify: `lib/src/features/exercises/exercises_screen.dart`

**Step 1: Replace header with sticky-style title**

- Remove description text
- Title "Exercises" centered/large, bold
- Keep "New Exercise" button but style as primary icon button (or move to FAB later)

**Step 2: Restyle search bar**

- Gray fill (`#F1F5F9`), rounded-xl (16px), search icon prefix, no visible border

**Step 3: Use CategoryChips shared widget**

- Selected = primary fill + white text
- Unselected = white bg + subtle border

**Step 4: Update section headers**

- Use PageSection with left blue vertical bar
- Add exercise count on right in gray text

**Step 5: Restyle exercise cards**

- Replace CircleAvatar with a 64x64 rounded-lg placeholder (gray bg with fitness icon centered)
- Name bold, muscles in small gray text below
- PopupMenuButton trailing (keep existing)

**Step 6: Playwright screenshot and compare with `Screens/exercise_list_light_updated/screen.png`**

**Step 7: Commit**

```bash
git add lib/src/features/exercises/exercises_screen.dart
git commit -m "feat: refactor exercises screen to match design"
```

---

### Task 6: Refactor Routines Screen

**Files:**
- Modify: `lib/src/features/routines/routines_screen.dart`

**Step 1: Add "Create New Routine" dashed card**

- At top of list, before routines
- DashedBorderCard with add icon in circular primary/10 container, "Create New Routine" title, description text
- onTap navigates to `/routine/new`

**Step 2: Restyle routine cards**

- Left side: 56x56 rounded container with gray bg + fitness icon
- Center: routine name (bold), "X exercises - Y min" with dot separator
- Right side: circular play button (40px, primary blue bg, white play icon)
- Remove the exercise chips Wrap and Edit/Start button row
- Keep popup menu for edit/archive

**Step 3: Restyle search + chips (reuse CategoryChips)**

**Step 4: Playwright screenshot and compare with `Screens/workout_library_with_routines/screen.png` and `Screens/workout_routine_list_updated_layout/screen.png`**

**Step 5: Commit**

```bash
git add lib/src/features/routines/routines_screen.dart
git commit -m "feat: refactor routines screen to match design"
```

---

### Task 7: Refactor Active Workout Screen

**Files:**
- Modify: `lib/src/features/workout/active_workout_screen.dart`

**Step 1: Restyle header card**

- White bg instead of dark (or keep dark — check design). Exercise name centered with "SET X OF Y" as a small badge below (Container with primary/10 bg, primary text, rounded-full).
- Close button on left, sync icon on right in AppBar

**Step 2: Add rest timer display**

- Replace the text-based rest timer with DigitalTimer widget
- "REST TIMER" label in small uppercase primary text
- Large minute:second display in bordered containers
- Primary blue for active seconds

**Step 3: Restyle input area as 3-column grid**

- Column 1: "WEIGHT (KG)" label + tall input (centered text, bold)
- Column 2: "REPS" label + tall input (centered text, bold)
- Column 3: Primary blue "LOG" button with check icon (same height as inputs)
- Remove the separate "Log Set" full-width button

**Step 4: Replace set note with dashed "ADD COMMENT" button**

- Full-width, dashed border, chat icon + "ADD COMMENT" text
- On tap, show a dialog or expand inline TextField

**Step 5: Restyle previous performance section**

- Group by date headers
- Each entry: set number left, "95 kg x 10 reps" center, time right
- "PB" badge (small primary container) for personal bests

**Step 6: Move session notes to less prominent position or remove from main flow**

**Step 7: Playwright screenshot and compare with `Screens/active_workout_switched_variant/screen.png`**

**Step 8: Commit**

```bash
git add lib/src/features/workout/active_workout_screen.dart
git commit -m "feat: refactor active workout screen to match design"
```

---

### Task 8: Refactor Workout Summary Screen

**Files:**
- Modify: `lib/src/features/workout/workout_summary_screen.dart`

**Step 1: Add hero section**

- Large CircleAvatar (128px) with 4px primary blue border, primary/10 bg, premium icon inside
- Workout name below, large bold text
- "New Personal Record!" badge (if PRs exist): Container with primary/10 bg, trending_up icon + text, rounded-full

**Step 2: Restyle stats grid as 3-column**

- Each StatCard: primary blue left border (3px), label uppercase small, large bold value, sub-unit text (KG, DURATION, TOTAL)
- White bg, subtle border

**Step 3: Make PR highlights horizontally scrollable**

- SingleChildScrollView(horizontal) with Row of PR cards
- Each card: fixed width ~180px, exercise name, weight x reps in large primary text, estimated 1RM below

**Step 4: Restyle exercise breakdown**

- Card header: exercise name + set count badge (primary bg, white text, rounded-full)
- Set list below as 2-column grid or simple column
- PR sets in bold primary text

**Step 5: Restyle RPE section**

- Card with primary/5 bg
- "How did it feel? (RPE)" title
- "Easy" left label, "Hard" right label
- Visual progress bar: primary blue fill to current position, circular handle
- Replace Slider with custom LinearProgressIndicator + GestureDetector (or keep Slider with custom theme)

**Step 6: Restyle action buttons**

- Full-width filled "Finish & Go Home" with checkmark icon
- Full-width outlined "View Progression Charts" below

**Step 7: Playwright screenshot and compare with `Screens/workout_summary_clean/screen.png`**

**Step 8: Commit**

```bash
git add lib/src/features/workout/workout_summary_screen.dart
git commit -m "feat: refactor workout summary screen to match design"
```

---

### Task 9: Refactor Progress Screen

**Files:**
- Modify: `lib/src/features/progress/progress_screen.dart`

**Step 1: Restyle tab navigation**

- Use TabBar with custom indicator: primary blue underline (2px, matches tab width)
- Active text: primary blue, bold
- Inactive text: slate-500

**Step 2: Restyle stats summary cards**

- Light primary/5 bg, primary/10 border
- Large bold value, descriptive subtitle
- Arrange as 2-column grid

**Step 3: Polish calendar section**

- Reuse the updated WorkoutFrequencyCalendar with month selector

**Step 4: Playwright screenshot and compare with `Screens/progress_tracking_updated/screen.png`**

**Step 5: Commit**

```bash
git add lib/src/features/progress/progress_screen.dart
git commit -m "feat: refactor progress screen to match design"
```

---

### Task 10: Refactor Exercise Editor Screen

**Files:**
- Modify: `lib/src/features/exercises/exercise_editor_screen.dart`

**Step 1: Restyle muscle group selection**

- Wrap of pill buttons (rounded-full)
- Selected: primary blue bg, white text
- Unselected: slate-200 bg, dark text

**Step 2: Restyle equipment as 2-column grid**

- GridView with crossAxisCount 2, gap 12
- Each item: Container with checkbox + label, pill shape, border

**Step 3: Restyle instructions textarea**

- Minimum height 160px
- Placeholder text describing what to include

**Step 4: Add Save button styling**

- AppBar "Save" button: primary blue, rounded-full, px-20 py-8

**Step 5: Playwright screenshot and compare with `Screens/new_exercise_creation_light/screen.png`**

**Step 6: Commit**

```bash
git add lib/src/features/exercises/exercise_editor_screen.dart
git commit -m "feat: refactor exercise editor to match design"
```

---

### Task 11: Refactor Routine Editor Screen

**Files:**
- Modify: `lib/src/features/routines/routine_editor_screen.dart`

**Step 1: Restyle exercise cards**

- Left: 56x56 placeholder image (gray bg, rounded-lg, fitness icon)
- Center: exercise name bold, muscle groups small gray
- Right: delete icon button (gray, hover red)
- Stepper row below: 3 columns with small circular +/- buttons (24px, gray bg, rounded-full)

**Step 2: Add dashed "add more exercises" placeholder**

- Full-width, dashed border, centered add icon + "Tap to add more exercises"
- onTap opens exercise picker

**Step 3: Add summary metrics**

- Row: schedule icon + "Estimated duration: X min" | fitness icon + "Total volume: ~X kg"
- Primary blue icons, slate-500 text

**Step 4: Add full-width "Create Routine" button at bottom**

- Primary blue, white text, shadow, icon + text centered

**Step 5: Playwright screenshot and compare with `Screens/exercise_builder_fixed_layout/screen.png`**

**Step 6: Commit**

```bash
git add lib/src/features/routines/routine_editor_screen.dart
git commit -m "feat: refactor routine editor to match design"
```

---

### Task 12: Final verification pass

**Step 1: Run flutter analyze**

Run: `flutter analyze`
Expected: No errors

**Step 2: Run existing tests**

Run: `flutter test`
Expected: All tests pass (existing behavior unchanged)

**Step 3: Playwright screenshot all screens**

Take screenshots of: dashboard, exercises, routines, active workout (if session exists), progress, exercise editor, routine editor

**Step 4: Visual comparison against all Screens/*.png**

Note any remaining gaps.

**Step 5: Fix any gaps found**

**Step 6: Final commit**

```bash
git add -A
git commit -m "fix: final UI polish after visual review"
```
