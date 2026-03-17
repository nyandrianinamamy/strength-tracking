import 'package:strength_training_tracker/src/core/utils/iterable_extensions.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

class AppState {
  const AppState({
    required this.exercises,
    required this.routines,
    required this.sessions,
  });

  final List<Exercise> exercises;
  final List<Routine> routines;
  final List<WorkoutSession> sessions;

  factory AppState.empty() {
    return const AppState(exercises: [], routines: [], sessions: []);
  }

  AppState copyWith({
    List<Exercise>? exercises,
    List<Routine>? routines,
    List<WorkoutSession>? sessions,
  }) {
    return AppState(
      exercises: exercises ?? this.exercises,
      routines: routines ?? this.routines,
      sessions: sessions ?? this.sessions,
    );
  }

  Exercise? exerciseById(String id) =>
      exercises.firstWhereOrNull((exercise) => exercise.id == id);

  Routine? routineById(String id) =>
      routines.firstWhereOrNull((routine) => routine.id == id);

  WorkoutSession? sessionById(String id) =>
      sessions.firstWhereOrNull((session) => session.id == id);

  WorkoutSession? get activeSession => sessions.firstWhereOrNull(
    (session) => session.status == WorkoutSessionStatus.active,
  );

  List<WorkoutSession> get completedSessions =>
      sessions
          .where((session) => session.status == WorkoutSessionStatus.completed)
          .toList()
        ..sort(
          (a, b) =>
              (b.endedAt ?? b.startedAt).compareTo(a.endedAt ?? a.startedAt),
        );

  factory AppState.fromJson(Map<String, dynamic> json) {
    return AppState(
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .map((item) => Exercise.fromJson(item as Map<String, dynamic>))
          .toList(),
      routines: (json['routines'] as List<dynamic>? ?? const [])
          .map((item) => Routine.fromJson(item as Map<String, dynamic>))
          .toList(),
      sessions: (json['sessions'] as List<dynamic>? ?? const [])
          .map((item) => WorkoutSession.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercises': exercises.map((item) => item.toJson()).toList(),
      'routines': routines.map((item) => item.toJson()).toList(),
      'sessions': sessions.map((item) => item.toJson()).toList(),
    };
  }
}
