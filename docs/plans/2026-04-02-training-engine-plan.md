# Training Engine Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a standalone Dart package implementing load auto-regulation, fatigue decay, 1RM estimation, ACWR monitoring, readiness scoring, and dynamic session planning for Kotrana.

**Architecture:** Materialized state with incremental updates. Pure Dart package at `packages/training_engine/` with no Flutter dependency. Each subsystem exposes standalone pure functions and is wired together via a `TrainingEngine` facade. Host app integration via thin Riverpod adapter layer.

**Tech Stack:** Dart 3.11+, `dart test` for testing, JSON serialization (hand-written, no codegen).

**Design Doc:** `docs/plans/2026-04-02-training-engine-design.md`

---

## Task 1: Package Scaffold

**Files:**
- Create: `packages/training_engine/pubspec.yaml`
- Create: `packages/training_engine/lib/training_engine.dart`
- Create: `packages/training_engine/lib/src/models/models.dart`
- Create: `packages/training_engine/test/scaffold_test.dart`

**Step 1: Create pubspec.yaml**

```yaml
name: training_engine
description: Hypertrophy-focused training auto-regulation engine for Kotrana.
version: 0.1.0

environment:
  sdk: ^3.11.1

dev_dependencies:
  test: ^1.25.0
```

**Step 2: Create barrel export**

`packages/training_engine/lib/training_engine.dart`:
```dart
library training_engine;
```

**Step 3: Create placeholder models barrel**

`packages/training_engine/lib/src/models/models.dart`:
```dart
// Core domain models for the training engine.
```

**Step 4: Write a smoke test**

`packages/training_engine/test/scaffold_test.dart`:
```dart
import 'package:test/test.dart';

void main() {
  test('package imports without error', () {
    expect(1 + 1, equals(2));
  });
}
```

**Step 5: Run test**

```bash
cd packages/training_engine && dart pub get && dart test
```

Expected: `All tests passed!`

**Step 6: Add package to root pubspec.yaml**

In `pubspec.yaml` (root), add under `dependencies`:
```yaml
  training_engine:
    path: packages/training_engine
```

Then run `flutter pub get` from root.

**Step 7: Commit**

```bash
git add packages/training_engine/ pubspec.yaml pubspec.lock
git commit -m "feat(training-engine): scaffold standalone Dart package"
```

---

## Task 2: Core Enums and Value Types

**Files:**
- Create: `packages/training_engine/lib/src/models/enums.dart`
- Create: `packages/training_engine/lib/src/models/muscle_activation.dart`
- Create: `packages/training_engine/lib/src/models/user_profile.dart`
- Modify: `packages/training_engine/lib/src/models/models.dart`
- Create: `packages/training_engine/test/models/enums_test.dart`

**Step 1: Write tests for enums and MuscleActivation**

`packages/training_engine/test/models/enums_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:training_engine/src/models/enums.dart';
import 'package:training_engine/src/models/muscle_activation.dart';

void main() {
  group('MuscleRole', () {
    test('has three values', () {
      expect(MuscleRole.values.length, equals(3));
    });
  });

  group('MuscleActivation', () {
    test('creates with required fields', () {
      final activation = MuscleActivation(
        muscleId: 'quadriceps',
        role: MuscleRole.primary,
        coefficient: 1.0,
      );
      expect(activation.muscleId, equals('quadriceps'));
      expect(activation.role, equals(MuscleRole.primary));
      expect(activation.coefficient, equals(1.0));
    });

    test('coefficient must be between 0 and 1', () {
      expect(
        () => MuscleActivation(muscleId: 'x', role: MuscleRole.primary, coefficient: 1.5),
        throwsA(isA<ArgumentError>()),
      );
      expect(
        () => MuscleActivation(muscleId: 'x', role: MuscleRole.primary, coefficient: -0.1),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('ExperienceLevel', () {
    test('has three values', () {
      expect(ExperienceLevel.values.length, equals(3));
    });
  });
}
```

**Step 2: Run test to verify it fails**

```bash
cd packages/training_engine && dart test test/models/enums_test.dart
```

