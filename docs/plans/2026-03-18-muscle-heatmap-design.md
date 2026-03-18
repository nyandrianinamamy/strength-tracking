# Muscle Heatmap Design

**Date:** 2026-03-18

## Overview

Dashboard card showing front + back body silhouettes with muscle regions colored by recent training volume with exponential decay.

## Location

Dashboard screen, between stats grid and Next Workout section.

## Visual

- Front and back body silhouettes side by side
- ~10 muscle regions colored by fatigue level
- Front: chest, shoulders, biceps, abs, quads
- Back: upper back/traps, lats, triceps, glutes, hamstrings
- Color scale: gray (no data) → blue (recovered) → green (light) → yellow (moderate) → orange (high) → red (fatigued)
- Small legend bar below: "Recovered → Fatigued"
- No tap interaction (v1)

## Data Model

- For each completed session, calculate volume per muscle group: sets × weight × reps
- Map exercises to muscles via the exercise's `primaryMuscles` field
- Apply exponential decay: volume halves every 48 hours
- Formula: `contribution = volume × 0.5^(hoursElapsed / 48)`
- Sum contributions across all sessions per muscle
- Normalize to 0–1 range across all muscles to determine color intensity

## Implementation

- Create `MuscleHeatmapService` that computes per-muscle fatigue from AppState
- Create SVG paths for front/back body with named muscle regions using CustomPainter
- Create `MuscleHeatmapCard` widget for the dashboard
- Color interpolation from gray → blue → green → yellow → orange → red based on normalized value

## Files

- Create: `lib/src/features/dashboard/muscle_heatmap_card.dart` — widget with CustomPainter
- Create: `lib/src/features/dashboard/muscle_heatmap_service.dart` — fatigue calculation
- Modify: `lib/src/features/dashboard/dashboard_screen.dart` — add card between stats and Next Workout
