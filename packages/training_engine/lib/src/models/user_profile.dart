import 'enums.dart';

class UserProfile {
  final Sex sex;
  final int age;
  final double bodyWeightKg;
  final ExperienceLevel experience;
  final HypertrophyGoal goal;
  final List<int> availableDays;
  final Duration maxSessionDuration;
  final DateTime createdAt;

  const UserProfile({
    required this.sex,
    required this.age,
    required this.bodyWeightKg,
    required this.experience,
    required this.goal,
    required this.availableDays,
    required this.maxSessionDuration,
    required this.createdAt,
  });

  UserProfile copyWith({
    Sex? sex,
    int? age,
    double? bodyWeightKg,
    ExperienceLevel? experience,
    HypertrophyGoal? goal,
    List<int>? availableDays,
    Duration? maxSessionDuration,
    DateTime? createdAt,
  }) =>
      UserProfile(
        sex: sex ?? this.sex,
        age: age ?? this.age,
        bodyWeightKg: bodyWeightKg ?? this.bodyWeightKg,
        experience: experience ?? this.experience,
        goal: goal ?? this.goal,
        availableDays: availableDays ?? this.availableDays,
        maxSessionDuration: maxSessionDuration ?? this.maxSessionDuration,
        createdAt: createdAt ?? this.createdAt,
      );

  Map<String, dynamic> toJson() => {
    'sex': sex.name,
    'age': age,
    'bodyWeightKg': bodyWeightKg,
    'experience': experience.name,
    'goal': goal.name,
    'availableDays': availableDays,
    'maxSessionDurationMinutes': maxSessionDuration.inMinutes,
    'createdAt': createdAt.toIso8601String(),
  };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    sex: Sex.values.byName(json['sex'] as String),
    age: json['age'] as int,
    bodyWeightKg: (json['bodyWeightKg'] as num).toDouble(),
    experience: ExperienceLevel.values.byName(json['experience'] as String),
    goal: HypertrophyGoal.values.byName(json['goal'] as String),
    availableDays: List<int>.from(json['availableDays'] as List),
    maxSessionDuration: Duration(
      minutes: json['maxSessionDurationMinutes'] as int,
    ),
    createdAt: DateTime.parse(json['createdAt'] as String),
  );
}