Expected: FAIL (imports don't resolve)

**Step 3: Implement enums**

`packages/training_engine/lib/src/models/enums.dart`:
```dart
enum MuscleRole { primary, synergist, stabilizer }

enum MuscleSize { small, moderate, large }

enum EquipmentClass { barbell, dumbbell, cable, machine, bodyweight }

enum MovementClass { compoundLower, compoundUpper, isolation }

enum Sex { male, female }

enum ExperienceLevel { beginner, intermediate, advanced }

enum HypertrophyGoal { hypertrophy, strength, general }

enum RecoveryPhase { acute, recovering, ready }

enum ReadinessConfidence { high, moderate, low, unavailable }

enum AcwrZone { undertraining, optimal, caution, danger }

enum AcwrTrend { rising, stable, falling }

enum PerformanceDelta { progression, maintenance, regression }
```

**Step 4: Implement MuscleActivation**

`packages/training_engine/lib/src/models/muscle_activation.dart`:
```dart
import 'enums.dart';

class MuscleActivation {
  MuscleActivation({
    required this.muscleId,
    required this.role,
    required this.coefficient,
  }) {
    if (coefficient < 0 || coefficient > 1) {
      throw ArgumentError('coefficient must be between 0 and 1, got $coefficient');
    }
  }

  final String muscleId;
  final MuscleRole role;
  final double coefficient;

  Map<String, dynamic> toJson() => {
    'muscleId': muscleId,
    'role': role.name,
    'coefficient': coefficient,
  };

  factory MuscleActivation.fromJson(Map<String, dynamic> json) => MuscleActivation(
    muscleId: json['muscleId'] as String,
    role: MuscleRole.values.byName(json['role'] as String),
    coefficient: (json['coefficient'] as num).toDouble(),
  );
}
```

**Step 5: Implement UserProfile**

`packages/training_engine/lib/src/models/user_profile.dart`:
```dart
import 'enums.dart';

class UserProfile {
  const UserProfile({
    required this.sex,
    required this.age,
    required this.bodyWeightKg,
    required this.experience,
    required this.goal,
    required this.availableDays,
    required this.maxSessionDuration,
    required this.createdAt,
  });

  final Sex sex;
  final int age;
  final double bodyWeightKg;
  final ExperienceLevel experience;
  final HypertrophyGoal goal;
  final List<int> availableDays;
  final Duration maxSessionDuration;
  final DateTime createdAt;

  UserProfile copyWith({
    Sex? sex,
    int? age,
    double? bodyWeightKg,
    ExperienceLevel? experience,
    HypertrophyGoal? goal,
    List<int>? availableDays,
    Duration? maxSessionDuration,
  }) => UserProfile(
    sex: sex ?? this.sex,
    age: age ?? this.age,
    bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
    experience: experience ?? this.experience,
    goal: goal ?? this.goal,
    availableDays: availableDays ?? this.availableDays,
    maxSessionDuration: maxSessionDuration ?? this.maxSessionDuration,
    createdAt: createdAt,
  );

  Map<String, dynamic> toJson() => {
    'sex': sex.name,
    'age': age,
    'bodyWeightKg': bodyWeightKg,
    'experience': experience.name,
    'goal': goal.name,
    'availableDays': availableDays,
    'maxSessionDurationMinutes': maxSessionDuration.inMinutes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    sex: Sex.values.byName(json['sex'] as String),
    age: json['age'] as int,
    bodyWeightKg: (json['bodyWeightKg'] as num).toDouble(),
    experience: ExperienceLevel.values.byName(json['experience'] as String),
    goal: HypertrophyGoal.values.byName(json['goal'] as String),
    availableDays: (json['availableDays'] as List).cast<int>(),
    maxSessionDuration: Duration(minutes: json['maxSessionDurationMinutes'] as int),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
```

**Step 6: Update models barrel**

`packages/training_engine/lib/src/models/models.dart`:
```dart
export 'enums.dart';
export 'muscle_activation.dart';
export 'user_profile.dart';
```

**Step 7: Run tests**

```bash
cd packages/training_engine && dart test test/models/enums_test.dart
```

Expected: All tests pass.

**Step 8: Commit**

```bash
git add packages/training_engine/
git commit -m "feat(training-engine): add core enums, MuscleActivation, UserProfile"
```

---

## Task 3: Session and Set Models

**Files:**
- Create: `packages/training_engine/lib/src/models/logged_set.dart`
- Create: `packages/training_engine/lib/src/models/engine_session.dart`
- Create: `packages/training_engine/lib/src/models/engine_exercise.dart`
- Create: `packages/training_engine/test/models/session_models_test.dart`
- Modify: `packages/training_engine/lib/src/models/models.dart`

**Step 1: Write tests**

`packages/training_engine/test/models/session_models_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('LoggedSet', () {
    test('creates with required fields', () {
      final set = LoggedSet(
        exerciseId: 'bench_press',
        weightKg: 100,
        reps: 8,
        rpe: 8.0,
        completedAt: DateTime(2026, 4, 1, 10, 30),
      );
      expect(set.rpeEstimated, isFalse);
    });

    test('serializes to/from JSON roundtrip', () {
      final original = LoggedSet(
        exerciseId: 'squat',
        weightKg: 120,
        reps: 5,
        rpe: 9.0,
        completedAt: DateTime(2026, 4, 1, 10, 0),
        rpeEstimated: true,
      );
      final json = original.toJson();
      final restored = LoggedSet.fromJson(json);
      expect(restored.exerciseId, equals(original.exerciseId));
      expect(restored.weightKg, equals(original.weightKg));
      expect(restored.rpe, equals(original.rpe));
      expect(restored.rpeEstimated, isTrue);
    });

    test('rpe must be between 5 and 10', () {
      expect(
        () => LoggedSet(exerciseId: 'x', weightKg: 50, reps: 10, rpe: 4.0, completedAt: DateTime.now()),
        throwsA(isA<ArgumentError>()),
      );
    });
  });

  group('EngineSession', () {
    test('creates with sets and timestamps', () {
      final session = EngineSession(
        id: 'session_1',
        startedAt: DateTime(2026, 4, 1, 9, 0),
        endedAt: DateTime(2026, 4, 1, 10, 15),
        sets: [],
      );
      expect(session.sessionRpe, isNull);
    });
  });

  group('EngineExercise', () {
    test('creates with muscle map', () {
      final ex = EngineExercise(
        id: 'bench_press',
        name: 'Bench Press',
        muscleMap: [
          MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
          MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.5),
          MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
        ],
        equipment: EquipmentClass.barbell,
        movement: MovementClass.compoundUpper,
      );
      expect(ex.muscleMap.length, equals(3));
    });
  });
}
```

**Step 2: Run test to verify failure**

```bash
cd packages/training_engine && dart test test/models/session_models_test.dart
```

**Step 3: Implement LoggedSet**

`packages/training_engine/lib/src/models/logged_set.dart`:
```dart
class LoggedSet {
  LoggedSet({
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    required this.rpe,
    required this.completedAt,
    this.rpeEstimated = false,
  }) {
    if (rpe < 5 || rpe > 10) {
      throw ArgumentError('rpe must be between 5 and 10, got $rpe');
    }
  }

  final String exerciseId;
  final double weightKg;
  final int reps;
  final double rpe;
  final DateTime completedAt;
  final bool rpeEstimated;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'weightKg': weightKg,
    'reps': reps,
    'rpe': rpe,
    'completedAt': completedAt.toIso8601String(),
    'rpeEstimated': rpeEstimated,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) => LoggedSet(
    exerciseId: json['exerciseId'] as String,
    weightKg: (json['weightKg'] as num).toDouble(),
    reps: json['reps'] as int,
    rpe: (json['rpe'] as num).toDouble(),
    completedAt: DateTime.parse(json['completedAt'] as String),
    rpeEstimated: json['rpeEstimated'] as bool? ?? false,
  );
}
```

**Step 4: Implement EngineSession**

`packages/training_engine/lib/src/models/engine_session.dart`:
```dart
import 'logged_set.dart';

class EngineSession {
  const EngineSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
    this.sessionRpe,
  });

  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<LoggedSet> sets;
  final double? sessionRpe;

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'sets': sets.map((s) => s.toJson()).toList(),
    if (sessionRpe != null) 'sessionRpe': sessionRpe,
  };

  factory EngineSession.fromJson(Map<String, dynamic> json) => EngineSession(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
    sets: (json['sets'] as List).map((s) => LoggedSet.fromJson(s as Map<String, dynamic>)).toList(),
    sessionRpe: (json['sessionRpe'] as num?)?.toDouble(),
  );
}
```

**Step 5: Implement EngineExercise**

`packages/training_engine/lib/src/models/engine_exercise.dart`:
```dart
import 'enums.dart';
import 'muscle_activation.dart';

class EngineExercise {
  const EngineExercise({
    required this.id,
    required this.name,
    required this.muscleMap,
    required this.equipment,
    required this.movement,
  });

  final String id;
  final String name;
  final List<MuscleActivation> muscleMap;
  final EquipmentClass equipment;
  final MovementClass movement;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'muscleMap': muscleMap.map((m) => m.toJson()).toList(),
    'equipment': equipment.name,
    'movement': movement.name,
  };

  factory EngineExercise.fromJson(Map<String, dynamic> json) => EngineExercise(
    id: json['id'] as String,
    name: json['name'] as String,
    muscleMap: (json['muscleMap'] as List)
        .map((m) => MuscleActivation.fromJson(m as Map<String, dynamic>))
        .toList(),
    equipment: EquipmentClass.values.byName(json['equipment'] as String),
    movement: MovementClass.values.byName(json['movement'] as String),
  );
}
```

**Step 6: Update models barrel** — add exports for all three new files.

**Step 7: Run tests**

```bash
cd packages/training_engine && dart test test/models/session_models_test.dart
```

Expected: All tests pass.

**Step 8: Commit**

```bash
git add packages/training_engine/
git commit -m "feat(training-engine): add LoggedSet, EngineSession, EngineExercise models"
```

---

## Task 4: Health Data Models

**Files:**
- Create: `packages/training_engine/lib/src/models/sleep_record.dart`
- Create: `packages/training_engine/lib/src/models/hrv_record.dart`
- Create: `packages/training_engine/test/models/health_models_test.dart`
- Modify: `packages/training_engine/lib/src/models/models.dart`

**Step 1: Write tests**

`packages/training_engine/test/models/health_models_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('SleepRecord', () {
    test('serializes roundtrip', () {
      final record = SleepRecord(
        date: DateTime(2026, 4, 1),
        totalSleep: Duration(hours: 7, minutes: 30),
        deepSleep: Duration(hours: 1, minutes: 15),
        remSleep: Duration(hours: 1, minutes: 45),
        coreSleep: Duration(hours: 4, minutes: 30),
      );
      final json = record.toJson();
      final restored = SleepRecord.fromJson(json);
      expect(restored.totalSleep.inMinutes, equals(450));
      expect(restored.deepSleep.inMinutes, equals(75));
    });
  });

  group('HrvRecord', () {
    test('serializes roundtrip with optional RHR', () {
      final record = HrvRecord(
        date: DateTime(2026, 4, 1),
        sdnn: 45.5,
        restingHeartRate: 62.0,
      );
      final json = record.toJson();
      final restored = HrvRecord.fromJson(json);
      expect(restored.sdnn, equals(45.5));
      expect(restored.restingHeartRate, equals(62.0));
    });

    test('RHR is optional', () {
      final record = HrvRecord(date: DateTime(2026, 4, 1), sdnn: 50.0);
      expect(record.restingHeartRate, isNull);
    });
  });
}
```

**Step 2: Implement SleepRecord and HrvRecord** — simple data classes with JSON roundtrip, durations stored as minutes.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): add SleepRecord, HrvRecord models"
```

---

## Task 5: State Models (E1rmEstimate, FatigueImpulse, DailyLoad, EwmaState)

**Files:**
- Create: `packages/training_engine/lib/src/models/e1rm_estimate.dart`
- Create: `packages/training_engine/lib/src/models/fatigue_impulse.dart`
- Create: `packages/training_engine/lib/src/models/daily_load.dart`
- Create: `packages/training_engine/lib/src/models/ewma_state.dart`
- Create: `packages/training_engine/test/models/state_models_test.dart`
- Modify: `packages/training_engine/lib/src/models/models.dart`

**Step 1: Write tests** covering construction and JSON roundtrip for each.

Key fields:
```dart
class E1rmEstimate {
  final String exerciseId;
  final double value;         // kg
  final double rMax;
  final double confidence;    // 0-1
  final DateTime estimatedAt;
  final bool fromEstimatedRpe;
}

class FatigueImpulse {
  final String muscleId;
  final double magnitude;     // 0-100
  final DateTime timestamp;
}

class DailyLoad {
  final DateTime date;
  final double volumeLoad;
  final double? sRpeLoad;
}

class EwmaState {
  final double acuteEwma;
  final double chronicEwma;
  final DateTime lastComputedDate;
}
```

**Step 2: Implement all four, run tests, commit**

```bash
git commit -m "feat(training-engine): add E1rmEstimate, FatigueImpulse, DailyLoad, EwmaState"
```

---

## Task 6: e1RM Formulas

**Files:**
- Create: `packages/training_engine/lib/src/e1rm/formulas.dart`
- Create: `packages/training_engine/test/e1rm/formulas_test.dart`

**Step 1: Write tests**

`packages/training_engine/test/e1rm/formulas_test.dart`:
```dart
import 'package:test/test.dart';
import 'package:training_engine/src/e1rm/formulas.dart';

