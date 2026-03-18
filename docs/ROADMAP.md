# Strength Tracker — Feature Roadmap

## Milestone 1: Core Polish (make existing features solid) — COMPLETE

- [x] **Remove demo seed data** — new users start with empty state, not fake "Alex" data
- [x] **Onboarding flow** — first launch: name input + unit preference selection
- [x] **Unit preference (kg/lbs)** — settings toggle in account section, conversion everywhere
- [x] **Rest timer audio** — triple beep sound when rest timer hits zero
- [x] **Offline indicator** — snackbar on connectivity changes
- [x] **Error handling UI** — save failures caught and logged
- [x] **Exercise reordering in routine editor** — drag handle for reordering
- [x] **App icon & splash screen** — branded blue icon and native splash

## Milestone 2: Workout Experience (make training sessions great)

- [ ] **Superset / circuit support** — group exercises to perform back-to-back
- [ ] **Warmup sets** — mark sets as warmup (excluded from volume/PR tracking)
- [ ] **Drop sets / failure sets** — tag set types for tracking
- [ ] **Auto-fill from last session** — pre-populate weight/reps from previous workout of same routine
- [ ] **Progressive overload suggestions** — "Last time: 80kg x 8 → Try 82.5kg"
- [ ] **Plate calculator** — given a target weight, show plates per side
- [ ] **In-workout notes per exercise** — form cues, technique reminders visible during session
- [ ] **Workout timer pause/resume** — pause session timer for bathroom breaks

## Milestone 3: History & Analytics (make progress visible)

- [ ] **Workout history screen** — full log with calendar view, filter by routine/exercise
- [ ] **Exercise history detail** — tap an exercise → see all sets ever logged, chart over time
- [ ] **1RM progression charts** — line chart per exercise showing estimated 1RM over weeks/months
- [ ] **Volume per muscle group** — weekly volume breakdown by muscle (chest, back, legs, etc.)
- [ ] **Training frequency heatmap** — GitHub-style yearly heatmap of training days
- [ ] **Body weight tracking** — optional daily weight log with trend line
- [ ] **Personal records timeline** — chronological list of all PRs achieved

## Milestone 4: Routine Management (make planning flexible)

- [ ] **Routine templates / presets** — bundled starter routines (PPL, Upper/Lower, 5x5)
- [ ] **Duplicate routine** — copy existing routine as starting point
- [ ] **Routine scheduling** — assign routines to days (Mon = Push, Tue = Pull, etc.)
- [ ] **Training program / mesocycle** — multi-week programs with progressive volume/intensity
- [ ] **Exercise alternatives** — suggest swaps (e.g., no bench → floor press)
- [ ] **Exercise search improvements** — search by muscle, equipment, movement pattern

## Milestone 5: Social & Sharing (make it shareable)

- [ ] **Workout summary sharing** — export summary as image for social media
- [ ] **Export data (JSON/CSV)** — full data export for backup or analysis
- [ ] **Import data** — import from other apps (Strong, JEFIT, etc.)
- [ ] **Public profile (optional)** — share PRs and stats with a link

## Milestone 6: Platform & Quality (make it production-grade)

- [ ] **Dark mode** — full dark theme matching existing dark: design tokens
- [ ] **Delete account** — required for App Store, removes all Firestore data
- [ ] **Firestore real-time sync** — listen for changes instead of load-once, handles multi-device
- [ ] **Rate limiting / quota monitoring** — guard against Firestore free tier limits
- [ ] **Accessibility** — semantic labels, screen reader support, contrast ratios
- [ ] **Localization (i18n)** — English first, structure for adding languages later
- [ ] **Analytics / crash reporting** — Firebase Crashlytics + Analytics
- [ ] **Privacy policy & terms** — hosted page, linked from app settings
- [ ] **App Store & Play Store submission** — screenshots, metadata, review process
