# Training Engine Design

**Date:** 2026-04-02
**Status:** Approved
**Based on:** [Algorithmic Modeling for Hypertrophy-Focused Resistance Training](../research/Algorithmic%20Modeling%20for%20Hypertrophy-Focused%20Resistance%20Training_%20Load%20Auto-Regulation%2C%20Fatigue%20Decay%2C%20and%201RM%20Estimation.md)

## Summary

A standalone Dart package (`packages/training_engine/`) implementing six subsystems for intelligent training auto-regulation: e1RM estimation, fatigue decay modeling, ACWR monitoring, readiness scoring, dynamic session planning, and progressive overload. The engine uses materialized state with incremental updates, exposes pure computation functions per subsystem, and integrates with Kotrana via a thin Riverpod adapter layer.

## Design Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Scope | All 6 subsystems | Complete engine in one design pass, implemented incrementally |
| Per-set RPE | Required on every working set | Cleanest data for e1RM and fatigue models |
| Legacy data | Session RPE backfill | Use existing session-level RPE as uniform RPE for all sets; flag as estimated |
| HealthKit | Full: sleep stages, HRV, resting HR | With tiered fallback when data sources are unavailable |
| Session planner | Parallel modes (manual + smart planner) | Manual mode preserved; smart planner opt-in per routine group |
| Architecture | Standalone `packages/training_engine/` | Pure Dart, no Flutter dependency, testable in isolation |
| Onboarding | 6-screen flow collecting profile data | Minimum data for cold-start bootstrapping |

## Architecture: Materialized State with Incremental Updates

The engine maintains a `TrainingState` snapshot updated incrementally via ingestion methods. Each subsystem also exposes standalone pure functions for independent use and testing. State is JSON-serializable for persistence by the host app.

```
packages/training_engine/
├── lib/
│   ├── src/
│   │   ├── models/          # TrainingState, domain types
│   │   ├── e1rm/            # Pure 1RM formulas + composite estimator
│   │   ├── fatigue/         # Exponential decay, activation coefficients, superposition
│   │   ├── acwr/            # EWMA computation, zone classification
│   │   ├── readiness/       # Composite score (ACWR + sleep + manual), pluggable sources
│   │   ├── progression/     # Safety gates -> performance delta -> load prediction
│   │   ├── planner/         # Split generation, time-bounding, substitution
│   │   ├── registry/        # Built-in exercise catalog (~80-100 exercises)
│   │   └── engine.dart      # TrainingEngine facade
│   └── training_engine.dart  # barrel export
└── test/                     # Pure Dart unit tests per subsystem
```

---

## 1. Data Models

### Core Types

```dart
enum MuscleRole { primary, synergist, stabilizer }
enum MuscleSize { small, moderate, large }
enum Sex { male, female }
enum ExperienceLevel { beginner, intermediate, advanced }
enum HypertrophyGoal { hypertrophy, strength, general }

class MuscleActivation {
  final String muscleId;
  final MuscleRole role;
  final double coefficient;     // 1.0 primary, 0.4-0.6 synergist, 0.15-0.25 stabilizer
}

class EngineExercise {
  final String id;
  final String name;
  final List<MuscleActivation> muscleMap;
  final EquipmentClass equipment;   // barbell, dumbbell, cable, machine, bodyweight
  final MovementClass movement;     // compound_lower, compound_upper, isolation
}

class LoggedSet {
  final String exerciseId;
  final double weightKg;
  final int reps;
  final double rpe;                 // 6.0 - 10.0
  final DateTime completedAt;
  final bool rpeEstimated;          // true for legacy backfill
}

class EngineSession {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<LoggedSet> sets;
  final double? sessionRpe;         // legacy, used for backfill
}

class SleepRecord {
  final DateTime date;
  final Duration totalSleep;
  final Duration deepSleep;
  final Duration remSleep;
  final Duration coreSleep;
}

class HrvRecord {
  final DateTime date;
  final double sdnn;
  final double? restingHeartRate;
}

class UserProfile {
  final Sex sex;
  final int age;
  final double bodyWeightKg;
  final ExperienceLevel experience;
  final HypertrophyGoal goal;
  final List<int> availableDays;
  final Duration maxSessionDuration;
  final DateTime createdAt;
}
```

### Materialized State