void main() {
  group('rirFromRpe', () {
    test('RPE 10 -> RIR 0', () => expect(rirFromRpe(10.0), equals(0.0)));
    test('RPE 9 -> RIR 1', () => expect(rirFromRpe(9.0), equals(1.0)));
    test('RPE 8 -> RIR 2', () => expect(rirFromRpe(8.0), equals(2.0)));
    test('RPE 9.5 -> RIR 0.5', () => expect(rirFromRpe(9.5), equals(0.5)));
  });

  group('rMax', () {
    test('8 reps @ RPE 8 -> rMax 10', () => expect(rMax(8, 8.0), equals(10.0)));
    test('8 reps @ RPE 10 -> rMax 8', () => expect(rMax(8, 10.0), equals(8.0)));
    test('5 reps @ RPE 9 -> rMax 6', () => expect(rMax(5, 9.0), equals(6.0)));
  });

  group('epley', () {
    test('100kg x rMax 8 -> 126.67', () {
      expect(epley(100, 8), closeTo(126.67, 0.01));
    });
    test('100kg x rMax 10 -> 133.33', () {
      expect(epley(100, 10), closeTo(133.33, 0.01));
    });
  });

  group('brzycki', () {
    test('100kg x rMax 8 -> 124.14', () {
      expect(brzycki(100, 8), closeTo(124.14, 0.01));
    });
    test('returns null for rMax > 30', () {
      expect(brzycki(100, 31), isNull);
    });
  });

  group('lander', () {
    test('100kg x rMax 8 -> 125.47', () {
      expect(lander(100, 8), closeTo(125.47, 0.5));
    });
  });

  group('lombardi', () {
    test('100kg x rMax 8 -> 120.93', () {
      expect(lombardi(100, 8), closeTo(120.93, 0.1));
    });
  });

  // Paper Table 3 verification: 100kg x 8 reps across RPE levels
  group('RIR-adjusted e1RM (paper Table 3)', () {
    test('100kg x 8 @ RPE 10 (rMax=8): Epley ~126.6', () {
      expect(epley(100, rMax(8, 10.0)), closeTo(126.6, 0.5));
    });
    test('100kg x 8 @ RPE 9 (rMax=9): Epley ~130.0', () {
      expect(epley(100, rMax(8, 9.0)), closeTo(130.0, 0.5));
    });
    test('100kg x 8 @ RPE 8 (rMax=10): Epley ~133.3', () {
      expect(epley(100, rMax(8, 8.0)), closeTo(133.3, 0.5));
    });
    test('100kg x 8 @ RPE 7 (rMax=11): Epley ~136.6', () {
      expect(epley(100, rMax(8, 7.0)), closeTo(136.6, 0.5));
    });
  });
}
```

**Step 2: Run test to verify failure**

```bash
cd packages/training_engine && dart test test/e1rm/formulas_test.dart
```

**Step 3: Implement formulas**

`packages/training_engine/lib/src/e1rm/formulas.dart`:
```dart
import 'dart:math';

double rirFromRpe(double rpe) => 10.0 - rpe;

double rMax(int reps, double rpe) => reps + rirFromRpe(rpe);

double epley(double weight, double rMax) => weight * (1 + rMax / 30);

double? brzycki(double weight, double rMax) {
  if (rMax > 30) return null;
  return weight * (36 / (37 - rMax));
}

double lander(double weight, double rMax) =>
    (100 * weight) / (101.3 - 2.67123 * rMax);

double lombardi(double weight, double rMax) =>
    weight * pow(rMax, 0.10);
```

**Step 4: Run tests**

```bash
cd packages/training_engine && dart test test/e1rm/formulas_test.dart
```

Expected: All tests pass.

**Step 5: Commit**

```bash
git add packages/training_engine/lib/src/e1rm/ packages/training_engine/test/e1rm/
git commit -m "feat(training-engine): implement e1RM formulas (Epley, Brzycki, Lander, Lombardi)"
```

---

## Task 7: e1RM Composite Estimator

**Files:**
- Create: `packages/training_engine/lib/src/e1rm/composite_estimator.dart`
- Create: `packages/training_engine/test/e1rm/composite_estimator_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/e1rm/composite_estimator.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('compositeE1rm', () {
    test('100kg x 8 @ RPE 8 produces composite in expected range', () {
      final result = compositeE1rm(weight: 100, reps: 8, rpe: 8.0);
      // All formulas give ~125-133 for rMax=10
      expect(result, greaterThan(125));
      expect(result, lessThan(135));
    });

    test('single rep max returns weight directly', () {
      final result = compositeE1rm(weight: 150, reps: 1, rpe: 10.0);
      expect(result, equals(150.0));
    });

    test('heavy sets (rMax 1-5) weight Brzycki highest', () {
      // Just verify it returns a reasonable value
      final result = compositeE1rm(weight: 140, reps: 3, rpe: 10.0);
      expect(result, greaterThan(140));
      expect(result, lessThan(160));
    });

    test('high rep sets (rMax > 15) still produce estimate', () {
      final result = compositeE1rm(weight: 50, reps: 18, rpe: 8.0);
      // rMax = 20, high rep territory
      expect(result, greaterThan(50));
    });
  });

  group('estimateConfidence', () {
    test('heavy sets get high confidence', () {
      expect(estimateConfidence(5.0), greaterThan(0.8));
    });
    test('moderate sets get moderate confidence', () {
      final c = estimateConfidence(10.0);
      expect(c, greaterThan(0.5));
      expect(c, lessThan(0.9));
    });
    test('high rep sets get low confidence', () {
      expect(estimateConfidence(20.0), lessThan(0.5));
    });
  });

  group('rollingE1rm', () {
    test('weights recent estimates higher', () {
      final now = DateTime(2026, 4, 2);
      final estimates = [
        E1rmEstimate(exerciseId: 'sq', value: 100, rMax: 8, confidence: 0.8,
          estimatedAt: now.subtract(Duration(days: 30)), fromEstimatedRpe: false),
        E1rmEstimate(exerciseId: 'sq', value: 120, rMax: 6, confidence: 0.9,
          estimatedAt: now.subtract(Duration(days: 2)), fromEstimatedRpe: false),
      ];
      final result = rollingE1rm(estimates, now);
      // Should be closer to 120 than 100
      expect(result, greaterThan(115));
    });

    test('legacy estimates weighted at 50%', () {
      final now = DateTime(2026, 4, 2);
      final estimates = [
        E1rmEstimate(exerciseId: 'sq', value: 100, rMax: 8, confidence: 0.8,
          estimatedAt: now.subtract(Duration(days: 1)), fromEstimatedRpe: true),
        E1rmEstimate(exerciseId: 'sq', value: 120, rMax: 6, confidence: 0.9,
          estimatedAt: now.subtract(Duration(days: 1)), fromEstimatedRpe: false),
      ];
      final result = rollingE1rm(estimates, now);
      // Legacy (100) weighted less, so result closer to 120
      expect(result, greaterThan(112));
    });

    test('returns null for empty list', () {
      expect(rollingE1rm([], DateTime.now()), isNull);
    });
  });
}
```

**Step 2: Implement**

`packages/training_engine/lib/src/e1rm/composite_estimator.dart`:
```dart
import 'dart:math';
import 'formulas.dart' as f;
import '../models/models.dart';

/// Rep-range-dependent formula weights: [epley, brzycki, lander, lombardi]
List<double> _formulaWeights(double rMax) {
  if (rMax <= 5) return [0.20, 0.35, 0.30, 0.15];
  if (rMax <= 10) return [0.30, 0.25, 0.25, 0.20];
  if (rMax <= 15) return [0.35, 0.10, 0.30, 0.25];
  return [0.30, 0.05, 0.30, 0.35];
}

double compositeE1rm({
  required double weight,
  required int reps,
  required double rpe,
}) {
  final rm = f.rMax(reps, rpe);

  // Single rep max
  if (rm <= 1) return weight;

  final weights = _formulaWeights(rm);
  final estimates = <double>[];
  final activeWeights = <double>[];

  estimates.add(f.epley(weight, rm));
  activeWeights.add(weights[0]);

  final brz = f.brzycki(weight, rm);
  if (brz != null) {
    estimates.add(brz);
    activeWeights.add(weights[1]);
  }

  estimates.add(f.lander(weight, rm));
  activeWeights.add(weights[2]);

  estimates.add(f.lombardi(weight, rm));
  activeWeights.add(weights[3]);

  // Normalize weights
  final totalWeight = activeWeights.fold(0.0, (a, b) => a + b);
  double result = 0;
  for (int i = 0; i < estimates.length; i++) {
    result += estimates[i] * (activeWeights[i] / totalWeight);
  }
  return result;
}

double estimateConfidence(double rMax) {
  if (rMax <= 5) return 0.95;
  if (rMax <= 10) return 0.80;
  if (rMax <= 15) return 0.60;
  if (rMax <= 20) return 0.40;
  return 0.25;
}

double? rollingE1rm(List<E1rmEstimate> estimates, DateTime now) {
  if (estimates.isEmpty) return null;

  const halfLifeDays = 14.0;
  final lambda = log(2) / (halfLifeDays * 24 * 60);

  double weightedSum = 0;
  double totalWeight = 0;

  for (final est in estimates) {
    final minutesAgo = now.difference(est.estimatedAt).inMinutes.toDouble();
    final recency = exp(-lambda * minutesAgo);
    final legacyPenalty = est.fromEstimatedRpe ? 0.5 : 1.0;
    final w = recency * est.confidence * legacyPenalty;

    weightedSum += est.value * w;
    totalWeight += w;
  }

  return totalWeight > 0 ? weightedSum / totalWeight : null;
}
```

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement composite e1RM estimator with rolling average"
```

---

## Task 8: Muscle Registry

