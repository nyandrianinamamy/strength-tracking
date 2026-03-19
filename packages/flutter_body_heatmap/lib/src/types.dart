import 'dart:ui' show Color;

/// Which side of the body to display.
enum BodySide { front, back }

/// Male or female body shape.
enum BodyGender { male, female }

/// Which side of a bilateral muscle.
enum MuscleSide { left, right, both }

/// Data for a single muscle's highlight state.
class MuscleData {
  const MuscleData({
    this.intensity = 1.0,
    this.color,
    this.side = MuscleSide.both,
  });

  /// Intensity from 0.0 (no highlight) to any positive value.
  /// Used to index into the color scale.
  final double intensity;

  /// Override color for this specific muscle. Takes priority over color scale.
  final Color? color;

  /// Which side to highlight (left, right, or both).
  final MuscleSide side;
}
