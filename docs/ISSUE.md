## Bugs
[x] Created routine cannot be edited
[x] Adding a new exercise in a routine has overflow on the SETS REPS REST number display
[x] Increasing REST time should keep with 10 seconds increments
[x] No ask for install PWA (works on Chrome; iOS requires manual "Add to Home Screen")
[x] Workout frequency duplicated, no need for it in progress page
[x] Clicking outside of weight and reps input should close the keyboard
[x] Exercises and routines not showing in French language (filter sentinel fix)

## Features
[x] Clicking on a date in workout frequency should show the workout for that date if it exists.
[x] Option to fill with preseed data and clear preseed data.
[x] Delete workout from history (trash icon on summary screen)
[x] Per muscle heatmap with bodychart_heatmap, updated after each session, with color gradient based on sets, weight, reps, volume. Shows fatigue level per muscle group with 48h decay.
[x] Timed exercise support (countdown timer, auto-log, manual log)
[x] Secondary muscles on exercises (50% heatmap contribution)
[x] Recommended weight per exercise in routine (auto-fills active workout)
[x] Editable and deletable logged sets (tap to edit, long-press to delete)
[x] Exercise search in routine editor picker
[x] Force update app button (PWA)
[x] Google/Apple sign-in (link account + sign in to restore data)
[x] Rest timer survives app switches (persisted from set timestamps)
[x] Swipe back disabled in active workout (no accidental exits)
[x] Auto-switch countdown (5s) when all sets completed for an exercise
[x] Active exercise heatmap with pulsing active muscles + fatigue colors
[x] Heatmap legend (info icon → bottom sheet explaining colors)
[x] Multi language (EN/FR with full l10n, all UI strings localized)
[x] Complete pre-seed exercises (60 exercises with translations)
[x] Swap exercise variant (filter by same primary muscles)
[x] Light and dark theme (Auto/Light/Dark toggle in account settings)
[x] Show title for body heat map in dashboard
[x] Swiping left when last exercise should propose to add a new exercise or finish
[ ] Add images for exercises
[ ] Apple watch companion

## Refactor
[x] New active exercise UI with body heatmap, exercise name in AppBar, compact rest timer
