import 'package:strength_training_tracker/src/data/models/completed_set.dart';

enum WorkoutSessionStatus { active, completed, discarded }

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.routineId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.currentExerciseIndex,
    required this.completedSets,
    required this.sessionNote,
    required this.rpe,
  });

  final String id;
  final String routineId;
  final WorkoutSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final int currentExerciseIndex;
  final List<CompletedSet> completedSets;
  final String sessionNote;
  final double? rpe;

  WorkoutSession copyWith({
    String? id,
    String? routineId,
    WorkoutSessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    int? currentExerciseIndex,
    List<CompletedSet>? completedSets,
    String? sessionNote,
    double? rpe,
    bool clearEndedAt = false,
    bool clearRpe = false,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      completedSets: completedSets ?? this.completedSets,
      sessionNote: sessionNote ?? this.sessionNote,
      rpe: clearRpe ? null : rpe ?? this.rpe,
    );
  }

  factory WorkoutSession.fromJson(Map<String, dynamic> json) {
    return WorkoutSession(
      id: json['id'] as String,
      routineId: json['routineId'] as String,
      status: WorkoutSessionStatus.values.byName(json['status'] as String),
      startedAt: DateTime.parse(json['startedAt'] as String),
      endedAt: json['endedAt'] == null
          ? null
          : DateTime.parse(json['endedAt'] as String),
      currentExerciseIndex: json['currentExerciseIndex'] as int? ?? 0,
      completedSets: (json['completedSets'] as List<dynamic>? ?? const [])
          .map((item) => CompletedSet.fromJson(item as Map<String, dynamic>))
          .toList(),
      sessionNote: json['sessionNote'] as String? ?? '',
      rpe: (json['rpe'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routineId': routineId,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'currentExerciseIndex': currentExerciseIndex,
      'completedSets': completedSets.map((item) => item.toJson()).toList(),
      'sessionNote': sessionNote,
      'rpe': rpe,
    };
  }
}
