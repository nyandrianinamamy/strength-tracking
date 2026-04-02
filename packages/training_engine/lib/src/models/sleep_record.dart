class SleepRecord {
  final DateTime date;
  final Duration totalSleep;
  final Duration deepSleep;
  final Duration remSleep;
  final Duration coreSleep;

  const SleepRecord({
    required this.date,
    required this.totalSleep,
    required this.deepSleep,
    required this.remSleep,
    required this.coreSleep,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'totalSleepMinutes': totalSleep.inMinutes,
    'deepSleepMinutes': deepSleep.inMinutes,
    'remSleepMinutes': remSleep.inMinutes,
    'coreSleepMinutes': coreSleep.inMinutes,
  };

  factory SleepRecord.fromJson(Map<String, dynamic> json) => SleepRecord(
    date: DateTime.parse(json['date'] as String),
    totalSleep: Duration(minutes: json['totalSleepMinutes'] as int),
    deepSleep: Duration(minutes: json['deepSleepMinutes'] as int),
    remSleep: Duration(minutes: json['remSleepMinutes'] as int),
    coreSleep: Duration(minutes: json['coreSleepMinutes'] as int),
  );
}