**Files:**
- Create: `packages/training_engine/lib/src/fatigue/muscle_registry.dart`
- Create: `packages/training_engine/test/fatigue/muscle_registry_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/fatigue/muscle_registry.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('MuscleDefinition', () {
    test('quadriceps is large with tau ~24.02', () {
      final quad = defaultMuscles['quadriceps']!;
      expect(quad.size, equals(MuscleSize.large));
      expect(quad.decayConstant, closeTo(24.02, 0.01));
    });

    test('biceps is small with tau ~12.01', () {
      final bicep = defaultMuscles['biceps']!;
      expect(bicep.size, equals(MuscleSize.small));
      expect(bicep.decayConstant, closeTo(12.01, 0.01));
    });

    test('triceps is moderate with tau ~16.01', () {
      final tri = defaultMuscles['triceps']!;
      expect(tri.size, equals(MuscleSize.moderate));
      expect(tri.decayConstant, closeTo(16.01, 0.01));
    });

    test('registry contains at least 25 muscles', () {
      expect(defaultMuscles.length, greaterThanOrEqualTo(25));
    });
  });

  group('decayConstantForSize', () {
    test('small -> 12.01', () => expect(decayConstantForSize(MuscleSize.small), closeTo(12.01, 0.01)));
    test('moderate -> 16.01', () => expect(decayConstantForSize(MuscleSize.moderate), closeTo(16.01, 0.01)));
    test('large -> 24.02', () => expect(decayConstantForSize(MuscleSize.large), closeTo(24.02, 0.01)));
  });
}
```

**Step 2: Implement**

`packages/training_engine/lib/src/fatigue/muscle_registry.dart`:

Contains `MuscleDefinition` class, `decayConstantForSize()` function (using `tau = -T / ln(0.05)`), and `defaultMuscles` map with ~28 muscles covering: quadriceps, hamstrings, glutes, calves, pectorals, lats, upper_back, trapezius, rear_deltoid, lateral_deltoid, anterior_deltoid, biceps, triceps, forearms, abs, obliques, erector_spinae, hip_flexors, adductors, abductors, neck, rotator_cuff, serratus_anterior, rhomboids, lower_back, brachialis, brachioradialis, tibialis_anterior.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): add muscle registry with decay constants"
```

---

## Task 9: Fatigue Impulse Calculator

**Files:**
- Create: `packages/training_engine/lib/src/fatigue/impulse_calculator.dart`
- Create: `packages/training_engine/test/fatigue/impulse_calculator_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/fatigue/impulse_calculator.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  final benchPress = EngineExercise(
    id: 'bench_press',
    name: 'Bench Press',
    muscleMap: [
      MuscleActivation(muscleId: 'pectorals', role: MuscleRole.primary, coefficient: 1.0),
      MuscleActivation(muscleId: 'anterior_deltoid', role: MuscleRole.synergist, coefficient: 0.5),
      MuscleActivation(muscleId: 'triceps', role: MuscleRole.synergist, coefficient: 0.4),
    ],
    equipment: EquipmentClass.barbell,
    movement: MovementClass.compoundUpper,
  );

  group('calculateImpulses', () {
    test('distributes stress across muscles by coefficient', () {
      final sets = [
        LoggedSet(exerciseId: 'bench_press', weightKg: 100, reps: 10, rpe: 8.0,
          completedAt: DateTime(2026, 4, 1, 10, 0)),
      ];
      final impulses = calculateImpulses(
        sets: sets,
        exercise: benchPress,
        e1rm: 130.0,
        sessionEndedAt: DateTime(2026, 4, 1, 10, 30),
      );

      expect(impulses.length, equals(3));

      final pecs = impulses.firstWhere((i) => i.muscleId == 'pectorals');
      final delts = impulses.firstWhere((i) => i.muscleId == 'anterior_deltoid');
      final tris = impulses.firstWhere((i) => i.muscleId == 'triceps');

      // Primary should have highest magnitude
      expect(pecs.magnitude, greaterThan(delts.magnitude));
      expect(delts.magnitude, greaterThan(tris.magnitude));

      // All capped at 100
      expect(pecs.magnitude, lessThanOrEqualTo(100));
    });

    test('RPE scales stress proportionally', () {
      final setsHigh = [
        LoggedSet(exerciseId: 'bench_press', weightKg: 100, reps: 10, rpe: 10.0,
          completedAt: DateTime(2026, 4, 1, 10, 0)),
      ];
      final setsLow = [
        LoggedSet(exerciseId: 'bench_press', weightKg: 100, reps: 10, rpe: 7.0,
          completedAt: DateTime(2026, 4, 1, 10, 0)),
      ];
      final impulsesHigh = calculateImpulses(
        sets: setsHigh, exercise: benchPress, e1rm: 130.0,
        sessionEndedAt: DateTime(2026, 4, 1, 10, 30));
      final impulsesLow = calculateImpulses(
        sets: setsLow, exercise: benchPress, e1rm: 130.0,
        sessionEndedAt: DateTime(2026, 4, 1, 10, 30));

      final pecsHigh = impulsesHigh.firstWhere((i) => i.muscleId == 'pectorals');
      final pecsLow = impulsesLow.firstWhere((i) => i.muscleId == 'pectorals');
      expect(pecsHigh.magnitude, greaterThan(pecsLow.magnitude));
    });

    test('typical hypertrophy session produces F0 ~75-85 for primary', () {
      // 4 sets x 10 reps @ 75% e1RM, RPE 8
      final sets = List.generate(4, (i) => LoggedSet(
        exerciseId: 'bench_press', weightKg: 97.5, reps: 10, rpe: 8.0,
        completedAt: DateTime(2026, 4, 1, 10, i * 4),
      ));
      final impulses = calculateImpulses(
        sets: sets, exercise: benchPress, e1rm: 130.0,
        sessionEndedAt: DateTime(2026, 4, 1, 10, 30));

      final pecs = impulses.firstWhere((i) => i.muscleId == 'pectorals');
      expect(pecs.magnitude, greaterThan(65));
      expect(pecs.magnitude, lessThanOrEqualTo(100));
    });
  });
}
```

**Step 2: Implement** — compute `setStress = weightKg * reps * (rpe / 10)`, accumulate per muscle scaled by coefficient, normalize against `e1rm * normalizationFactor`, clamp to 0-100.

The `normalizationFactor` is a constant calibrated so 4x10 @ RPE 8 at ~75% e1RM yields F0 ~80. This works out to approximately `normalizationFactor = 40.0` (i.e., the stress from 40 reps at e1RM would be "100% fatigue").

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement fatigue impulse calculator"
```

---

## Task 10: Fatigue Exponential Decay

**Files:**
- Create: `packages/training_engine/lib/src/fatigue/decay.dart`
- Create: `packages/training_engine/test/fatigue/decay_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/fatigue/decay.dart';
import 'package:training_engine/src/fatigue/muscle_registry.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('decayedFatigue', () {
    test('returns full magnitude at t=0', () {
      expect(decayedFatigue(magnitude: 100, hoursElapsed: 0, tau: 24.02), equals(100.0));
    });

    test('large muscle at 72h decays to ~5%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 72, tau: 24.02);
      expect(result, closeTo(5.0, 0.5));
    });

    test('small muscle at 36h decays to ~5%', () {
      final result = decayedFatigue(magnitude: 100, hoursElapsed: 36, tau: 12.01);
      expect(result, closeTo(5.0, 0.5));
    });

    // Paper Table 2 verification for large muscle
    test('large muscle at 12h -> ~60.7%', () {
      expect(decayedFatigue(magnitude: 100, hoursElapsed: 12, tau: 24.02), closeTo(60.7, 1.0));
    });
    test('large muscle at 24h -> ~36.8%', () {
      expect(decayedFatigue(magnitude: 100, hoursElapsed: 24, tau: 24.02), closeTo(36.8, 1.0));
    });
    test('large muscle at 48h -> ~13.5%', () {
      expect(decayedFatigue(magnitude: 100, hoursElapsed: 48, tau: 24.02), closeTo(13.5, 1.0));
    });
  });

  group('currentFatigue (superposition)', () {
    test('single impulse decays normally', () {
      final now = DateTime(2026, 4, 2, 10, 0);
      final impulses = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 80,
          timestamp: now.subtract(Duration(hours: 24))),
      ];
      final result = currentFatigue('quadriceps', impulses, now);
      // 80 * exp(-24/24.02) ~ 80 * 0.368 ~ 29.4
      expect(result, closeTo(29.4, 1.0));
    });

    test('two impulses superimpose and cap at 100', () {
      final now = DateTime(2026, 4, 2, 10, 0);
      final impulses = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 80,
          timestamp: now.subtract(Duration(hours: 6))),
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 80,
          timestamp: now.subtract(Duration(hours: 2))),
      ];
      final result = currentFatigue('quadriceps', impulses, now);
      expect(result, lessThanOrEqualTo(100));
      // Both still very fresh, so combined > either alone
      expect(result, greaterThan(80));
    });

    test('ignores impulses for other muscles', () {
      final now = DateTime(2026, 4, 2, 10, 0);
      final impulses = [
        FatigueImpulse(muscleId: 'quadriceps', magnitude: 80, timestamp: now),
        FatigueImpulse(muscleId: 'biceps', magnitude: 60, timestamp: now),
      ];
      final result = currentFatigue('biceps', impulses, now);
      expect(result, closeTo(60, 0.1));
    });
  });

  group('ageRecoveryModifier', () {
    test('age 25 -> 1.0', () => expect(ageRecoveryModifier(25), equals(1.0)));
    test('age 35 -> 1.10', () => expect(ageRecoveryModifier(35), equals(1.10)));
    test('age 45 -> 1.25', () => expect(ageRecoveryModifier(45), equals(1.25)));
    test('age 55 -> 1.40', () => expect(ageRecoveryModifier(55), equals(1.40)));
  });

  group('fullFatigueMap', () {
    test('returns FatigueStatus for each muscle with impulses', () {
      final now = DateTime(2026, 4, 2, 10, 0);
      final impulses = {
        'quadriceps': [FatigueImpulse(muscleId: 'quadriceps', magnitude: 80, timestamp: now)],
        'biceps': [FatigueImpulse(muscleId: 'biceps', magnitude: 40,
          timestamp: now.subtract(Duration(hours: 24)))],
      };
      final map = fullFatigueMap(impulses, now);
      expect(map['quadriceps']!.phase, equals(RecoveryPhase.acute));
      expect(map['biceps']!.phase, equals(RecoveryPhase.recovering));
    });
  });

  group('pruneOldImpulses', () {
    test('removes impulses older than 7 days', () {
      final now = DateTime(2026, 4, 2);
      final impulses = [
        FatigueImpulse(muscleId: 'quads', magnitude: 80,
          timestamp: now.subtract(Duration(days: 8))),
        FatigueImpulse(muscleId: 'quads', magnitude: 60,
          timestamp: now.subtract(Duration(days: 1))),
      ];
      final pruned = pruneOldImpulses(impulses, now);
      expect(pruned.length, equals(1));
      expect(pruned.first.magnitude, equals(60));
    });
  });
}
```

