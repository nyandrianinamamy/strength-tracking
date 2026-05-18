import 'package:strength_training_tracker/src/data/models/completed_set.dart';

enum WorkoutSessionStatus { active, completed, discarded }

class TimedExerciseTimerState {
  const TimedExerciseTimerState({
    required this.exerciseId,
    required this.remainingSeconds,
    required this.endsAt,
    this.beeped = false,
  });

  final String exerciseId;
  final int remainingSeconds;
  final DateTime? endsAt;
  final bool beeped;

  bool get isRunning => endsAt != null;

  int remainingAt(DateTime now) {
    final end = endsAt;
    if (end == null) {
      return remainingSeconds.clamp(0, 9999);
    }
    return end.difference(now).inSeconds.clamp(0, 9999);
  }

  TimedExerciseTimerState copyWith({
    String? exerciseId,
    int? remainingSeconds,
    DateTime? endsAt,
    bool clearEndsAt = false,
    bool? beeped,
  }) {
    return TimedExerciseTimerState(
      exerciseId: exerciseId ?? this.exerciseId,
      remainingSeconds: remainingSeconds ?? this.remainingSeconds,
      endsAt: clearEndsAt ? null : endsAt ?? this.endsAt,
      beeped: beeped ?? this.beeped,
    );
  }

  factory TimedExerciseTimerState.fromJson(Map<String, dynamic> json) {
    return TimedExerciseTimerState(
      exerciseId: json['exerciseId'] as String,
      remainingSeconds: json['remainingSeconds'] as int? ?? 0,
      endsAt: json['endsAt'] == null
          ? null
          : DateTime.parse(json['endsAt'] as String),
      beeped: json['beeped'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exerciseId': exerciseId,
      'remainingSeconds': remainingSeconds,
      'endsAt': endsAt?.toIso8601String(),
      'beeped': beeped,
    };
  }
}

class WorkoutSession {
  const WorkoutSession({
    required this.id,
    required this.routineId,
    required this.status,
    required this.startedAt,
    required this.endedAt,
    required this.lastActivityAt,
    required this.currentExerciseIndex,
    required this.completedSets,
    required this.sessionNote,
    required this.rpe,
    this.timedExerciseTimers = const {},
  });

  final String id;
  final String routineId;
  final WorkoutSessionStatus status;
  final DateTime startedAt;
  final DateTime? endedAt;
  final DateTime? lastActivityAt;
  final int currentExerciseIndex;
  final List<CompletedSet> completedSets;
  final String sessionNote;
  final double? rpe;
  final Map<String, TimedExerciseTimerState> timedExerciseTimers;

  WorkoutSession copyWith({
    String? id,
    String? routineId,
    WorkoutSessionStatus? status,
    DateTime? startedAt,
    DateTime? endedAt,
    DateTime? lastActivityAt,
    int? currentExerciseIndex,
    List<CompletedSet>? completedSets,
    String? sessionNote,
    double? rpe,
    Map<String, TimedExerciseTimerState>? timedExerciseTimers,
    bool clearEndedAt = false,
    bool clearRpe = false,
  }) {
    return WorkoutSession(
      id: id ?? this.id,
      routineId: routineId ?? this.routineId,
      status: status ?? this.status,
      startedAt: startedAt ?? this.startedAt,
      endedAt: clearEndedAt ? null : endedAt ?? this.endedAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      currentExerciseIndex: currentExerciseIndex ?? this.currentExerciseIndex,
      completedSets: completedSets ?? this.completedSets,
      sessionNote: sessionNote ?? this.sessionNote,
      rpe: clearRpe ? null : rpe ?? this.rpe,
      timedExerciseTimers: timedExerciseTimers ?? this.timedExerciseTimers,
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
      lastActivityAt: json['lastActivityAt'] == null
          ? null
          : DateTime.parse(json['lastActivityAt'] as String),
      currentExerciseIndex: json['currentExerciseIndex'] as int? ?? 0,
      completedSets: (json['completedSets'] as List<dynamic>? ?? const [])
          .map((item) => CompletedSet.fromJson(item as Map<String, dynamic>))
          .toList(),
      sessionNote: json['sessionNote'] as String? ?? '',
      rpe: (json['rpe'] as num?)?.toDouble(),
      timedExerciseTimers:
          (json['timedExerciseTimers'] as Map<String, dynamic>? ?? const {})
              .map(
                (key, value) => MapEntry(
                  key,
                  TimedExerciseTimerState.fromJson(
                    value as Map<String, dynamic>,
                  ),
                ),
              ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'routineId': routineId,
      'status': status.name,
      'startedAt': startedAt.toIso8601String(),
      'endedAt': endedAt?.toIso8601String(),
      'lastActivityAt': lastActivityAt?.toIso8601String(),
      'currentExerciseIndex': currentExerciseIndex,
      'completedSets': completedSets.map((item) => item.toJson()).toList(),
      'sessionNote': sessionNote,
      'rpe': rpe,
      'timedExerciseTimers': timedExerciseTimers.map(
        (key, value) => MapEntry(key, value.toJson()),
      ),
    };
  }
}
