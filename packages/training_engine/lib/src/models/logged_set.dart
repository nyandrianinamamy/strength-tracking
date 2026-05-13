import 'enums.dart' show IntensityClass;

/// Validates strength or local RPE (5-10 scale).
void _validateRpe5to10(double rpe, String fieldName) {
  if (rpe < 5.0 || rpe > 10.0) {
    throw ArgumentError('$fieldName must be between 5.0 and 10.0, got $rpe');
  }
}

/// Validates effort RPE (0-10 scale for cardio).
void _validateEffortRpe(double rpe) {
  if (rpe < 0.0 || rpe > 10.0) {
    throw ArgumentError('effortRpe must be between 0.0 and 10.0, got $rpe');
  }
}

class LoggedSet {
  final String exerciseId;
  final double weightKg;
  final int reps;
  final DateTime completedAt;
  final bool rpeEstimated;
  final int durationSeconds;

  // New RPE fields for different exercise types
  final double? strengthRpe;
  final double? localRpe;
  final double? effortRpe;
  final IntensityClass? intensityClass;

  factory LoggedSet({
    required String exerciseId,
    required double weightKg,
    required int reps,
    required DateTime completedAt,
    bool rpeEstimated = false,
    int durationSeconds = 0,
    double? strengthRpe,
    double? localRpe,
    double? effortRpe,
    IntensityClass? intensityClass,
    // Backward compatibility: legacy 'rpe' parameter maps to strengthRpe
    double? rpe,
  }) {
    // Merge legacy rpe into strengthRpe for backward compatibility
    final effectiveStrengthRpe = strengthRpe ?? rpe;

    // Validate strength RPE if provided
    if (effectiveStrengthRpe != null) {
      _validateRpe5to10(effectiveStrengthRpe, 'strengthRpe');
    }
    if (localRpe != null) {
      _validateRpe5to10(localRpe, 'localRpe');
    }
    if (effortRpe != null) {
      _validateEffortRpe(effortRpe);
    }
    if (durationSeconds < 0) {
      throw ArgumentError(
        'durationSeconds must be non-negative, got $durationSeconds',
      );
    }

    return LoggedSet._internal(
      exerciseId: exerciseId,
      weightKg: weightKg,
      reps: reps,
      completedAt: completedAt,
      rpeEstimated: rpeEstimated,
      durationSeconds: durationSeconds,
      strengthRpe: effectiveStrengthRpe,
      localRpe: localRpe,
      effortRpe: effortRpe,
      intensityClass: intensityClass,
    );
  }

  const LoggedSet._internal({
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    required this.completedAt,
    required this.rpeEstimated,
    required this.durationSeconds,
    this.strengthRpe,
    this.localRpe,
    this.effortRpe,
    this.intensityClass,
  });

  /// Backward compatibility: returns strengthRpe for legacy code.
  /// Falls back to 8.0 if no strength RPE is recorded (for cardio/isometric sets).
  double get rpe {
    return strengthRpe ?? 8.0;
  }

  /// Whether this set has dynamic resistance load (weight × reps).
  bool get hasStrengthLoad => reps > 0;

  /// Whether this set has a timed duration component.
  bool get hasTimedLoad => durationSeconds > 0;

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'weightKg': weightKg,
    'reps': reps,
    'completedAt': completedAt.toIso8601String(),
    'rpeEstimated': rpeEstimated,
    if (durationSeconds > 0) 'durationSeconds': durationSeconds,
    if (strengthRpe != null) 'strengthRpe': strengthRpe,
    if (localRpe != null) 'localRpe': localRpe,
    if (effortRpe != null) 'effortRpe': effortRpe,
    if (intensityClass != null) 'intensityClass': intensityClass!.name,
    if (strengthRpe != null) 'rpe': strengthRpe,
  };

  factory LoggedSet.fromJson(Map<String, dynamic> json) {
    // Handle legacy JSON that only has 'rpe' field
    final legacyRpe = (json['rpe'] as num?)?.toDouble();
    final parsedStrengthRpe =
        (json['strengthRpe'] as num?)?.toDouble() ?? legacyRpe;
    final parsedLocalRpe = (json['localRpe'] as num?)?.toDouble();
    final parsedEffortRpe = (json['effortRpe'] as num?)?.toDouble();

    IntensityClass? parsedIntensity;
    final intensityName = json['intensityClass'] as String?;
    if (intensityName != null) {
      try {
        parsedIntensity = IntensityClass.values.byName(intensityName);
      } catch (_) {
        parsedIntensity = null;
      }
    }

    return LoggedSet._internal(
      exerciseId: json['exerciseId'] as String,
      weightKg: (json['weightKg'] as num).toDouble(),
      reps: json['reps'] as int,
      completedAt: DateTime.parse(json['completedAt'] as String),
      rpeEstimated: json['rpeEstimated'] as bool? ?? false,
      durationSeconds: json['durationSeconds'] as int? ?? 0,
      strengthRpe: parsedStrengthRpe,
      localRpe: parsedLocalRpe,
      effortRpe: parsedEffortRpe,
      intensityClass: parsedIntensity,
    );
  }
}
