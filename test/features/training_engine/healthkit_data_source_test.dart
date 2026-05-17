import 'package:flutter_test/flutter_test.dart';
import 'package:health/health.dart';
import 'package:strength_training_tracker/src/features/training_engine/healthkit_data_source.dart';

void main() {
  group('HealthKitDataSource.sleepRecordsFromSamples', () {
    test('uses in-bed samples when no asleep or staged samples exist', () {
      final samples = [
        _sleepPoint(
          type: HealthDataType.SLEEP_IN_BED,
          from: DateTime(2026, 5, 16, 23),
          to: DateTime(2026, 5, 17, 7, 30),
        ),
      ];

      final records = HealthKitDataSource.sleepRecordsFromSamples(samples);

      expect(records, hasLength(1));
      expect(records.single.date, DateTime(2026, 5, 16));
      expect(records.single.totalSleep, const Duration(hours: 8, minutes: 30));
      expect(records.single.deepSleep, Duration.zero);
      expect(records.single.remSleep, Duration.zero);
      expect(records.single.coreSleep, Duration.zero);
    });

    test(
      'prefers staged sleep over in-bed samples to avoid double counting',
      () {
        final samples = [
          _sleepPoint(
            type: HealthDataType.SLEEP_IN_BED,
            from: DateTime(2026, 5, 16, 22),
            to: DateTime(2026, 5, 17, 7),
          ),
          _sleepPoint(
            type: HealthDataType.SLEEP_LIGHT,
            from: DateTime(2026, 5, 16, 23),
            to: DateTime(2026, 5, 17, 3),
          ),
          _sleepPoint(
            type: HealthDataType.SLEEP_DEEP,
            from: DateTime(2026, 5, 17, 3),
            to: DateTime(2026, 5, 17, 4, 30),
          ),
          _sleepPoint(
            type: HealthDataType.SLEEP_REM,
            from: DateTime(2026, 5, 17, 4, 30),
            to: DateTime(2026, 5, 17, 6),
          ),
        ];

        final records = HealthKitDataSource.sleepRecordsFromSamples(samples);

        expect(records, hasLength(1));
        expect(records.single.totalSleep, const Duration(hours: 7));
        expect(records.single.coreSleep, const Duration(hours: 4));
        expect(records.single.deepSleep, const Duration(hours: 1, minutes: 30));
        expect(records.single.remSleep, const Duration(hours: 1, minutes: 30));
      },
    );
  });
}

HealthDataPoint _sleepPoint({
  required HealthDataType type,
  required DateTime from,
  required DateTime to,
}) {
  return HealthDataPoint(
    uuid: '${type.name}-$from',
    value: NumericHealthValue(numericValue: 0),
    type: type,
    unit: HealthDataUnit.MINUTE,
    dateFrom: from,
    dateTo: to,
    sourcePlatform: HealthPlatformType.appleHealth,
    sourceDeviceId: 'test-device',
    sourceId: 'test-source',
    sourceName: 'Test Source',
  );
}
