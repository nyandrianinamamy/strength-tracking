import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';

class Routine {
  const Routine({
    required this.id,
    required this.name,
    required this.category,
    required this.exercises,
    required this.estimatedDurationMin,
    required this.archived,
  });

  final String id;
  final String name;
  final String category;
  final List<RoutineExercise> exercises;
  final int estimatedDurationMin;
  final bool archived;

  Routine copyWith({
    String? id,
    String? name,
    String? category,
    List<RoutineExercise>? exercises,
    int? estimatedDurationMin,
    bool? archived,
  }) {
    return Routine(
      id: id ?? this.id,
      name: name ?? this.name,
      category: category ?? this.category,
      exercises: exercises ?? this.exercises,
      estimatedDurationMin: estimatedDurationMin ?? this.estimatedDurationMin,
      archived: archived ?? this.archived,
    );
  }

  factory Routine.fromJson(Map<String, dynamic> json) {
    return Routine(
      id: json['id'] as String,
      name: json['name'] as String,
      category: json['category'] as String,
      estimatedDurationMin: json['estimatedDurationMin'] as int,
      archived: json['archived'] as bool? ?? false,
      exercises: (json['exercises'] as List<dynamic>? ?? const [])
          .map((item) => RoutineExercise.fromJson(item as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'estimatedDurationMin': estimatedDurationMin,
      'archived': archived,
      'exercises': exercises.map((item) => item.toJson()).toList(),
    };
  }
}
