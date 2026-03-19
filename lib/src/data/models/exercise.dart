class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.primaryMuscles,
    this.secondaryMuscles = const [],
    required this.equipment,
    required this.instructions,
    required this.archived,
    this.exerciseType = 'strength',
  });

  final String id;
  final String name;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> equipment;
  final String instructions;
  final bool archived;
  final String exerciseType;

  Exercise copyWith({
    String? id,
    String? name,
    List<String>? primaryMuscles,
    List<String>? secondaryMuscles,
    List<String>? equipment,
    String? instructions,
    bool? archived,
    String? exerciseType,
  }) {
    return Exercise(
      id: id ?? this.id,
      name: name ?? this.name,
      primaryMuscles: primaryMuscles ?? this.primaryMuscles,
      secondaryMuscles: secondaryMuscles ?? this.secondaryMuscles,
      equipment: equipment ?? this.equipment,
      instructions: instructions ?? this.instructions,
      archived: archived ?? this.archived,
      exerciseType: exerciseType ?? this.exerciseType,
    );
  }

  factory Exercise.fromJson(Map<String, dynamic> json) {
    return Exercise(
      id: json['id'] as String,
      name: json['name'] as String,
      primaryMuscles: List<String>.from(
        json['primaryMuscles'] as List<dynamic>? ?? const [],
      ),
      secondaryMuscles: List<String>.from(
        json['secondaryMuscles'] as List<dynamic>? ?? const [],
      ),
      equipment: List<String>.from(
        json['equipment'] as List<dynamic>? ?? const [],
      ),
      instructions: json['instructions'] as String? ?? '',
      archived: json['archived'] as bool? ?? false,
      exerciseType: json['exerciseType'] as String? ?? 'strength',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'primaryMuscles': primaryMuscles,
      'secondaryMuscles': secondaryMuscles,
      'equipment': equipment,
      'instructions': instructions,
      'archived': archived,
      'exerciseType': exerciseType,
    };
  }
}
