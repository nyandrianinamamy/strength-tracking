import 'package:training_engine/training_engine.dart';

/// Stub implementation of a HealthKit data source.
///
/// Returns empty collections until a real HealthKit integration is wired up.
/// Replace the method bodies with actual `health` package calls when ready.
class HealthKitDataSource {
  const HealthKitDataSource();

  /// Requests HealthKit authorisation for sleep and HRV data.
  ///
  /// Returns `false` until the integration is implemented.
  Future<bool> requestAuthorization() async => false;

  /// Fetches recent sleep records from HealthKit.
  ///
  /// Returns an empty list until the integration is implemented.
  Future<List<SleepRecord>> fetchRecentSleep({int days = 14}) async => [];

  /// Fetches recent HRV records from HealthKit.
  ///
  /// Returns an empty list until the integration is implemented.
  Future<List<HrvRecord>> fetchRecentHrv({int days = 14}) async => [];
}