```dart
class TrainingState {
  final UserProfile profile;
  final Map<String, List<E1rmEstimate>> e1rmHistory;    // last 20 per exercise
  final Map<String, List<FatigueImpulse>> fatigueLog;   // impulses, not current levels
  final List<DailyLoad> dailyLoads;                      // last 35 days
  final EwmaState acwrState;                             // running EWMA values
  final List<SleepRecord> sleepHistory;                  // last 14 days
  final List<HrvRecord> hrvHistory;                      // last 14 days
  final PlannerState? activePlan;
  final DateTime lastUpdated;
  final int sessionsIngested;
}
```

Key design: `fatigueLog` stores impulses (magnitude + timestamp), not current levels. Current F(t) is computed at query time via exponential decay with superposition. This avoids stale state.

---

## 2. e1RM Estimation

### Four Formulas (RIR-Adjusted)

All formulas receive `rMax = reps + (10 - rpe)` instead of raw reps:

- **Epley:** `weight * (1 + rMax / 30)`
- **Brzycki:** `weight * (36 / (37 - rMax))` — excluded when rMax > 30
- **Lander:** `(100 * weight) / (101.3 - 2.67123 * rMax)`
- **Lombardi:** `weight * pow(rMax, 0.10)`

### Composite Estimate

Weighted average across formulas, weights vary by rep range:

| rMax Range | Epley | Brzycki | Lander | Lombardi |
|---|---|---|---|---|
| 1-5 (heavy) | 0.20 | 0.35 | 0.30 | 0.15 |
| 6-10 (moderate) | 0.30 | 0.25 | 0.25 | 0.20 |
| 11-15 (light) | 0.35 | 0.10 | 0.30 | 0.25 |
| >15 | 0.30 | 0.05 | 0.30 | 0.35 |

### Rolling e1RM

Weighted rolling average of last 20 estimates per exercise:
- Exponential recency decay (half-life ~14 days)
- Heavy-set estimates weighted higher (confidence factor)
- Legacy estimates (estimated RPE) weighted at 50%

### Guards

- Brzycki excluded when rMax > 30
- Sets with rMax > 20 get low confidence
- Single-rep max sets: e1RM = weight directly

---

## 3. Fatigue Decay

### Fatigue Generation

Per set: `setStress = weightKg * reps * (rpe / 10)`

Distributed across muscles by activation coefficient, then normalized against e1RM to produce F0 (0-100). Calibrated so a typical hypertrophy session (4 exercises, 4x10 @ RPE 8) produces F0 ~ 75-85 for primary muscles.

### Exponential Decay

```
F(t) = F0 * exp(-t / tau)
```

Constants derived from `tau = -T_recovery / ln(0.05)`:

| Muscle Size | Recovery Time | tau (hours) | Examples |
|---|---|---|---|
| Small | 36h | 12.01 | Biceps, lateral delts, calves, forearms |
| Moderate | 48h | 16.01 | Triceps, rear delts, traps, abs, hamstrings |
| Large | 72h | 24.02 | Quads, glutes, lats, pectorals, erector spinae |

Age modifier: `effectiveTau = baseTau * ageRecoveryModifier(age)` (1.0 at age 30, up to 1.4 at 50+).

### Superposition

Multiple impulses for the same muscle sum naturally — `currentFatigue()` iterates all impulses and sums their decayed contributions, capped at 100.

### Pruning

Impulses older than 7 days pruned on serialization (< 0.1% contribution by then).

### Heatmap Output

```dart
class FatigueStatus {
  final double level;                    // 0-100
  final double hue;                      // 120 * (1 - level/100): red->green
  final Duration estimatedFullRecovery;  // time until level < 5
  final RecoveryPhase phase;             // acute, recovering, ready
}
```

---

## 4. ACWR (Acute to Chronic Workload Ratio)

### EWMA Computation

```
lambda_acute  = 2 / (7 + 1)   ~ 0.25
lambda_chronic = 2 / (28 + 1)  ~ 0.069

ewma_acute  = lambda_a * todayLoad + (1 - lambda_a) * ewma_acute
ewma_chronic = lambda_c * todayLoad + (1 - lambda_c) * ewma_chronic

ACWR = ewma_acute / ewma_chronic
```

Rest days contribute load = 0, naturally decaying acute faster than chronic.

### Zones

| ACWR Range | Zone | Progression Gate |
|---|---|---|
| < 0.80 | Undertraining | Open, suggest volume increase |
| 0.80 - 1.30 | Optimal | **Open** — standard progression |
| 1.31 - 1.50 | Caution | **Locked** — maintain loads, cap volume |
| > 1.50 | Danger | **Locked + deload** — 30-50% volume reduction |

### Cold Start

