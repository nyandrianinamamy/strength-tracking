import 'package:flutter/foundation.dart';
import 'package:health/health.dart';
import 'package:training_engine/training_engine.dart';

enum HealthKitFetchStatus { success, noSamples, unavailable, denied, error }

class HealthKitFetchResult<T> {
  const HealthKitFetchResult({required this.status, required this.records});

  final HealthKitFetchStatus status;
  final List<T> records;

  bool get shouldStampFetch => true;
}

/// Reads sleep and HRV data from Apple HealthKit via the `health` package.
///
/// Returns explicit fetch statuses so callers can distinguish unavailable
/// platforms, denied authorization, empty HealthKit stores, and fetch errors.
class HealthKitDataSource {
  const HealthKitDataSource();

  static final _health = Health();

  /// Returns `true` only on iOS — HealthKit is not available elsewhere.
  static bool get _isAvailable => defaultTargetPlatform == TargetPlatform.iOS;

  static const _readTypes = [
    HealthDataType.SLEEP_ASLEEP,
    HealthDataType.SLEEP_IN_BED,
    HealthDataType.SLEEP_DEEP,
    HealthDataType.SLEEP_REM,
    HealthDataType.SLEEP_LIGHT,
    HealthDataType.HEART_RATE_VARIABILITY_SDNN,
    HealthDataType.RESTING_HEART_RATE,
  ];

  /// Requests read-only HealthKit authorization for sleep and HRV data.
  ///
  /// Returns `true` if the user granted (or had previously granted) access.
  /// Returns `false` on denial, or when HealthKit is unavailable.
  Future<bool> requestAuthorization() async {
    if (!_isAvailable) return false;
    try {
      return await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
    } catch (e) {
      debugPrint('[HealthKit] Authorization failed: $e');
      return false;
    }
  }

  Future<HealthKitFetchStatus> _requestAuthorizationStatus() async {
    if (!_isAvailable) return HealthKitFetchStatus.unavailable;
    try {
      final authorized = await _health.requestAuthorization(
        _readTypes,
        permissions: _readTypes.map((_) => HealthDataAccess.READ).toList(),
      );
      return authorized
          ? HealthKitFetchStatus.success
          : HealthKitFetchStatus.denied;
    } catch (e) {
      debugPrint('[HealthKit] Authorization failed: $e');
      return HealthKitFetchStatus.error;
    }
  }

  /// Fetches recent sleep records from HealthKit, grouped by calendar night.
  ///
  /// Each returned [SleepRecord] represents one night of sleep, with
  /// total / deep / REM / core (light) breakdowns aggregated from individual
  /// HealthKit sleep samples.
  Future<List<SleepRecord>> fetchRecentSleep({int days = 14}) async {
    final result = await fetchRecentSleepResult(days: days);
    return result.records;
  }

  Future<HealthKitFetchResult<SleepRecord>> fetchRecentSleepResult({
    int days = 14,
  }) async {
    try {
      final authorizationStatus = await _requestAuthorizationStatus();
      if (authorizationStatus != HealthKitFetchStatus.success) {
        return HealthKitFetchResult(
          status: authorizationStatus,
          records: const [],
        );
      }

      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));

      final samples = await _health.getHealthDataFromTypes(
        types: [
          HealthDataType.SLEEP_ASLEEP,
          HealthDataType.SLEEP_IN_BED,
          HealthDataType.SLEEP_DEEP,
          HealthDataType.SLEEP_REM,
          HealthDataType.SLEEP_LIGHT,
        ],
        startTime: start,
        endTime: now,
      );

      if (samples.isEmpty) {
        return const HealthKitFetchResult(
          status: HealthKitFetchStatus.noSamples,
          records: [],
        );
      }

