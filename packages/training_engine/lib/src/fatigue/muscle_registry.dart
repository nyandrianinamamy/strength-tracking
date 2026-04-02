import 'dart:math';
import '../models/enums.dart';

class MuscleDefinition {
  final String id;
  final String displayName;
  final MuscleSize size;
  final double decayConstant; // tau in hours

  const MuscleDefinition({
    required this.id,
    required this.displayName,
    required this.size,
    required this.decayConstant,
  });
}

/// Computes exponential decay constant tau such that fatigue drops to 5%
/// after the given recovery time: tau = -T_recovery / ln(0.05)
/// ln(0.05) = -2.995732...
double decayConstantForSize(MuscleSize size) {
  const ln005 = -2.995732273553991; // ln(0.05)
  switch (size) {
    case MuscleSize.small:
      return -36.0 / ln005; // ~12.01
    case MuscleSize.moderate:
      return -48.0 / ln005; // ~16.01
    case MuscleSize.large:
      return -72.0 / ln005; // ~24.02
  }
}

MuscleDefinition _def(String id, String displayName, MuscleSize size) =>
    MuscleDefinition(
      id: id,
      displayName: displayName,
      size: size,
      decayConstant: decayConstantForSize(size),
    );

/// Default muscle registry: ~28 muscles keyed by id.
final Map<String, MuscleDefinition> defaultMuscles = {
  // Small muscles
  'biceps': _def('biceps', 'Biceps', MuscleSize.small),
  'lateral_deltoid': _def('lateral_deltoid', 'Lateral Deltoid', MuscleSize.small),
  'calves': _def('calves', 'Calves', MuscleSize.small),
  'forearms': _def('forearms', 'Forearms', MuscleSize.small),
  'brachialis': _def('brachialis', 'Brachialis', MuscleSize.small),
  'brachioradialis': _def('brachioradialis', 'Brachioradialis', MuscleSize.small),
  'tibialis_anterior': _def('tibialis_anterior', 'Tibialis Anterior', MuscleSize.small),

  // Moderate muscles
  'triceps': _def('triceps', 'Triceps', MuscleSize.moderate),
  'rear_deltoid': _def('rear_deltoid', 'Rear Deltoid', MuscleSize.moderate),
  'anterior_deltoid': _def('anterior_deltoid', 'Anterior Deltoid', MuscleSize.moderate),
  'trapezius': _def('trapezius', 'Trapezius', MuscleSize.moderate),
  'abs': _def('abs', 'Abs', MuscleSize.moderate),
  'obliques': _def('obliques', 'Obliques', MuscleSize.moderate),
  'hamstrings': _def('hamstrings', 'Hamstrings', MuscleSize.moderate),
  'rotator_cuff': _def('rotator_cuff', 'Rotator Cuff', MuscleSize.moderate),
  'serratus_anterior': _def('serratus_anterior', 'Serratus Anterior', MuscleSize.moderate),
  'rhomboids': _def('rhomboids', 'Rhomboids', MuscleSize.moderate),

  // Large muscles
  'quadriceps': _def('quadriceps', 'Quadriceps', MuscleSize.large),
  'glutes': _def('glutes', 'Glutes', MuscleSize.large),
  'pectorals': _def('pectorals', 'Pectorals', MuscleSize.large),
  'lats': _def('lats', 'Lats', MuscleSize.large),
  'upper_back': _def('upper_back', 'Upper Back', MuscleSize.large),
  'erector_spinae': _def('erector_spinae', 'Erector Spinae', MuscleSize.large),
  'lower_back': _def('lower_back', 'Lower Back', MuscleSize.large),
  'hip_flexors': _def('hip_flexors', 'Hip Flexors', MuscleSize.large),
  'adductors': _def('adductors', 'Adductors', MuscleSize.large),
  'abductors': _def('abductors', 'Abductors', MuscleSize.large),
  'neck': _def('neck', 'Neck', MuscleSize.large),
};
