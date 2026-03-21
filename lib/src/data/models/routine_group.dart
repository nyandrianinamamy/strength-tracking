class RoutineGroup {
  const RoutineGroup({
    required this.id,
    required this.name,
    required this.routineIds,
    this.pendingRoutineIds = const [],
  });

  final String id;
  final String name;
  final List<String> routineIds;
  final List<String> pendingRoutineIds;

  RoutineGroup copyWith({
    String? id,
    String? name,
    List<String>? routineIds,
    List<String>? pendingRoutineIds,
  }) {
    return RoutineGroup(
      id: id ?? this.id,
      name: name ?? this.name,
      routineIds: routineIds ?? this.routineIds,
      pendingRoutineIds: pendingRoutineIds ?? this.pendingRoutineIds,
    );
  }

  factory RoutineGroup.fromJson(Map<String, dynamic> json) {
    final routineIds = (json['routineIds'] as List<dynamic>? ?? const [])
        .map((item) => item as String)
        .toList();
    final pendingRoutineIds =
        (json['pendingRoutineIds'] as List<dynamic>? ??
                json['skippedRoutineIds'] as List<dynamic>? ??
                routineIds)
            .map((item) => item as String)
            .toList();

    return RoutineGroup(
      id: json['id'] as String,
      name: json['name'] as String,
      routineIds: routineIds,
      pendingRoutineIds: pendingRoutineIds,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'routineIds': routineIds,
      'pendingRoutineIds': pendingRoutineIds,
    };
  }
}
