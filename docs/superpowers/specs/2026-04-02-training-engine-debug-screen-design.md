# Training Engine Debug Screen Design

Date: 2026-04-02
Status: Proposed

## Goal

Add a dedicated in-app screen that exposes the current training engine internals used to compute today's state. This screen is meant for debugging and validation while comparing the engine-backed dashboard outputs with expected behavior.

The screen should:
- be reachable from the dashboard through a visible button in all build types
- display only new training-engine data and computations
- help explain how readiness, fatigue, and recommendations were computed today
- remain useful even when the engine has no sessions yet or when engine loading fails

## Non-Goals

- Do not compare engine output side by side with the legacy fatigue provider
- Do not expose this through a dev-only flag
- Do not replace the existing dashboard cards
- Do not introduce editing or mutation actions on engine state from this screen

## User Need

The dashboard heatmap now uses the new training engine, and the displayed fatigue can differ from the legacy heuristic. We need a first-class debugging surface that makes the engine's internal state inspectable from the app itself, without needing logs or local test fixtures.

## Entry Point

### Dashboard Access

Add a visible button on the dashboard that navigates to the debug screen in all build types.

Recommended placement:
- as a secondary action near the `Muscle Fatigue` and `Adaptive Readiness` area
- labeled clearly, for example `Engine Debug`

The button should feel intentionally diagnostic rather than like a primary user feature.

### Routing

Add a dedicated route:

`/debug/training-engine`

This route should be accessible through the existing GoRouter setup and should render as a normal full-screen page.

## Screen Structure

The screen should be a single vertically scrollable page with clearly separated sections. It should favor readable structured data over raw JSON.

### 1. Engine Status

Purpose:
- answer whether the engine is loaded and what state it currently holds

Fields:
- sessions ingested
- last updated timestamp
- sleep history count
- HRV history count
- daily loads count
- fatigue log muscle count
- e1RM-tracked exercise count
- last top set count

If the engine is unavailable:
- show the error message
- still render the page shell and section headers so the failure is diagnosable

### 2. Readiness Breakdown

Purpose:
- explain exactly how today's readiness was produced

Fields:
- readiness score
- confidence
- tier
- flags
- component scores

Presentation:
- a summary card at the top
- then a structured key/value breakdown for every component score present

### 3. Fatigue Breakdown

Purpose:
- explain the muscle fatigue state behind the heatmap

Fields:
- full fatigue map from the engine
- sorted from highest fatigue to lowest
- per-muscle numeric fatigue value if available from the engine query path
- fatigue status classification

Presentation:
- a ranked list of muscles
- each row should include:
  - muscle id
  - status
  - score/value

Additionally:
- show the mapped heatmap payload used by the app UI
- this helps verify whether discrepancies are from engine computation or UI mapping

### 4. Recommendation Breakdown

Purpose:
- inspect what the engine would recommend right now

Scope:
- show recommendation details for exercises that currently have meaningful engine state
- prefer exercises present in `lastTopSets`

Per exercise fields:
- exercise id
- current e1RM
- last top set summary
- recommendation target weight
- target rep range if available
- explanation text

If no exercise recommendations are available:
- show a calm empty state explaining that recommendations appear after relevant training data exists

### 5. Persisted State Summary

Purpose:
- expose the stored engine state shape without dumping unreadable raw JSON first

Fields:
- ACWR state summary
- recent daily loads
- last top sets
- e1RM history summary per exercise

Presentation:
- structured cards/lists
- concise summaries instead of a full raw blob

### 6. Raw Snapshot

Purpose:
- provide a last-resort debugging view when structured summaries are not enough

Presentation:
- collapsed by default
- expandable text block containing pretty-printed serialized engine state

This section is intentionally secondary. The primary screen should remain readable without opening raw JSON.

## Data Sources

The screen should use the existing engine-backed providers and minimal new derived providers where needed.

Primary sources:
- `trainingEngineProvider`
- `readinessProvider`
- `fatigueMapProvider`
- `engineHeatmapDataProvider`

New derived debug providers may be added for:
- sorted fatigue rows
- debug recommendation rows
- raw serialized engine state text

The screen should not reconstruct the engine independently. It should inspect the same provider-backed engine state used elsewhere in the app.

## Failure Behavior

If engine loading fails:
- show a visible error card with the exception text
- continue rendering the rest of the screen shell
- avoid hiding the failure behind generic empty UI

If engine has no ingested sessions:
- still show status and profile-derived state
- readiness should still render if available
- fatigue and recommendation sections should explain why they are empty

## UI Principles

- Debug-first, not marketing-first
- Dense but readable
- Use existing cards/section patterns where possible
- Prefer structured lists and labeled values over decorative visuals
- Make copy explicit and technical enough to support diagnosis

## Files Likely Affected

New:
- `lib/src/features/training_engine/training_engine_debug_screen.dart`
- `test/features/training_engine/training_engine_debug_screen_test.dart`

Modified:
- `lib/src/app/router.dart`
- `lib/src/features/dashboard/dashboard_screen.dart`
- `lib/src/features/training_engine/training_engine_provider.dart`

Possible support additions:
- a small debug view-model/helper file under `lib/src/features/training_engine/`

## Testing Strategy

### Widget Tests

- dashboard shows navigation button
- tapping the button opens the debug screen
- debug screen renders engine status/readiness/fatigue sections with seeded engine state
- debug screen shows a useful error state when engine provider fails

### Provider Tests

- new derived debug providers sort and format fatigue/recommendation data correctly
- raw snapshot provider returns readable serialized state

## Open Decisions Resolved

- The debug screen is visible in all build types
- The screen shows only new engine internals
- The screen should be a full route, not a modal

## Recommended Implementation Order

1. Add route and dashboard button
2. Build a minimal debug screen shell with engine status and readiness
3. Add fatigue breakdown and heatmap payload section
4. Add recommendation section
5. Add persisted state summary and raw snapshot
6. Add widget/provider tests