- < 7 days: ACWR returns null, gate skipped
- 7-21 days: low confidence, widened thresholds (0.80-1.50 = optimal)
- > 21 days: full confidence, standard thresholds

---

## 5. Readiness

### Tiered Composite Score (0-100)

Automatically adapts to available data sources:

| Tier | Available Data | Weights |
|---|---|---|
| Full | ACWR + Sleep + HRV | 40% / 35% / 25% |
| No HRV | ACWR + Sleep | 55% / 45% |
| No Sleep | ACWR + HRV | 60% / 40% |
| ACWR only | ACWR | 100% |
| Cold start | Nothing | Returns null, conservative defaults |

Detection-based: the engine checks if recent records exist (last 7 days), not user configuration.

### Manual Slider

Universal fallback overlay ("how do you feel?" 1-5). Weight varies:
- No other sources: 100%
- 1 other source: 30%
- 2 other sources: 15%
- All sources present: 10%

### Component Scoring

**Sleep** (14-day weighted average):
- Total duration vs 7-9h target: 60%
- Deep sleep ratio (target >= 15%): 25%
- REM sleep ratio (target >= 20%): 15%
- Acute deprivation penalty: -20 points if < 5h last night

**HRV** (personal baseline comparison):
- SDNN vs 14-day rolling mean (+/- SD bands)
- Resting HR trend: -10 penalty if rising > 5bpm over 7 days

### Output

```dart
class ReadinessScore {
  final double score;
  final ReadinessConfidence confidence;    // high, moderate, low, unavailable
  final ReadinessTier tier;
  final Map<String, double> componentScores;
  final List<ReadinessFlag> flags;         // acuteSleepDeprivation, risingRestingHR, etc.
}
```

### Downstream Effect

| Score | Gate Effect |
|---|---|
| 70-100 | Open — standard progression |
| 50-69 | Dampened — load increase capped at 50% of normal increment |
| 30-49 | Locked — maintain current load |
| 0-29 | Deload — suggest 10-20% reduction |

---

## 6. Dynamic Session Planner

### Two Modes

- **Manual** (default): user-created routines unchanged. Engine provides per-exercise load recommendations and fatigue warnings.
- **Smart planner** (opt-in per routine group): engine generates and adjusts the weekly split.

### Smart Planner Config

```dart
class PlannerConfig {
  final List<int> availableDays;
  final Duration maxSessionDuration;
  final HypertrophyGoal goal;
  final List<String> preferredExercises;
  final List<String> excludedExercises;
}
```

### Split Selection

| Days | Pattern | Split |
|---|---|---|
| 1-2 | Any | Full Body |
| 3 | Non-consecutive | Full Body |
| 3 | Consecutive | Push/Pull/Legs |
| 4 | Any | Upper/Lower |
| 5+ | Any | Push/Pull/Legs (rotating) |

### Time-Bounding

If estimated duration > max:
1. Reduce isolation rest (3min -> 90s)
2. Pair exercises as supersets (agonist/antagonist)
3. Trim accessory volume (drop 1 set from lowest-priority isolation)

### Missed Session Redistribution

50-75% of missed volume redistributed across remaining sessions in the week, targeted to matching muscle focus.

### Heatmap-Driven Substitution

Before finalizing a session, check fatigue on secondary muscles. If secondary muscle > 50% fatigued, substitute exercise with a variant that avoids that muscle (e.g., barbell deadlift -> seated leg curl to spare erector spinae).

### Exercise Registry

Built-in catalog of ~80-100 exercises with full `MuscleActivation` mappings. Host app can extend with user-created exercises.

---

## 7. Progressive Overload Engine

### Pipeline

```
Step 1: Establish targets (reps, RPE per movement class)
Step 2: Safety gates (fatigue -> ACWR -> readiness) — sequential, short-circuit
Step 3: Performance delta (last session's top set vs targets)
Step 4: Load prediction (inverse e1RM when progression triggered)
Step 5: Equipment rounding (barbell 2.5kg, dumbbell 2kg, machine 5kg)
```

### Target Defaults

| Movement Class | Rep Range | Target RPE |
|---|---|---|
| Compound lower | 6-10 | 8.0 |
| Compound upper | 8-12 | 8.0 |
| Isolation | 10-15 | 8.5 |

### Performance Delta

- **Progression:** hit upper rep bound AND RPE <= target -> increase load
- **Maintenance:** mid-range reps OR hit bound at max effort -> hold
- **Regression:** below lower bound despite RPE >= 9.5 -> decrease 5-10%

### Load Prediction (Inverse Epley)

