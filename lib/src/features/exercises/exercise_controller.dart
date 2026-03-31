import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';

final exerciseControllerProvider = Provider<ExerciseController>(
  ExerciseController.new,
);

class ExerciseController {
  ExerciseController(this._ref);

  final Ref _ref;

  List<Exercise> search(String query) {
    final normalized = query.trim().toLowerCase();
    final exercises = _ref.read(appStateControllerProvider).exercises;

    return exercises.where((exercise) {
      if (exercise.archived) {
        return false;
      }

      if (normalized.isEmpty) {
        return true;
      }

      return exercise.name.toLowerCase().contains(normalized) ||
          exercise.primaryMuscles.any(
            (muscle) => muscle.toLowerCase().contains(normalized),
          ) ||
          exercise.secondaryMuscles.any(
            (muscle) => muscle.toLowerCase().contains(normalized),
          );
    }).toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  Exercise create({
    required String name,
    required List<String> primaryMuscles,
    List<String> secondaryMuscles = const [],
    required List<String> equipment,
    required String instructions,
    String exerciseType = 'strength',
    String? photoBase64,
  }) {
    final exercise = Exercise(
      id: 'exercise_${DateTime.now().microsecondsSinceEpoch}',
      name: name.trim(),
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
      equipment: equipment,
      instructions: instructions.trim(),
      archived: false,
      exerciseType: exerciseType,
      photoBase64: photoBase64,
    );

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (state) => state.copyWith(exercises: [...state.exercises, exercise]),
        );

    return exercise;
  }

  Exercise update({
    required String exerciseId,
    required String name,
    required List<String> primaryMuscles,
    List<String> secondaryMuscles = const [],
    required List<String> equipment,
    required String instructions,
    String exerciseType = 'strength',
    String? photoBase64,
    bool clearPhoto = false,
  }) {
    final state = _ref.read(appStateControllerProvider);
    final exercise = state.exerciseById(exerciseId)!;
    final updated = exercise.copyWith(
      name: name.trim(),
      primaryMuscles: primaryMuscles,
      secondaryMuscles: secondaryMuscles,
      equipment: equipment,
      instructions: instructions.trim(),
      exerciseType: exerciseType,
      photoBase64: photoBase64,
      clearPhoto: clearPhoto,
    );

    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (currentState) => currentState.copyWith(
            exercises: currentState.exercises
                .map((item) => item.id == exerciseId ? updated : item)
                .toList(),
          ),
        );

    return updated;
  }

  void archive(String exerciseId) {
    _ref
        .read(appStateControllerProvider.notifier)
        .updateState(
          (state) => state.copyWith(
            exercises: state.exercises
                .map(
                  (exercise) => exercise.id == exerciseId
                      ? exercise.copyWith(archived: true)
                      : exercise,
                )
                .toList(),
          ),
        );
  }
}
