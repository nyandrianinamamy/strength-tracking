import 'dart:math' as math;

import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';

final muscleHeatmapServiceProvider = Provider<MuscleHeatmapService>((ref) {
  return MuscleHeatmapService();
});

class MuscleHeatmapService {
  /// Maps exercise primaryMuscles/secondaryMuscles strings to package Muscle enum values.
  static const Map<String, List<Muscle>> muscleMapping = {
    'Chest': [Muscle.chest],
    'Back': [Muscle.upperBack, Muscle.trapezius],
    'Shoulders': [Muscle.deltoids],
    'Arms': [Muscle.biceps, Muscle.triceps],
    'Biceps': [Muscle.biceps],
    'Triceps': [Muscle.triceps],
    'Legs': [Muscle.quadriceps, Muscle.hamstring, Muscle.gluteal],
    'Quads': [Muscle.quadriceps],
    'Quadriceps': [Muscle.quadriceps],
    'Hamstrings': [Muscle.hamstring],
    'Glutes': [Muscle.gluteal],
    'Abs': [Muscle.abs],
    'Core': [Muscle.abs, Muscle.obliques],
    'Upper Back': [Muscle.upperBack],
    'Lats': [Muscle.trapezius],
    'Forearm': [Muscle.forearm],
    'Calves': [Muscle.calves],
  };

  /// Compute fatigue levels for all muscles.
  /// Returns a map of Muscle to MuscleData with intensity (0.0 to 1.0).
  Map<Muscle, MuscleData> computeFatigue(AppState state) {
    final now = DateTime.now();
    final rawVolume = <Muscle, double>{};

    for (final session in state.completedSessions) {
      for (final set in session.completedSets) {
        final exercise = state.exerciseById(set.exerciseId);
        if (exercise == null) continue;

        final volume = set.weightKg * set.reps + set.durationSeconds.toDouble();
        final hoursElapsed = now.difference(set.completedAt).inMinutes / 60.0;
        final decayFactor = _decay(hoursElapsed);
        if (decayFactor < 0.01) continue;
        final decayedVolume = volume * decayFactor;

        // Primary muscles at full weight
        for (final muscle in exercise.primaryMuscles) {
          final mapped = muscleMapping[muscle] ?? [];
          for (final target in mapped) {
            rawVolume[target] = (rawVolume[target] ?? 0) + decayedVolume;
          }
        }

        // Secondary muscles at 50% weight
        for (final muscle in exercise.secondaryMuscles) {
          final mapped = muscleMapping[muscle] ?? [];
          for (final target in mapped) {
            rawVolume[target] = (rawVolume[target] ?? 0) + decayedVolume * 0.5;
          }
        }
      }
    }

    // Normalize to 0-1
    final maxVolume = rawVolume.values.isEmpty
        ? 1.0
        : rawVolume.values.reduce((a, b) => a > b ? a : b);

    final result = <Muscle, MuscleData>{};
    for (final entry in rawVolume.entries) {
      final intensity = maxVolume > 0 ? (entry.value / maxVolume).clamp(0.0, 1.0) : 0.0;
      if (intensity > 0) {
        result[entry.key] = MuscleData(intensity: intensity);
      }
    }

    return result;
  }

  /// Determines if any of the given exercise muscles appear on the front/back.
  static ({bool front, bool back}) sidesForMuscles(List<String> muscles) {
    const frontMuscles = {Muscle.chest, Muscle.deltoids, Muscle.biceps, Muscle.abs, Muscle.obliques, Muscle.quadriceps, Muscle.adductors, Muscle.tibialis};
    const backMuscles = {Muscle.upperBack, Muscle.trapezius, Muscle.triceps, Muscle.gluteal, Muscle.hamstring, Muscle.calves, Muscle.lowerBack};

    bool front = false, back = false;
    for (final name in muscles) {
      final mapped = muscleMapping[name] ?? [];
      for (final m in mapped) {
        if (frontMuscles.contains(m)) front = true;
        if (backMuscles.contains(m)) back = true;
      }
    }
    // Deltoids appear on both front and back
    return (front: front, back: back);
  }

  /// Exponential decay: halves every 48 hours.
  double _decay(double hoursElapsed) {
    if (hoursElapsed <= 0) return 1.0;
    return math.pow(0.5, hoursElapsed / 48.0).toDouble();
  }
}
