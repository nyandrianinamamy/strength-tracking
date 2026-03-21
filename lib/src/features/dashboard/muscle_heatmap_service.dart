import 'dart:math' as math;

import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';

final muscleHeatmapServiceProvider = Provider<MuscleHeatmapService>((ref) {
  return MuscleHeatmapService();
});

class MuscleHeatmapService {
  /// Maps exercise primaryMuscles/secondaryMuscles strings to package Muscle enum values.
  /// Each name maps 1:1 to a single Muscle enum value.
  static const Map<String, List<Muscle>> muscleMapping = {
    'Chest': [Muscle.chest],
    'Upper Back': [Muscle.upperBack],
    'Trapezius': [Muscle.trapezius],
    'Deltoids': [Muscle.deltoids],
    'Biceps': [Muscle.biceps],
    'Triceps': [Muscle.triceps],
    'Forearm': [Muscle.forearm],
    'Abs': [Muscle.abs],
    'Obliques': [Muscle.obliques],
    'Lower Back': [Muscle.lowerBack],
    'Quadriceps': [Muscle.quadriceps],
    'Hamstrings': [Muscle.hamstring],
    'Glutes': [Muscle.gluteal],
    'Calves': [Muscle.calves],
    'Adductors': [Muscle.adductors],
    'Tibialis': [Muscle.tibialis],
  };

  /// Compute fatigue levels for all muscles.
  /// Returns a map of Muscle to MuscleData with intensity (0.0 to 1.0).
  Map<Muscle, MuscleData> computeFatigue(AppState state) {
    final now = DateTime.now();
    final rawVolume = <Muscle, double>{};
    final sessions = [
      ...state.completedSessions,
      if (state.activeSession != null) state.activeSession!,
    ];

    for (final session in sessions) {
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
    const frontMuscles = {Muscle.chest, Muscle.deltoids, Muscle.biceps, Muscle.forearm, Muscle.abs, Muscle.obliques, Muscle.quadriceps, Muscle.adductors, Muscle.tibialis};
    const backMuscles = {Muscle.upperBack, Muscle.trapezius, Muscle.deltoids, Muscle.triceps, Muscle.forearm, Muscle.gluteal, Muscle.hamstring, Muscle.calves, Muscle.lowerBack};

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
