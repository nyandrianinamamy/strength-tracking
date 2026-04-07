class RestTimerNotificationService {
  Future<void> primePermission() async {}

  void scheduleRestEnd({
    required Duration duration,
    required String exerciseName,
    required String notificationTitle,
    required String notificationBody,
  }) {}

  void cancel() {}
}
