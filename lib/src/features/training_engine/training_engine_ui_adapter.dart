import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:training_engine/training_engine.dart';

enum EngineSuggestionDirection { up, hold, down }

class EngineWeightSuggestion {
  const EngineWeightSuggestion({
    required this.suggestedWeightKg,
    required this.direction,
    required this.reason,
  });

  final double suggestedWeightKg;
  final EngineSuggestionDirection direction;
  final String reason;
}

class TrainingEngineUiAdapter {
  const TrainingEngineUiAdapter();

  static const Map<String, List<Muscle>> _appMuscleMap = {
    'Chest': [Muscle.chest],
    'Upper Back': [Muscle.upperBack],
    'Back': [Muscle.upperBack, Muscle.lowerBack],
    'Trapezius': [Muscle.trapezius],
    'Deltoids': [Muscle.deltoids],
    'Shoulders': [Muscle.deltoids],
    'Biceps': [Muscle.biceps],
    'Triceps': [Muscle.triceps],
    'Forearm': [Muscle.forearm],
    'Abs': [Muscle.abs],
    'Obliques': [Muscle.obliques],
    'Lower Back': [Muscle.lowerBack],
    'Quadriceps': [Muscle.quadriceps],
    'Quads': [Muscle.quadriceps],
    'Hamstrings': [Muscle.hamstring],
    'Glutes': [Muscle.gluteal],
    'Calves': [Muscle.calves],
    'Adductors': [Muscle.adductors],
    'Tibialis': [Muscle.tibialis],
    'Legs': [Muscle.quadriceps, Muscle.hamstring, Muscle.calves],
  };

  static const Map<String, List<Muscle>> _muscleMap = {
    'pectorals': [Muscle.chest],
    'upper_back': [Muscle.upperBack],
    'lats': [Muscle.upperBack],
    'rhomboids': [Muscle.upperBack],
    'trapezius': [Muscle.trapezius],
    'anterior_deltoid': [Muscle.deltoids],
    'lateral_deltoid': [Muscle.deltoids],
    'rear_deltoid': [Muscle.deltoids],
    'biceps': [Muscle.biceps],
    'triceps': [Muscle.triceps],
    'forearms': [Muscle.forearm],
    'brachialis': [Muscle.forearm],
    'brachioradialis': [Muscle.forearm],
    'abs': [Muscle.abs],
    'obliques': [Muscle.obliques],
    'lower_back': [Muscle.lowerBack],
    'erector_spinae': [Muscle.lowerBack],
    'quadriceps': [Muscle.quadriceps],
    'hamstrings': [Muscle.hamstring],
    'glutes': [Muscle.gluteal],
    'calves': [Muscle.calves],
    'adductors': [Muscle.adductors],
    'tibialis_anterior': [Muscle.tibialis],
  };

  Map<Muscle, MuscleData> toHeatmapData(
    Map<String, FatigueStatus> fatigueMap,
  ) {
    final result = <Muscle, MuscleData>{};

    for (final entry in fatigueMap.entries) {
      final mappedMuscles = _muscleMap[entry.key];
      if (mappedMuscles == null) {
        continue;
      }

      final intensity = (entry.value.level / 100).clamp(0.0, 1.0);
      for (final muscle in mappedMuscles) {
        final previous = result[muscle]?.intensity ?? 0.0;
        if (intensity >= previous) {
          result[muscle] = MuscleData(intensity: intensity);
        }
      }
    }

    return result;
  }

  Set<Muscle> appMusclesToHeatmap(Iterable<String> muscles) {
    final result = <Muscle>{};
    for (final name in muscles) {
      result.addAll(_appMuscleMap[name] ?? const []);
    }
    return result;
  }

  EngineWeightSuggestion? toWeightSuggestion(
    LoadRecommendation? recommendation,
  ) {
    final suggestedWeightKg = recommendation?.suggestedWeightKg;
    if (suggestedWeightKg == null) {
      return null;
    }

    final direction = switch (recommendation!.delta) {
      PerformanceDelta.progression => EngineSuggestionDirection.up,
      PerformanceDelta.maintenance => EngineSuggestionDirection.hold,
      PerformanceDelta.regression => EngineSuggestionDirection.down,
    };

    return EngineWeightSuggestion(
      suggestedWeightKg: suggestedWeightKg,
      direction: direction,
      reason: recommendation.explanation,
    );
  }
}