**Step 2: Implement**

`packages/training_engine/lib/src/fatigue/decay.dart`:
- `decayedFatigue(magnitude, hoursElapsed, tau)` — `magnitude * exp(-hoursElapsed / tau)`
- `currentFatigue(muscleId, impulses, now, {int? age})` — sums decayed impulses, clamps to 100
- `ageRecoveryModifier(age)` — returns multiplier
- `fullFatigueMap(impulseLog, now, {int? age})` — returns `Map<String, FatigueStatus>`
- `pruneOldImpulses(impulses, now)` — filters out > 7 days
- `FatigueStatus` class with `level`, `hue`, `estimatedFullRecovery`, `phase`

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement fatigue exponential decay with superposition"
```

---

## Task 11: ACWR (EWMA + Zone Classification)

**Files:**
- Create: `packages/training_engine/lib/src/acwr/ewma.dart`
- Create: `packages/training_engine/lib/src/acwr/acwr_classifier.dart`
- Create: `packages/training_engine/test/acwr/acwr_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/acwr/ewma.dart';
import 'package:training_engine/src/acwr/acwr_classifier.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('updateEwma', () {
    test('first day initializes both acute and chronic', () {
      final state = updateEwma(
        previous: null,
        todayLoad: 5000,
        today: DateTime(2026, 4, 1),
      );
      expect(state.acuteEwma, equals(5000.0));
      expect(state.chronicEwma, equals(5000.0));
    });

    test('rest day decays acute faster than chronic', () {
      final initial = EwmaState(acuteEwma: 5000, chronicEwma: 5000,
        lastComputedDate: DateTime(2026, 4, 1));
      final state = updateEwma(previous: initial, todayLoad: 0,
        today: DateTime(2026, 4, 2));
      expect(state.acuteEwma, lessThan(state.chronicEwma));
    });

    test('catches up skipped rest days', () {
      final initial = EwmaState(acuteEwma: 5000, chronicEwma: 5000,
        lastComputedDate: DateTime(2026, 3, 28));
      // 4 rest days + today with load
      final state = updateEwma(previous: initial, todayLoad: 5000,
        today: DateTime(2026, 4, 2));
      // Acute should have decayed from rest days then bounced back
      expect(state.acuteEwma, lessThan(5000));
      expect(state.lastComputedDate, equals(DateTime(2026, 4, 2)));
    });
  });

  group('classifyAcwr', () {
    test('ratio 1.0 is optimal', () {
      expect(classifyAcwr(1.0).zone, equals(AcwrZone.optimal));
    });
    test('ratio 0.5 is undertraining', () {
      expect(classifyAcwr(0.5).zone, equals(AcwrZone.undertraining));
    });
    test('ratio 1.4 is caution', () {
      expect(classifyAcwr(1.4).zone, equals(AcwrZone.caution));
    });
    test('ratio 1.7 is danger', () {
      expect(classifyAcwr(1.7).zone, equals(AcwrZone.danger));
    });
    test('null returned when chronic is near zero', () {
      final result = computeAcwr(EwmaState(
        acuteEwma: 100, chronicEwma: 0.001,
        lastComputedDate: DateTime(2026, 4, 1)));
      expect(result, isNull);
    });
  });

  group('acwrConfidence', () {
    test('< 7 days returns null', () {
      expect(acwrConfidence(5), isNull);
    });
    test('7-21 days returns low', () {
      expect(acwrConfidence(14), equals(AcwrConfidenceLevel.low));
    });
    test('> 21 days returns full', () {
      expect(acwrConfidence(25), equals(AcwrConfidenceLevel.full));
    });
  });
}
```

**Step 2: Implement**

`ewma.dart`: `updateEwma()` with lambda_acute = 2/8, lambda_chronic = 2/29, rest day catch-up loop.

`acwr_classifier.dart`: `computeAcwr()`, `classifyAcwr()`, `acwrConfidence()`, `AcwrStatus` class.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement ACWR with EWMA and zone classification"
```

---

## Task 12: Readiness Scoring

**Files:**
- Create: `packages/training_engine/lib/src/readiness/sleep_scorer.dart`
- Create: `packages/training_engine/lib/src/readiness/hrv_scorer.dart`
- Create: `packages/training_engine/lib/src/readiness/composite_readiness.dart`
- Create: `packages/training_engine/test/readiness/readiness_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/readiness/sleep_scorer.dart';
import 'package:training_engine/src/readiness/hrv_scorer.dart';
import 'package:training_engine/src/readiness/composite_readiness.dart';
import 'package:training_engine/src/acwr/acwr_classifier.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('sleepScore', () {
    test('7.5h with good stages scores high', () {
      final records = [
        SleepRecord(date: DateTime(2026, 4, 1),
          totalSleep: Duration(hours: 7, minutes: 30),
          deepSleep: Duration(hours: 1, minutes: 15),
          remSleep: Duration(hours: 1, minutes: 45),
          coreSleep: Duration(hours: 4, minutes: 30)),
      ];
      expect(scoreSleep(records, DateTime(2026, 4, 2)), greaterThan(75));
    });

    test('4h last night triggers acute penalty', () {
      final records = [
        SleepRecord(date: DateTime(2026, 4, 1),
          totalSleep: Duration(hours: 4),
          deepSleep: Duration(hours: 0, minutes: 30),
          remSleep: Duration(hours: 0, minutes: 45),
          coreSleep: Duration(hours: 2, minutes: 45)),
      ];
      expect(scoreSleep(records, DateTime(2026, 4, 2)), lessThan(50));
    });

    test('returns null for empty records', () {
      expect(scoreSleep([], DateTime.now()), isNull);
    });
  });

  group('hrvScore', () {
    test('SDNN at baseline scores well', () {
      final records = List.generate(14, (i) =>
        HrvRecord(date: DateTime(2026, 3, 19 + i), sdnn: 45.0 + (i % 3)));
      expect(scoreHrv(records, DateTime(2026, 4, 2)), greaterThan(70));
    });

    test('returns null for insufficient data', () {
      expect(scoreHrv([], DateTime.now()), isNull);
    });
  });

  group('compositeReadiness', () {
    test('full tier with all data sources', () {
      final score = computeReadiness(
        acwr: AcwrStatus(ratio: 1.0, zone: AcwrZone.optimal,
          acuteEwma: 5000, chronicEwma: 5000, recommendation: ''),
        sleepScore: 80,
        hrvScore: 75,
        manualSlider: null,
      );
      expect(score.tier, equals(ReadinessTier.full));
      expect(score.confidence, equals(ReadinessConfidence.high));
      expect(score.score, greaterThan(70));
    });

    test('ACWR-only tier when no health data', () {
      final score = computeReadiness(
        acwr: AcwrStatus(ratio: 1.1, zone: AcwrZone.optimal,
          acuteEwma: 5500, chronicEwma: 5000, recommendation: ''),
        sleepScore: null,
        hrvScore: null,
        manualSlider: null,
      );
      expect(score.tier, equals(ReadinessTier.acwrOnly));
      expect(score.confidence, equals(ReadinessConfidence.low));
    });

    test('manual slider provides fallback when no other data', () {
      final score = computeReadiness(
        acwr: null,
        sleepScore: null,
        hrvScore: null,
        manualSlider: 4.0,
      );
      expect(score.tier, equals(ReadinessTier.manualOnly));
      expect(score.score, greaterThan(60));
    });

    test('danger zone ACWR flags alert', () {
      final score = computeReadiness(
        acwr: AcwrStatus(ratio: 1.7, zone: AcwrZone.danger,
          acuteEwma: 8500, chronicEwma: 5000, recommendation: ''),
        sleepScore: 80,
        hrvScore: 75,
        manualSlider: null,
      );
      expect(score.flags, contains(ReadinessFlag.acwrDangerZone));
    });
  });
}
```