      final records = sleepRecordsFromSamples(samples);
      return HealthKitFetchResult(
        status: records.isEmpty
            ? HealthKitFetchStatus.noSamples
            : HealthKitFetchStatus.success,
        records: records,
      );
    } catch (e) {
      debugPrint('[HealthKit] fetchRecentSleep failed: $e');
      return const HealthKitFetchResult(
        status: HealthKitFetchStatus.error,
        records: [],
      );
    }
  }

  /// Fetches recent HRV (SDNN) and resting heart rate records from HealthKit.
  ///
  /// Returns one [HrvRecord] per calendar day, using the latest SDNN sample
  /// for that day and the corresponding resting heart rate (if available).
  Future<List<HrvRecord>> fetchRecentHrv({int days = 14}) async {
    final result = await fetchRecentHrvResult(days: days);
    return result.records;
  }

  Future<HealthKitFetchResult<HrvRecord>> fetchRecentHrvResult({
    int days = 14,
  }) async {
    try {
      final authorizationStatus = await _requestAuthorizationStatus();
      if (authorizationStatus != HealthKitFetchStatus.success) {
        return HealthKitFetchResult(
          status: authorizationStatus,
          records: const [],
        );
      }

      final now = DateTime.now();
      final start = now.subtract(Duration(days: days));

      final hrvSamples = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE_VARIABILITY_SDNN],
        startTime: start,
        endTime: now,
      );

      final rhrSamples = await _health.getHealthDataFromTypes(
        types: [HealthDataType.RESTING_HEART_RATE],
        startTime: start,
        endTime: now,
      );

      if (hrvSamples.isEmpty) {
        return const HealthKitFetchResult(
          status: HealthKitFetchStatus.noSamples,
          records: [],
        );
      }

      // Index resting HR by date for quick lookup.
      final rhrByDate = <DateTime, double>{};
      for (final sample in rhrSamples) {
        final date = _dateOnly(sample.dateFrom);
        final value = _numericValue(sample);
        if (value != null) {
          rhrByDate[date] = value;
        }
      }

      // Group HRV by date, keeping the latest sample per day.
      final hrvByDate = <DateTime, HealthDataPoint>{};
      for (final sample in hrvSamples) {
        final date = _dateOnly(sample.dateFrom);
        final existing = hrvByDate[date];
        if (existing == null || sample.dateFrom.isAfter(existing.dateFrom)) {
          hrvByDate[date] = sample;
        }
      }

      final records =
          hrvByDate.entries
              .map((entry) {
                final sdnn = _numericValue(entry.value);
                if (sdnn == null) return null;
                return HrvRecord(
                  date: entry.key,
                  sdnn: sdnn,
                  restingHeartRate: rhrByDate[entry.key],
                );
              })
              .whereType<HrvRecord>()
              .toList()
            ..sort((a, b) => a.date.compareTo(b.date));
      return HealthKitFetchResult(
        status: records.isEmpty
            ? HealthKitFetchStatus.noSamples
            : HealthKitFetchStatus.success,
        records: records,
      );
    } catch (e) {
      debugPrint('[HealthKit] fetchRecentHrv failed: $e');
      return const HealthKitFetchResult(
        status: HealthKitFetchStatus.error,
        records: [],
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Private helpers
  // ---------------------------------------------------------------------------

  /// Determines which "night" a sleep sample belongs to.
  /// Anything before 18:00 is attributed to the previous calendar day.
  static DateTime _nightOf(DateTime timestamp) {
    if (timestamp.hour < 18) {
      final prev = timestamp.subtract(const Duration(days: 1));
      return DateTime(prev.year, prev.month, prev.day);
    }
    return DateTime(timestamp.year, timestamp.month, timestamp.day);
  }

  static DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

  static double? _numericValue(HealthDataPoint point) {
    final value = point.value;
    if (value is NumericHealthValue) {
      return value.numericValue.toDouble();
    }
    return null;
  }

  @visibleForTesting
  static List<SleepRecord> sleepRecordsFromSamples(
    List<HealthDataPoint> samples,
  ) {
    // Group samples by the night they belong to.
    // A sleep sample's "night" is the date of the start time,
    // shifted so anything before 6 PM counts as the previous night.
    final byNight = <DateTime, _SleepAccumulator>{};

    for (final sample in samples) {
      final nightDate = _nightOf(sample.dateFrom);
      final acc = byNight.putIfAbsent(nightDate, _SleepAccumulator.new);
      final duration = sample.dateTo.difference(sample.dateFrom);

      switch (sample.type) {
        case HealthDataType.SLEEP_DEEP:
          acc.deep += duration;
          acc.total += duration;
        case HealthDataType.SLEEP_REM:
          acc.rem += duration;
          acc.total += duration;
        case HealthDataType.SLEEP_LIGHT:
          acc.core += duration;
          acc.total += duration;
        case HealthDataType.SLEEP_ASLEEP:
          // Generic "asleep" — only count if no typed breakdown exists.
          acc.genericAsleep += duration;
        case HealthDataType.SLEEP_IN_BED:
          // Some devices/sources provide only in-bed sleep analysis. Use it
          // as a last-resort duration so permissioned HealthKit does not look
          // empty when no staged or generic asleep samples exist.
          acc.inBed += duration;
        default:
          break;
      }
    }

    final records =
        byNight.entries
            .map((entry) {
              final acc = entry.value;
              // Prefer typed stage totals, then generic asleep, then in-bed fallback.
              final total = acc.total > Duration.zero
                  ? acc.total
                  : acc.genericAsleep > Duration.zero
                  ? acc.genericAsleep
                  : acc.inBed;
              return SleepRecord(
                date: entry.key,
                totalSleep: total,
                deepSleep: acc.deep,
                remSleep: acc.rem,
                coreSleep: acc.core,
              );
            })
            .where((record) => record.totalSleep > Duration.zero)
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));
    return records;
  }
}

/// Accumulates sleep durations across multiple samples for one night.
class _SleepAccumulator {
  Duration total = Duration.zero;
  Duration deep = Duration.zero;
  Duration rem = Duration.zero;
  Duration core = Duration.zero;
  Duration genericAsleep = Duration.zero;
  Duration inBed = Duration.zero;
}
