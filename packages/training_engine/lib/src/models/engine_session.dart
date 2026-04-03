import 'logged_set.dart';

class EngineSession {
  final String id;
  final DateTime startedAt;
  final DateTime endedAt;
  final List<LoggedSet> sets;
  final double? sessionRpe;

  const EngineSession({
    required this.id,
    required this.startedAt,
    required this.endedAt,
    required this.sets,
    this.sessionRpe,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'startedAt': startedAt.toIso8601String(),
    'endedAt': endedAt.toIso8601String(),
    'sets': sets.map((s) => s.toJson()).toList(),
    if (sessionRpe != null) 'sessionRpe': sessionRpe,
  };

  factory EngineSession.fromJson(Map<String, dynamic> json) => EngineSession(
    id: json['id'] as String,
    startedAt: DateTime.parse(json['startedAt'] as String),
    endedAt: DateTime.parse(json['endedAt'] as String),
    sets: (json['sets'] as List)
        .map((s) => LoggedSet.fromJson(s as Map<String, dynamic>))
        .toList(),
    sessionRpe: (json['sessionRpe'] as num?)?.toDouble(),
  );
}