```
targetRMax = targetRepsHigh + RIR(targetRPE)
suggestedWeight = e1RM / (1 + targetRMax / 30)
```

Rounded to nearest equipment increment.

### Output

```dart
class LoadRecommendation {
  final String exerciseId;
  final double suggestedWeightKg;
  final TargetParams targets;
  final PerformanceDelta delta;
  final GateResult gateResult;
  final double? e1rm;
  final double? previousWeightKg;
  final String explanation;    // "You hit 12 reps @ RPE 7 last time -> +2.5kg"
}
```

---

## 8. TrainingEngine Facade

```dart
class TrainingEngine {
  final ExerciseRegistry registry;

  // Ingestion
  TrainingState ingestSession(EngineSession session);
  TrainingState ingestSleep(SleepRecord record);
  TrainingState ingestHrv(HrvRecord record);

  // Queries
  double? currentE1rm(String exerciseId);
  double currentFatigue(String muscleId, [DateTime? at]);
  Map<String, FatigueStatus> fullFatigueMap([DateTime? at]);
  AcwrStatus? currentAcwr();
  ReadinessScore computeReadiness({double? manualSlider});
  LoadRecommendation recommendLoad(String exerciseId, {TargetParams? overrides});

  // Planner
  WeeklyPlan generatePlan(PlannerConfig config);
  WeeklyPlan handleMissedSession(int missedDay);
  PlannedSession adjustSessionForFatigue(PlannedSession session);

  // State management
  TrainingState get state;
  TrainingState restoreState(Map<String, dynamic> json);
  Map<String, dynamic> serializeState();

  // Bootstrap
  TrainingState bootstrapFromHistory(List<EngineSession> legacySessions);
}
```

---

## 9. Onboarding & User Profile

### Data Collected (6 screens, ~60 seconds)

| Field | Type | Engine Use |
|---|---|---|
| Biological sex | male / female | Baseline strength ratios for cold-start e1RM |
| Age | int | Recovery decay modifier (1.0 at 30, 1.4 at 50+) |
| Body weight | double (kg) | Anchors initial e1RM via strength-to-bodyweight ratios |
| Training experience | beginner / intermediate / advanced | Progression rate, RPE trust, default targets |
| Available days | List<int> | Smart planner split selection |
| Session duration | 30 / 45 / 60 / 90 min | Time-bounding constraint |
| Goal | hypertrophy / strength / general | Default rep ranges and target RPE |

### Cold-Start e1RM Bootstrapping

Population-based strength-to-bodyweight ratios by (exercise_category, sex, experience). Intentionally conservative. Replaced by real data after 2-3 sessions.

### Experience-Based Defaults

| Setting | Beginner | Intermediate | Advanced |
|---|---|---|---|
| Default target RPE | 7.0 (3 RIR) | 8.0 (2 RIR) | 8.5 (1-2 RIR) |
| Progression increment | Conservative | Standard | Inverse e1RM |
| RPE trust weight | 0.5 | 0.8 | 1.0 |
| ACWR cold start | 28 days | 21 days | 14 days |

---

## 10. Host App Integration

### Kotrana Adapter Layer

```
lib/src/features/training_engine/
├── training_engine_provider.dart      # Riverpod provider
├── training_engine_adapter.dart       # AppState <-> Engine mapping
├── healthkit_data_source.dart         # HealthKit -> SleepRecord/HrvRecord
└── widgets/
    ├── load_recommendation_chip.dart
    ├── readiness_card.dart
    ├── acwr_chart.dart
    └── planner_setup_sheet.dart
```

### Model Changes to Kotrana

| Model | Change |
|---|---|
| `CompletedSet` | Add `rpe` field (double?, nullable for migration) |
| `WorkoutSession` | Keep existing `rpe` (session-level, for legacy backfill) |
| `AppState` | No change — `TrainingState` lives separately |
| `Exercise` | No change — mapping in adapter |

### Data Flow

```
User logs set -> WorkoutController.logSet()
  -> AppState updated
  -> Adapter maps CompletedSet -> LoggedSet (with per-set RPE)
  -> TrainingEngine.ingestSession() on session completion
  -> TrainingState updated and persisted

User opens next workout -> recommendLoad(exerciseId)
  -> Full pipeline: gates -> delta -> prediction
  -> LoadRecommendation displayed

HealthKit sync (background) -> ingestSleep() / ingestHrv()
  -> Readiness score updates
```

`TrainingState` is persisted to Firestore alongside `AppState` as a separate document.
