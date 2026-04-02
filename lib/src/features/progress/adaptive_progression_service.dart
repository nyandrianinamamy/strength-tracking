import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

final adaptiveProgressionServiceProvider = Provider<AdaptiveProgressionService>(
  (ref) => const AdaptiveProgressionService(),
);

enum ProgressionDirection { up, hold, down }

class WeightSuggestion {
  const WeightSuggestion({
    required this.suggestedWeightKg,
    required this.previousWeightKg,
    required this.direction,
    required this.reason,
    required this.incrementKg,
  });

  final double suggestedWeightKg;
  final double previousWeightKg;
  final ProgressionDirection direction;
  final String reason;
  final double incrementKg;
}

class AdaptiveProgressionService {
  const AdaptiveProgressionService();

  WeightSuggestion? suggestionForExercise({
    required AppState state,
    required Exercise? exercise,
    required RoutineExercise prescription,
  }) {
    if (exercise == null || exercise.exerciseType != 'strength') {
      return null;
    }

    WorkoutSession? sourceSession;
    for (final session in state.completedSessions) {
      final hasExercise = session.completedSets.any(
        (set) => set.exerciseId == prescription.exerciseId,
      );
      if (hasExercise) {
        sourceSession = session;
        break;
      }
    }

    if (sourceSession == null) {
      return null;
    }

    final loggedSets = sourceSession.completedSets
        .where((set) => set.exerciseId == prescription.exerciseId)
        .toList()
      ..sort((a, b) => a.setNumber.compareTo(b.setNumber));
    if (loggedSets.isEmpty) {
      return null;
    }

    final previousWeightKg = _baseWeightKg(loggedSets);
    if (previousWeightKg <= 0) {
      return null;
    }

    final incrementKg = _progressionIncrementKg(exercise);
    final evaluatedSets = loggedSets.take(prescription.targetSets).toList();
    final allSetsHitTarget =
        evaluatedSets.length >= prescription.targetSets &&
        evaluatedSets.every((set) => set.reps >= prescription.targetReps);
    final averageReps = evaluatedSets.isEmpty
        ? 0.0
        : evaluatedSets.fold<int>(0, (sum, set) => sum + set.reps) /
            evaluatedSets.length;
    final isClearlyUnderTarget =
        evaluatedSets.length >= prescription.targetSets &&
        averageReps <= (prescription.targetReps - 2);
    final effectiveRpe = _effectiveExerciseRpe(
      evaluatedSets,
      fallbackSessionRpe: sourceSession.rpe,
    );

    final direction = _directionForPerformance(
      allSetsHitTarget: allSetsHitTarget,
      completedSetCount: evaluatedSets.length,
      targetSetCount: prescription.targetSets,
      isClearlyUnderTarget: isClearlyUnderTarget,
      effectiveRpe: effectiveRpe,
    );

    final suggestedWeightKg = switch (direction) {
      ProgressionDirection.up => previousWeightKg + incrementKg,
      ProgressionDirection.hold => previousWeightKg,
      ProgressionDirection.down =>
        math.max(0.0, previousWeightKg - incrementKg).toDouble(),
    };

    return WeightSuggestion(
      suggestedWeightKg: _normalizeWeight(suggestedWeightKg),
      previousWeightKg: previousWeightKg,
      direction: direction,
      reason: _reasonForDirection(
        direction,
        completedSetCount: evaluatedSets.length,
        targetSetCount: prescription.targetSets,
        effectiveRpe: effectiveRpe,
      ),
      incrementKg: incrementKg,
    );
  }

  ProgressionDirection _directionForPerformance({
    required bool allSetsHitTarget,
    required int completedSetCount,
    required int targetSetCount,
    required bool isClearlyUnderTarget,
    required double? effectiveRpe,
  }) {
    if (allSetsHitTarget && (effectiveRpe == null || effectiveRpe <= 8.5)) {
      return ProgressionDirection.up;
    }

    if (isClearlyUnderTarget && effectiveRpe != null && effectiveRpe >= 9.5) {
      return ProgressionDirection.down;
    }

    if (completedSetCount < targetSetCount) {
      return ProgressionDirection.hold;
    }

    if (effectiveRpe != null && effectiveRpe > 8.5) {
      return ProgressionDirection.hold;
    }

    return ProgressionDirection.hold;
  }

  String _reasonForDirection(
    ProgressionDirection direction, {
    required int completedSetCount,
    required int targetSetCount,
    required double? effectiveRpe,
  }) {
    switch (direction) {
      case ProgressionDirection.up:
        return 'Hit all target reps last time';
      case ProgressionDirection.down:
        return 'Back off slightly after a grind';
      case ProgressionDirection.hold:
        if (completedSetCount < targetSetCount) {
          return 'Hold until all working sets are completed';
        }
        if (effectiveRpe != null && effectiveRpe > 8.5) {
          return 'Hold because the last session felt hard';
        }
        return 'Hold and build consistency first';
    }
  }

  double? _effectiveExerciseRpe(
    List<CompletedSet> sets, {
    required double? fallbackSessionRpe,
  }) {
    final loggedRpes = sets
        .map((set) => set.rpe)
        .whereType<double>()
        .toList(growable: false);
    if (loggedRpes.isEmpty) {
      return fallbackSessionRpe;
    }

    final total = loggedRpes.fold<double>(0, (sum, rpe) => sum + rpe);
    return total / loggedRpes.length;
  }

  double _progressionIncrementKg(Exercise exercise) {
    final name = exercise.name.toLowerCase();
    final equipment = exercise.equipment.map((item) => item.toLowerCase()).toSet();
    final muscles = exercise.primaryMuscles.map((item) => item.toLowerCase()).toSet();

    final isLowerCompound =
        _containsAny(name, const [
          'squat',
          'deadlift',
          'leg press',
          'hip thrust',
          'split squat',
          'lunge',
          'hack squat',
          'good morning',
          'step up',
        ]) ||
        ((muscles.contains('quadriceps') ||
                muscles.contains('hamstrings') ||
                muscles.contains('glutes')) &&
            equipment.contains('barbell'));
    if (isLowerCompound) {
      return 5.0;
    }

    final isUpperCompound =
        _containsAny(name, const [
          'bench press',
          'overhead press',
          'shoulder press',
          'row',
          'pulldown',
          'pull up',
          'chin up',
          'dip',
          'press',
        ]) ||
        ((muscles.contains('chest') ||
                muscles.contains('back') ||
                muscles.contains('upper back') ||
                muscles.contains('deltoids') ||
                muscles.contains('shoulders')) &&
            (equipment.contains('barbell') || equipment.contains('dumbbell')));
    if (isUpperCompound) {
      return 2.5;
    }

    return 1.25;
  }

  bool _containsAny(String value, List<String> needles) {
    for (final needle in needles) {
      if (value.contains(needle)) {
        return true;
      }
    }
    return false;
  }

  double _baseWeightKg(List<CompletedSet> sets) {
    final counts = <double, int>{};
    for (final set in sets) {
      final normalized = _normalizeWeight(set.weightKg);
      counts[normalized] = (counts[normalized] ?? 0) + 1;
    }

    var bestWeight = _normalizeWeight(sets.last.weightKg);
    var bestCount = 0;
    for (final entry in counts.entries) {
      final shouldReplace =
          entry.value > bestCount ||
          (entry.value == bestCount && entry.key >= bestWeight);
      if (shouldReplace) {
        bestWeight = entry.key;
        bestCount = entry.value;
      }
    }

    return bestWeight;
  }

  double _normalizeWeight(double value) {
    return (value * 100).roundToDouble() / 100;
  }
}
