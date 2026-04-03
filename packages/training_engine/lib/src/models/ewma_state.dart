class EwmaState {
  final double acuteEwma;
  final double chronicEwma;
  final DateTime lastComputedDate;

  const EwmaState({
    required this.acuteEwma,
    required this.chronicEwma,
    required this.lastComputedDate,
  });

  Map<String, dynamic> toJson() => {
    'acuteEwma': acuteEwma,
    'chronicEwma': chronicEwma,
    'lastComputedDate': lastComputedDate.toIso8601String(),
  };

  factory EwmaState.fromJson(Map<String, dynamic> json) => EwmaState(
    acuteEwma: (json['acuteEwma'] as num).toDouble(),
    chronicEwma: (json['chronicEwma'] as num).toDouble(),
    lastComputedDate: DateTime.parse(json['lastComputedDate'] as String),
  );
}