**Step 2: Implement** all three files. `ReadinessTier` enum: full, noHrv, noSleep, acwrOnly, manualOnly, cold. `ReadinessFlag` enum: acuteSleepDeprivation, risingRestingHR, acwrDangerZone, coldStart.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement readiness scoring with tiered fallback"
```

---

## Task 13: Progressive Overload — Safety Gates

**Files:**
- Create: `packages/training_engine/lib/src/progression/safety_gates.dart`
- Create: `packages/training_engine/test/progression/safety_gates_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/progression/safety_gates.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('checkSafetyGates', () {
    test('all clear when fatigue low, ACWR optimal, readiness high', () {
      final result = checkSafetyGates(
        primaryMuscleFatigue: 30,
        acwrZone: AcwrZone.optimal,
        readinessScore: 80,
      );
      expect(result.passed, isTrue);
    });

    test('blocked by high primary muscle fatigue', () {
      final result = checkSafetyGates(
        primaryMuscleFatigue: 75,
        acwrZone: AcwrZone.optimal,
        readinessScore: 80,
      );
      expect(result.passed, isFalse);
      expect(result.reason, equals(GateReason.muscleFatigue));
    });

    test('blocked by ACWR danger zone', () {
      final result = checkSafetyGates(
        primaryMuscleFatigue: 20,
        acwrZone: AcwrZone.danger,
        readinessScore: 80,
      );
      expect(result.passed, isFalse);
      expect(result.action, equals(GateAction.deload));
    });

    test('dampened by low readiness (50-69)', () {
      final result = checkSafetyGates(
        primaryMuscleFatigue: 20,
        acwrZone: AcwrZone.optimal,
        readinessScore: 55,
      );
      expect(result.passed, isTrue);
      expect(result.modifier, closeTo(0.5, 0.01));
    });

    test('blocked by very low readiness (<30)', () {
      final result = checkSafetyGates(
        primaryMuscleFatigue: 20,
        acwrZone: AcwrZone.optimal,
        readinessScore: 20,
      );
      expect(result.passed, isFalse);
      expect(result.action, equals(GateAction.reduceLoad));
    });

    test('null values are permissive (gates skipped)', () {
      final result = checkSafetyGates(
        primaryMuscleFatigue: 30,
        acwrZone: null,
        readinessScore: null,
      );
      expect(result.passed, isTrue);
    });
  });
}
```

**Step 2: Implement** `GateResult`, `GateReason`, `GateAction` types and `checkSafetyGates()`.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement progression safety gates"
```

---

## Task 14: Progressive Overload — Performance Delta + Load Predictor

**Files:**
- Create: `packages/training_engine/lib/src/progression/performance_delta.dart`
- Create: `packages/training_engine/lib/src/progression/load_predictor.dart`
- Create: `packages/training_engine/lib/src/progression/equipment_rounding.dart`
- Create: `packages/training_engine/test/progression/progression_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/progression/performance_delta.dart';
import 'package:training_engine/src/progression/load_predictor.dart';
import 'package:training_engine/src/progression/equipment_rounding.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('evaluateDelta', () {
    test('hit upper bound at low RPE -> progression', () {
      expect(evaluateDelta(reps: 12, rpe: 7.5, targetRepsHigh: 12, targetRpe: 8.0),
        equals(PerformanceDelta.progression));
    });
    test('mid range reps -> maintenance', () {
      expect(evaluateDelta(reps: 10, rpe: 8.0, targetRepsHigh: 12, targetRpe: 8.0),
        equals(PerformanceDelta.maintenance));
    });
    test('below lower bound at max effort -> regression', () {
      expect(evaluateDelta(reps: 5, rpe: 9.5, targetRepsHigh: 12, targetRpe: 8.0, targetRepsLow: 8),
        equals(PerformanceDelta.regression));
    });
  });

  group('predictLoad (inverse Epley)', () {
    test('paper example: e1RM=150, target 8 reps @ RPE 8 -> ~112.5', () {
      // targetRMax = 8 + 2 = 10
      // weight = 150 / (1 + 10/30) = 150 / 1.333 = 112.5
      final weight = predictLoad(e1rm: 150, targetReps: 8, targetRpe: 8.0);
      expect(weight, closeTo(112.5, 0.5));
    });

    test('e1RM=130, target 10 reps @ RPE 8.5 -> ~91.8', () {
      // targetRMax = 10 + 1.5 = 11.5
      // weight = 130 / (1 + 11.5/30) = 130 / 1.383 = ~94
      final weight = predictLoad(e1rm: 130, targetReps: 10, targetRpe: 8.5);
      expect(weight, greaterThan(90));
      expect(weight, lessThan(100));
    });
  });

  group('roundToEquipment', () {
    test('barbell rounds to 2.5kg', () {
      expect(roundToEquipment(112.3, EquipmentClass.barbell), equals(112.5));
      expect(roundToEquipment(113.7, EquipmentClass.barbell), equals(115.0));
    });
    test('dumbbell rounds to 2kg', () {
      expect(roundToEquipment(23.3, EquipmentClass.dumbbell), equals(24.0));
    });
    test('machine rounds to 5kg', () {
      expect(roundToEquipment(47.0, EquipmentClass.machine), equals(45.0));
    });
  });

  group('TargetParams defaults', () {
    test('compound lower defaults', () {
      final t = TargetParams.defaultFor(MovementClass.compoundLower);
      expect(t.targetRepsLow, equals(6));
      expect(t.targetRepsHigh, equals(10));
      expect(t.targetRpe, equals(8.0));
    });
  });
}
```

**Step 2: Implement** `TargetParams`, `evaluateDelta()`, `predictLoad()`, `roundToEquipment()`.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement load predictor with equipment rounding"
```

---

## Task 15: Progression — LoadRecommendation Assembly

**Files:**
- Create: `packages/training_engine/lib/src/progression/recommendation.dart`
- Create: `packages/training_engine/test/progression/recommendation_test.dart`

**Step 1: Write tests** — full pipeline test: given e1RM, fatigue, ACWR, readiness, and last session data, produce a `LoadRecommendation` with correct `suggestedWeightKg`, `delta`, `explanation`.

Test cases:
- Clear gates + progression triggered -> increased weight
- Clear gates + maintenance -> same weight
- Blocked by fatigue -> maintenance with warning
- ACWR danger -> deload recommendation
- Dampened readiness -> half-increment

**Step 2: Implement** `buildRecommendation()` function assembling the full pipeline.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement LoadRecommendation assembly"
```

---

## Task 16: Planner — Split Selector

**Files:**
- Create: `packages/training_engine/lib/src/planner/split_selector.dart`
- Create: `packages/training_engine/test/planner/split_selector_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/planner/split_selector.dart';

void main() {
  group('selectSplit', () {
    test('2 days -> fullBody', () {
      expect(selectSplit([0, 3]), equals(SplitType.fullBody)); // Mon, Thu
    });
    test('3 non-consecutive -> fullBody', () {
      expect(selectSplit([0, 2, 4]), equals(SplitType.fullBody)); // MWF
    });
    test('3 consecutive -> pushPullLegs', () {
      expect(selectSplit([4, 5, 6]), equals(SplitType.pushPullLegs)); // Fri-Sun
    });
    test('4 days -> upperLower', () {
      expect(selectSplit([0, 1, 3, 4]), equals(SplitType.upperLower));
    });
    test('5 days -> pushPullLegs', () {
      expect(selectSplit([0, 1, 2, 3, 4]), equals(SplitType.pushPullLegs));
    });
    test('1 day -> fullBody', () {
      expect(selectSplit([3]), equals(SplitType.fullBody));
    });
  });

  group('hasConsecutiveDays', () {
    test('[0,2,4] has no consecutive', () {
      expect(hasConsecutiveDays([0, 2, 4]), isFalse);
    });
    test('[4,5,6] has consecutive', () {
      expect(hasConsecutiveDays([4, 5, 6]), isTrue);
    });
    test('[0,1,4] has consecutive', () {
      expect(hasConsecutiveDays([0, 1, 4]), isTrue);
    });
  });
}
```

**Step 2: Implement** `SplitType` enum, `selectSplit()`, `hasConsecutiveDays()`.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement split selector"
```

---

## Task 17: Planner — Session Generator + Time Bounder

**Files:**
- Create: `packages/training_engine/lib/src/planner/session_generator.dart`
- Create: `packages/training_engine/lib/src/planner/time_bounder.dart`
- Create: `packages/training_engine/test/planner/session_generator_test.dart`

**Step 1: Write tests**

Test cases for session generation:
- Full body split generates exercises hitting all major muscle groups
- PPL split: push day has chest/shoulders/triceps, pull has back/biceps, legs has quads/hamstrings/glutes
- Upper/lower split distributes correctly
- Respects preferred and excluded exercises
- Generated sessions are within 10-20 weekly working sets per muscle group

Test cases for time bounding:
- Session under time limit passes through unchanged
- Over-time session first reduces isolation rest
- Further over-time pairs supersets
- Still over-time trims accessory volume
- Adjustments are tracked for UI explanation

**Step 2: Implement** `generateWeeklyPlan()`, `boundSessionToTime()`.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement session generator and time bounder"
```

