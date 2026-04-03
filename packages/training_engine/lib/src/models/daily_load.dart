class DailyLoad {
  final DateTime date;
  final double volumeLoad;
  final double? sRpeLoad;

  const DailyLoad({
    required this.date,
    required this.volumeLoad,
    this.sRpeLoad,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'volumeLoad': volumeLoad,
    'sRpeLoad': sRpeLoad,
  };

  factory DailyLoad.fromJson(Map<String, dynamic> json) => DailyLoad(
    date: DateTime.parse(json['date'] as String),
    volumeLoad: (json['volumeLoad'] as num).toDouble(),
    sRpeLoad: (json['sRpeLoad'] as num?)?.toDouble(),
  );
}
