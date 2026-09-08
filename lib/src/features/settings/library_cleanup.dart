import '../../data/models/app_state.dart';

/// Hide the library without destroying sessions or the definitions needed to
/// display their names, prescriptions, sets and active-workout state.
AppState clearLibraryPreservingHistory(AppState state) {
  final routineIds = state.sessions.map((session) => session.routineId).toSet();
  final retainedRoutines = state.routines.where(
    (routine) => routineIds.contains(routine.id),
  );
  final exerciseIds = {
    for (final routine in retainedRoutines)
      for (final exercise in routine.exercises) exercise.exerciseId,
    for (final session in state.sessions)
      for (final set in session.completedSets) set.exerciseId,
  };
  return state.copyWith(
    routines: retainedRoutines
        .map((routine) => routine.copyWith(archived: true))
        .toList(),
    exercises: state.exercises
        .where((exercise) => exerciseIds.contains(exercise.id))
        .map((exercise) => exercise.copyWith(archived: true))
        .toList(),
    routineGroups: [],
    clearActiveRoutineGroupId: true,
  );
}
