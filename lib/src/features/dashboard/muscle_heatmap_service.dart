import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';

final muscleHeatmapServiceProvider = Provider<MuscleHeatmapService>((ref) {
  return MuscleHeatmapService();
});

class MuscleHeatmapService {
  /// All recognized muscle groups for the heatmap
  static const allMuscles = [
    'Chest',
    'Shoulders',
    'Biceps',
    'Abs',
    'Quads',
    'Upper Back',
    'Lats',
    'Triceps',
    'Glutes',
    'Hamstrings',
  ];

  /// Front-facing muscles
  static const frontMuscles = [
    'Chest',
    'Shoulders',
    'Biceps',
    'Abs',
    'Quads',
  ];

  /// Back-facing muscles
  static const backMuscles = [
    'Upper Back',
    'Lats',
    'Triceps',
    'Glutes',
    'Hamstrings',
  ];

  /// Maps exercise primaryMuscles names to heatmap muscle names.
  /// The exercise model uses names like 'Back', 'Arms', 'Legs' —
  /// we need to map those to our more specific regions.
  static const Map<String, List<String>> muscleMapping = {
    'Chest': ['Chest'],
    'Back': ['Upper Back', 'Lats'],
    'Shoulders': ['Shoulders'],
    'Arms': ['Biceps', 'Triceps'],
    'Biceps': ['Biceps'],
    'Triceps': ['Triceps'],
    'Legs': ['Quads', 'Hamstrings', 'Glutes'],
    'Quads': ['Quads'],
    'Hamstrings': ['Hamstrings'],
    'Glutes': ['Glutes'],
    'Abs': ['Abs'],
    'Core': ['Abs'],
    'Upper Back': ['Upper Back'],
    'Lats': ['Lats'],
  };

  /// Compute fatigue levels for all muscles.
  /// Returns a map of muscle name to fatigue value (0.0 to 1.0).
  Map<String, double> computeFatigue(AppState state) {
    final now = DateTime.now();
    final rawVolume = <String, double>{};

    for (final session in state.completedSessions) {
      for (final set in session.completedSets) {
        final exercise = state.exerciseById(set.exerciseId);
        if (exercise == null) continue;

        final volume = set.weightKg * set.reps;
        final hoursElapsed = now.difference(set.completedAt).inMinutes / 60.0;

        // Exponential decay: halves every 48 hours
        final decayFactor = _decay(hoursElapsed);

        // Skip if contribution is negligible (older than ~10 days)
        if (decayFactor < 0.01) continue;

        final decayedVolume = volume * decayFactor;

        // Map exercise muscles to heatmap muscles
        for (final muscle in exercise.primaryMuscles) {
          final mapped = muscleMapping[muscle] ?? [muscle];
          for (final target in mapped) {
            rawVolume[target] = (rawVolume[target] ?? 0) + decayedVolume;
          }
        }

        // Secondary muscles contribute at 50% weight
        for (final muscle in exercise.secondaryMuscles) {
          final mapped = muscleMapping[muscle] ?? [muscle];
          for (final target in mapped) {
            rawVolume[target] = (rawVolume[target] ?? 0) + decayedVolume * 0.5;
          }
        }
      }
    }

    // Normalize to 0-1 range
    final maxVolume = rawVolume.values.isEmpty
        ? 1.0
        : rawVolume.values.reduce((a, b) => a > b ? a : b);

    final result = <String, double>{};
    for (final muscle in allMuscles) {
      final raw = rawVolume[muscle] ?? 0;
      result[muscle] = maxVolume > 0 ? (raw / maxVolume).clamp(0.0, 1.0) : 0.0;
    }

    return result;
  }

  /// Exponential decay: halves every 48 hours.
  double _decay(double hoursElapsed) {
    if (hoursElapsed <= 0) return 1.0;
    return math.pow(0.5, hoursElapsed / 48.0).toDouble();
  }
}
