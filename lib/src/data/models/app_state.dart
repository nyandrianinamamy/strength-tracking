import 'package:strength_training_tracker/src/core/utils/iterable_extensions.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_group.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';

class AppState {
  const AppState({
    required this.exercises,
    required this.routines,
    required this.sessions,
    this.routineGroups = const [],
    this.userName = '',
    this.preferredUnit = 'kg',
    this.sex = 'male',
    this.age,
    this.weight,
    this.fitnessGoal = '',
    this.preferredLanguage = '',
    this.preferredTheme = '',
    this.activeRoutineGroupId,
    this.healthKitEnabled = false,
  });

  final List<Exercise> exercises;
  final List<Routine> routines;
  final List<RoutineGroup> routineGroups;
  final List<WorkoutSession> sessions;
  final String userName;
  final String preferredUnit;
  final String sex;
  final int? age;
  final double? weight;
  final String fitnessGoal;
  final String preferredLanguage;
  final String preferredTheme;
  final String? activeRoutineGroupId;
  final bool healthKitEnabled;

  factory AppState.empty() {
    return const AppState(
      exercises: [],
      routines: [],
      routineGroups: [],
      sessions: [],
    );
  }

  AppState copyWith({
    List<Exercise>? exercises,
    List<Routine>? routines,
    List<RoutineGroup>? routineGroups,
    List<WorkoutSession>? sessions,
    String? userName,
    String? preferredUnit,
    String? sex,
    int? age,
    bool clearAge = false,
    double? weight,
    bool clearWeight = false,
    String? fitnessGoal,
    String? preferredLanguage,
    String? preferredTheme,
    String? activeRoutineGroupId,
    bool clearActiveRoutineGroupId = false,
    bool? healthKitEnabled,
  }) {
    return AppState(
      exercises: exercises ?? this.exercises,
      routines: routines ?? this.routines,
      routineGroups: routineGroups ?? this.routineGroups,
      sessions: sessions ?? this.sessions,
      userName: userName ?? this.userName,
      preferredUnit: preferredUnit ?? this.preferredUnit,
      sex: sex ?? this.sex,
      age: clearAge ? null : age ?? this.age,
      weight: clearWeight ? null : weight ?? this.weight,
      fitnessGoal: fitnessGoal ?? this.fitnessGoal,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      preferredTheme: preferredTheme ?? this.preferredTheme,
      activeRoutineGroupId: clearActiveRoutineGroupId
          ? null
          : activeRoutineGroupId ?? this.activeRoutineGroupId,
      healthKitEnabled: healthKitEnabled ?? this.healthKitEnabled,
    );
  }

  Exercise? exerciseById(String id) =>
      exercises.firstWhereOrNull((exercise) => exercise.id == id);

  Routine? routineById(String id) =>
      routines.firstWhereOrNull((routine) => routine.id == id);

  RoutineGroup? routineGroupById(String id) =>
      routineGroups.firstWhereOrNull((group) => group.id == id);

  WorkoutSession? sessionById(String id) =>
      sessions.firstWhereOrNull((session) => session.id == id);

  WorkoutSession? get activeSession => sessions.firstWhereOrNull(
    (session) => session.status == WorkoutSessionStatus.active,
  );

  RoutineGroup? get activeRoutineGroup {
    final activeRoutineGroupId = this.activeRoutineGroupId;
    if (activeRoutineGroupId == null) {
      return null;
    }
    return routineGroupById(activeRoutineGroupId);
  }

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
      routineGroups: (json['routineGroups'] as List<dynamic>? ?? const [])
          .map((item) => RoutineGroup.fromJson(item as Map<String, dynamic>))
          .toList(),
      sessions: (json['sessions'] as List<dynamic>? ?? const [])
          .map((item) => WorkoutSession.fromJson(item as Map<String, dynamic>))
          .toList(),
      userName: json['userName'] as String? ?? '',
      preferredUnit: json['preferredUnit'] as String? ?? 'kg',
      sex: json['sex'] as String? ?? json['bodyGender'] as String? ?? 'male',
      age: json['age'] as int?,
      weight: (json['weight'] as num?)?.toDouble(),
      fitnessGoal: json['fitnessGoal'] as String? ?? '',
      preferredLanguage: json['preferredLanguage'] as String? ?? '',
      preferredTheme: json['preferredTheme'] as String? ?? '',
      activeRoutineGroupId: json['activeRoutineGroupId'] as String?,
      healthKitEnabled: json['healthKitEnabled'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'exercises': exercises.map((item) => item.toJson()).toList(),
      'routines': routines.map((item) => item.toJson()).toList(),
      'routineGroups': routineGroups.map((item) => item.toJson()).toList(),
      'sessions': sessions.map((item) => item.toJson()).toList(),
      'userName': userName,
      'preferredUnit': preferredUnit,
      'sex': sex,
      'age': age,
      'weight': weight,
      'fitnessGoal': fitnessGoal,
      'preferredLanguage': preferredLanguage,
      'preferredTheme': preferredTheme,
      'activeRoutineGroupId': activeRoutineGroupId,
      'healthKitEnabled': healthKitEnabled,
    };
  }
}
