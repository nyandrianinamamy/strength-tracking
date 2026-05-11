import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:training_engine/training_engine.dart';

enum EngineSuggestionDirection { up, hold, down }

class EngineWeightSuggestion {
  const EngineWeightSuggestion({
    required this.suggestedWeightKg,
    required this.direction,
    required this.reason,
    this.gateAction,
  });

  final double suggestedWeightKg;
  final EngineSuggestionDirection direction;
  final String reason;
  final GateAction? gateAction;
}

String engineSuggestionDirectionLabel(EngineWeightSuggestion suggestion) {
  switch (suggestion.gateAction) {
    case GateAction.deload:
      return 'deload';
    case GateAction.reduceLoad:
      return 'reduce load';
    case GateAction.suggestAlternative:
      return 'alternative suggested';
    case GateAction.maintain:
    case null:
      break;
  }

  switch (suggestion.direction) {
    case EngineSuggestionDirection.up:
      return 'up from last time';
    case EngineSuggestionDirection.hold:
      return 'hold steady';
    case EngineSuggestionDirection.down:
      return 'reduce from last time';
  }
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

  /// Maps canonical engine muscle IDs → heatmap [Muscle] enum values.
  ///
  /// Only canonical IDs are listed here. Any stale/aliased IDs in the fatigue
  /// map are resolved via [MuscleNormalizer.normalize] before lookup.
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
    'core': [Muscle.abs],
    'obliques': [Muscle.obliques],
    'lower_back': [Muscle.lowerBack],
    'erector_spinae': [Muscle.lowerBack],
    'rotator_cuff': [Muscle.deltoids, Muscle.upperBack],
    'serratus_anterior': [Muscle.chest, Muscle.obliques],
    'quadriceps': [Muscle.quadriceps],
    'hamstrings': [Muscle.hamstring],
    'glutes': [Muscle.gluteal],
    'hip_flexors': [Muscle.quadriceps, Muscle.abs],
    'calves': [Muscle.calves],
    'adductors': [Muscle.adductors],
    'abductors': [Muscle.gluteal],
    'tibialis_anterior': [Muscle.tibialis],
    'neck': [Muscle.neck],
  };

  Map<Muscle, MuscleData> toHeatmapData(Map<String, FatigueStatus> fatigueMap) {
    final result = <Muscle, MuscleData>{};

    for (final entry in fatigueMap.entries) {
      final canonical = MuscleNormalizer.normalize(entry.key);
      final mappedMuscles = _muscleMap[canonical];
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
    final rec = recommendation;
    if (rec == null || rec.suggestedWeightKg == null) {
      return null;
    }
    final suggestedWeightKg = rec.suggestedWeightKg!;

    final direction = _directionFor(rec);

    return EngineWeightSuggestion(
      suggestedWeightKg: suggestedWeightKg,
      direction: direction,
      reason: rec.explanation,
      gateAction: rec.gateResult.action,
    );
  }

  EngineSuggestionDirection _directionFor(LoadRecommendation recommendation) {
    switch (recommendation.gateResult.action) {
      case GateAction.deload:
      case GateAction.reduceLoad:
      case GateAction.suggestAlternative:
        return EngineSuggestionDirection.down;
      case GateAction.maintain:
      case null:
        break;
    }

    final previousWeightKg = recommendation.previousWeightKg;
    final suggestedWeightKg = recommendation.suggestedWeightKg;
    if (previousWeightKg != null && suggestedWeightKg != null) {
      const tolerance = 0.001;
      if (suggestedWeightKg < previousWeightKg - tolerance) {
        return EngineSuggestionDirection.down;
      }
      if (suggestedWeightKg > previousWeightKg + tolerance) {
        return EngineSuggestionDirection.up;
      }
      return EngineSuggestionDirection.hold;
    }

    return switch (recommendation.delta) {
      PerformanceDelta.progression => EngineSuggestionDirection.up,
      PerformanceDelta.maintenance => EngineSuggestionDirection.hold,
      PerformanceDelta.regression => EngineSuggestionDirection.down,
    };
  }
}