---

## Task 18: Planner — Missed Session + Fatigue Substitution

**Files:**
- Create: `packages/training_engine/lib/src/planner/missed_session.dart`
- Create: `packages/training_engine/lib/src/planner/fatigue_substitution.dart`
- Create: `packages/training_engine/test/planner/dynamic_adjustments_test.dart`

**Step 1: Write tests**

Missed session tests:
- Volume redistributed to remaining sessions (50-75%)
- No redistribution if week is over
- Extra sets target matching muscle focus

Fatigue substitution tests:
- No substitution when muscles recovered
- Secondary muscle fatigued -> substitute to machine variant
- Primary muscle fatigued -> warning flag, no substitution (user decides)
- Substitution preserves primary muscle targeting

**Step 2: Implement**

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement missed session redistribution and fatigue substitution"
```

---

## Task 19: Exercise Registry (Default Exercises)

**Files:**
- Create: `packages/training_engine/lib/src/registry/exercise_registry.dart`
- Create: `packages/training_engine/lib/src/registry/default_exercises.dart`
- Create: `packages/training_engine/test/registry/registry_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/registry/exercise_registry.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  late ExerciseRegistry registry;

  setUp(() {
    registry = ExerciseRegistry.withDefaults();
  });

  group('ExerciseRegistry', () {
    test('contains at least 80 exercises', () {
      expect(registry.all.length, greaterThanOrEqualTo(80));
    });

    test('bench press has correct muscle map', () {
      final bp = registry.lookup('barbell_bench_press')!;
      expect(bp.muscleMap.any((m) => m.muscleId == 'pectorals' && m.role == MuscleRole.primary), isTrue);
      expect(bp.equipment, equals(EquipmentClass.barbell));
      expect(bp.movement, equals(MovementClass.compoundUpper));
    });

    test('barbell squat is compound lower', () {
      final sq = registry.lookup('barbell_back_squat')!;
      expect(sq.movement, equals(MovementClass.compoundLower));
      expect(sq.muscleMap.any((m) => m.muscleId == 'quadriceps' && m.role == MuscleRole.primary), isTrue);
    });

    test('substitutesFor finds alternatives avoiding specified muscles', () {
      final subs = registry.substitutesFor('barbell_deadlift', avoidMuscles: {'erector_spinae'});
      // Should find leg exercises that don't heavily load erector spinae
      expect(subs, isNotEmpty);
      for (final ex in subs) {
        final erspinae = ex.muscleMap.where((m) => m.muscleId == 'erector_spinae');
        // Should either not involve it or have very low coefficient
        for (final m in erspinae) {
          expect(m.coefficient, lessThan(0.3));
        }
      }
    });

    test('custom exercises can be added', () {
      final custom = EngineExercise(
        id: 'my_exercise',
        name: 'My Exercise',
        muscleMap: [MuscleActivation(muscleId: 'biceps', role: MuscleRole.primary, coefficient: 1.0)],
        equipment: EquipmentClass.dumbbell,
        movement: MovementClass.isolation,
      );
      registry.addCustom(custom);
      expect(registry.lookup('my_exercise'), isNotNull);
    });
  });
}
```

**Step 2: Implement** `ExerciseRegistry` class and `default_exercises.dart` with ~80-100 exercises.

The default exercises should cover the major categories:
- **Chest:** barbell/dumbbell bench (flat/incline/decline), cable fly, pec deck
- **Back:** barbell row, dumbbell row, lat pulldown, cable row, pull-up, deadlift
- **Shoulders:** overhead press (barbell/dumbbell), lateral raise, face pull, reverse fly
- **Legs:** squat (barbell/hack/goblet), leg press, leg extension, leg curl, RDL, lunge, calf raise
- **Arms:** barbell/dumbbell curl, hammer curl, tricep pushdown, overhead extension, skull crusher
- **Core:** cable crunch, hanging leg raise, ab wheel, plank

Each with full `MuscleActivation` maps (primary + synergists + stabilizers with coefficients).

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): add exercise registry with ~80 default exercises"
```

---

## Task 20: Strength Baseline (Cold-Start e1RM)

**Files:**
- Create: `packages/training_engine/lib/src/e1rm/strength_baseline.dart`
- Create: `packages/training_engine/test/e1rm/strength_baseline_test.dart`

**Step 1: Write tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/src/e1rm/strength_baseline.dart';
import 'package:training_engine/src/models/models.dart';

void main() {
  group('estimateBaselineE1rm', () {
    test('male beginner 80kg squat -> 60kg (0.75x BW)', () {
      final e1rm = estimateBaselineE1rm(
        category: ExerciseCategory.squat,
        sex: Sex.male,
        experience: ExperienceLevel.beginner,
        bodyWeightKg: 80,
      );
      expect(e1rm, equals(60.0));
    });

    test('female intermediate bench -> bodyweight ratio applied', () {
      final e1rm = estimateBaselineE1rm(
        category: ExerciseCategory.bench,
        sex: Sex.female,
        experience: ExperienceLevel.intermediate,
        bodyWeightKg: 65,
      );
      expect(e1rm, greaterThan(0));
      expect(e1rm, lessThan(65)); // sub-bodyweight for female intermediate bench
    });

    test('categorizeExercise maps exercise to category', () {
      expect(categorizeExercise('barbell_back_squat'), equals(ExerciseCategory.squat));
      expect(categorizeExercise('barbell_bench_press'), equals(ExerciseCategory.bench));
      expect(categorizeExercise('barbell_deadlift'), equals(ExerciseCategory.deadlift));
      expect(categorizeExercise('dumbbell_bicep_curl'), equals(ExerciseCategory.isolation));
    });
  });
}
```

**Step 2: Implement** `ExerciseCategory` enum, lookup table of BW ratios, `estimateBaselineE1rm()`, `categorizeExercise()`.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): add cold-start strength baseline estimation"
```

---

## Task 21: TrainingState Serialization

**Files:**
- Create: `packages/training_engine/lib/src/models/training_state.dart`
- Create: `packages/training_engine/test/models/training_state_test.dart`

**Step 1: Write tests**

Test JSON roundtrip for the full `TrainingState` object including all nested collections (e1rmHistory, fatigueLog, dailyLoads, ewmaState, sleepHistory, hrvHistory, profile).

**Step 2: Implement** `TrainingState` with `toJson()` / `fromJson()`, `copyWith()`.

**Step 3: Run tests, commit**

```bash
git commit -m "feat(training-engine): implement TrainingState with JSON serialization"
```

---

## Task 22: TrainingEngine Facade

**Files:**
- Create: `packages/training_engine/lib/src/engine.dart`
- Create: `packages/training_engine/test/engine_test.dart`
- Modify: `packages/training_engine/lib/training_engine.dart` (barrel export)

**Step 1: Write integration tests**

```dart
import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  late TrainingEngine engine;

  setUp(() {
    engine = TrainingEngine(
      registry: ExerciseRegistry.withDefaults(),
      profile: UserProfile(
        sex: Sex.male, age: 28, bodyWeightKg: 80,
        experience: ExperienceLevel.intermediate,
        goal: HypertrophyGoal.hypertrophy,
        availableDays: [0, 2, 4],
        maxSessionDuration: Duration(minutes: 60),
        createdAt: DateTime(2026, 4, 1),
      ),
    );
  });

  test('ingestSession updates e1RM, fatigue, and ACWR', () {
    final session = EngineSession(
      id: 's1',
      startedAt: DateTime(2026, 4, 1, 9, 0),
      endedAt: DateTime(2026, 4, 1, 10, 15),
      sets: [
        LoggedSet(exerciseId: 'barbell_back_squat', weightKg: 100, reps: 8,
          rpe: 8.0, completedAt: DateTime(2026, 4, 1, 9, 10)),
        LoggedSet(exerciseId: 'barbell_back_squat', weightKg: 100, reps: 8,
          rpe: 8.5, completedAt: DateTime(2026, 4, 1, 9, 15)),
        LoggedSet(exerciseId: 'barbell_back_squat', weightKg: 100, reps: 7,
          rpe: 9.0, completedAt: DateTime(2026, 4, 1, 9, 20)),
      ],
    );

    engine.ingestSession(session);

    expect(engine.currentE1rm('barbell_back_squat'), isNotNull);
    expect(engine.currentFatigue('quadriceps'), greaterThan(0));
    expect(engine.state.sessionsIngested, equals(1));
  });

  test('recommendLoad returns suggestion after session ingestion', () {
    // Ingest a session first
    final session = EngineSession(
      id: 's1',
      startedAt: DateTime(2026, 4, 1, 9, 0),
      endedAt: DateTime(2026, 4, 1, 10, 0),
      sets: [
        LoggedSet(exerciseId: 'barbell_back_squat', weightKg: 100, reps: 10,
          rpe: 7.5, completedAt: DateTime(2026, 4, 1, 9, 10)),
        LoggedSet(exerciseId: 'barbell_back_squat', weightKg: 100, reps: 10,
          rpe: 8.0, completedAt: DateTime(2026, 4, 1, 9, 15)),
      ],
    );
    engine.ingestSession(session);

    // Query recommendation 3 days later (recovered)
    final rec = engine.recommendLoad('barbell_back_squat',
      at: DateTime(2026, 4, 4, 9, 0));

    expect(rec.suggestedWeightKg, greaterThan(0));
    expect(rec.delta, equals(PerformanceDelta.progression)); // hit 10 @ RPE 7.5
    expect(rec.explanation, isNotEmpty);
  });

  test('bootstrapFromHistory processes legacy sessions', () {
    final legacySessions = [
      EngineSession(
        id: 'legacy_1',
        startedAt: DateTime(2026, 3, 1, 9, 0),
        endedAt: DateTime(2026, 3, 1, 10, 0),
        sets: [
          LoggedSet(exerciseId: 'barbell_back_squat', weightKg: 90, reps: 10,
            rpe: 8.0, completedAt: DateTime(2026, 3, 1, 9, 10), rpeEstimated: true),
        ],
        sessionRpe: 8.0,
      ),
    ];

    engine.bootstrapFromHistory(legacySessions);
    expect(engine.state.sessionsIngested, equals(1));
    expect(engine.currentE1rm('barbell_back_squat'), isNotNull);
  });

  test('state serialization roundtrip', () {
    engine.ingestSession(EngineSession(
      id: 's1',
      startedAt: DateTime(2026, 4, 1, 9, 0),
      endedAt: DateTime(2026, 4, 1, 10, 0),
      sets: [
        LoggedSet(exerciseId: 'barbell_back_squat', weightKg: 100, reps: 8,
          rpe: 8.0, completedAt: DateTime(2026, 4, 1, 9, 10)),
      ],
    ));

    final json = engine.serializeState();
    final restored = TrainingEngine(
      registry: ExerciseRegistry.withDefaults(),
      profile: engine.state.profile,
    );
    restored.restoreState(json);

    expect(restored.currentE1rm('barbell_back_squat'),
      equals(engine.currentE1rm('barbell_back_squat')));
  });

  test('generatePlan produces valid weekly plan', () {
    final plan = engine.generatePlan(PlannerConfig(
      availableDays: [0, 2, 4],
      maxSessionDuration: Duration(minutes: 60),
      goal: HypertrophyGoal.hypertrophy,
      preferredExercises: [],
      excludedExercises: [],
    ));

    expect(plan.sessions.length, equals(3));
    expect(plan.splitType, equals(SplitType.fullBody));
    for (final session in plan.sessions) {
      expect(session.estimatedDuration.inMinutes, lessThanOrEqualTo(65)); // small margin
    }
  });
}
```

**Step 2: Implement** `TrainingEngine` class wiring all subsystems. Key methods:
- `ingestSession()` — computes e1RM estimates, fatigue impulses, daily load, updates EWMA
- `ingestSleep()` / `ingestHrv()` — appends to history, trims to 14 days
- `recommendLoad()` — runs full pipeline (gates -> delta -> predictor -> rounding)
- `bootstrapFromHistory()` — replays legacy sessions with RPE backfill
- `serializeState()` / `restoreState()` — JSON roundtrip

**Step 3: Update barrel export** to re-export all public types.

**Step 4: Run all tests**

```bash
cd packages/training_engine && dart test
```

Expected: All tests pass.

**Step 5: Commit**

```bash
git commit -m "feat(training-engine): implement TrainingEngine facade"
```

---

## Task 23: Host App — CompletedSet Model Change

**Files:**
- Modify: `lib/src/data/models/completed_set.dart`
- Modify: tests that create CompletedSet instances

**Step 1: Add `rpe` field to CompletedSet**

Add `this.rpe` as nullable double:
```dart
class CompletedSet {
  const CompletedSet({
    required this.exerciseId,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    required this.completedAt,
    required this.note,
    this.durationSeconds = 0,
    this.rpe,   // NEW: nullable for migration
  });

  // ... existing fields ...
  final double? rpe;
```

Update `copyWith`, `toJson`, `fromJson` accordingly.

**Step 2: Run existing tests to verify no regression**

```bash
cd /Users/mamy/Project/StrengthApp && flutter test
```

**Step 3: Commit**

```bash
git commit -m "feat: add per-set RPE field to CompletedSet (nullable for migration)"
```

---

## Task 24: Host App — Training Engine Adapter

**Files:**
- Create: `lib/src/features/training_engine/training_engine_adapter.dart`
- Create: `test/features/training_engine/adapter_test.dart`

**Step 1: Write tests**

Test the adapter maps:
- `WorkoutSession` + `CompletedSet` (with per-set RPE) -> `EngineSession` + `LoggedSet`
- Legacy session (no per-set RPE, has session RPE) -> backfills RPE on all sets with `rpeEstimated: true`
- Legacy session (no RPE at all) -> uses default RPE 8.0
- `Exercise` -> `EngineExercise` with muscle map lookup from registry

**Step 2: Implement** `TrainingEngineAdapter` with `toEngineSession()`, `toEngineExercise()` methods.

**Step 3: Run tests, commit**

```bash
git commit -m "feat: add training engine adapter for AppState mapping"
```

---

## Task 25: Host App — Riverpod Providers

**Files:**
- Create: `lib/src/features/training_engine/training_engine_provider.dart`
- Create: `lib/src/features/training_engine/healthkit_data_source.dart`

**Step 1: Implement providers**

```dart
// training_engine_provider.dart
final trainingEngineProvider = Provider<TrainingEngine>((ref) {
  final appState = ref.watch(appStateControllerProvider);
  final adapter = TrainingEngineAdapter();
  final registry = ExerciseRegistry.withDefaults();

  // Add custom exercises from app state
  for (final exercise in appState.exercises) {
    final engineEx = adapter.toEngineExercise(exercise, registry);
    if (engineEx != null) registry.addCustom(engineEx);
  }

  final engine = TrainingEngine(
    registry: registry,
    profile: adapter.toUserProfile(appState),
  );

  // Restore persisted state (implementation depends on repository)
  return engine;
});

final fatigueMapProvider = Provider<Map<String, FatigueStatus>>((ref) {
  return ref.watch(trainingEngineProvider).fullFatigueMap();
});

final readinessProvider = Provider<ReadinessScore?>((ref) {
  final engine = ref.watch(trainingEngineProvider);
  return engine.computeReadiness();
});

final loadRecommendationProvider = Provider.family<LoadRecommendation?, String>(
  (ref, exerciseId) {
    final engine = ref.watch(trainingEngineProvider);
    return engine.currentE1rm(exerciseId) != null
        ? engine.recommendLoad(exerciseId)
        : null;
  },
);
```

**Step 2: Create HealthKit data source stub**

`healthkit_data_source.dart` — interface for fetching sleep and HRV data. Initial implementation as a stub returning empty lists (HealthKit plugin integration is a separate task).

```dart
class HealthKitDataSource {
  Future<List<SleepRecord>> fetchRecentSleep({int days = 14}) async => [];
  Future<List<HrvRecord>> fetchRecentHrv({int days = 14}) async => [];
  Future<bool> requestAuthorization() async => false;
}
```

**Step 3: Run flutter analyze**

```bash
flutter analyze
```

**Step 4: Commit**

```bash
git commit -m "feat: add training engine Riverpod providers and HealthKit stub"
```

---

## Task 26: Integration Smoke Test

**Files:**
- Create: `test/features/training_engine/integration_test.dart`

**Step 1: Write end-to-end integration test**

Test the full flow:
1. Create an AppState with exercises and a completed session (with per-set RPE)
2. Adapter maps to engine types
3. Engine ingests session
4. Query e1RM, fatigue map, load recommendation
5. Verify all return sensible values

**Step 2: Run full test suite**

```bash
flutter test && cd packages/training_engine && dart test
```

**Step 3: Commit**

```bash
git commit -m "test: add training engine integration smoke test"
```

---

## Summary

| Task | Component | Est. Steps |
|---|---|---|
| 1 | Package scaffold | 7 |
| 2 | Core enums + value types | 8 |
| 3 | Session/set/exercise models | 8 |
| 4 | Health data models | 3 |
| 5 | State models | 3 |
| 6 | e1RM formulas | 5 |
| 7 | e1RM composite estimator | 3 |
| 8 | Muscle registry | 3 |
| 9 | Fatigue impulse calculator | 3 |
| 10 | Fatigue exponential decay | 3 |
| 11 | ACWR (EWMA + zones) | 3 |
| 12 | Readiness scoring | 3 |
| 13 | Safety gates | 3 |
| 14 | Performance delta + load predictor | 3 |
| 15 | LoadRecommendation assembly | 3 |
| 16 | Split selector | 3 |
| 17 | Session generator + time bounder | 3 |
| 18 | Missed session + fatigue substitution | 3 |
| 19 | Exercise registry (~80 exercises) | 3 |
| 20 | Strength baseline (cold start) | 3 |
| 21 | TrainingState serialization | 3 |
| 22 | TrainingEngine facade | 5 |
| 23 | CompletedSet model change | 3 |
| 24 | Training engine adapter | 3 |
| 25 | Riverpod providers | 4 |
| 26 | Integration smoke test | 3 |

**Total: 26 tasks, ~90 steps, ~26 commits**
