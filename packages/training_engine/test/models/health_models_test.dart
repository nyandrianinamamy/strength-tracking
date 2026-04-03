import 'package:test/test.dart';
import 'package:training_engine/training_engine.dart';

void main() {
  group('SleepRecord', () {
    final date = DateTime(2026, 1, 15);

    test('constructs correctly', () {
      final record = SleepRecord(
        date: date,
        totalSleep: const Duration(hours: 7, minutes: 30),
        deepSleep: const Duration(hours: 1, minutes: 30),
        remSleep: const Duration(hours: 2),
        coreSleep: const Duration(hours: 4),
      );
      expect(record.date, date);
      expect(record.totalSleep, const Duration(hours: 7, minutes: 30));
      expect(record.deepSleep, const Duration(hours: 1, minutes: 30));
      expect(record.remSleep, const Duration(hours: 2));
      expect(record.coreSleep, const Duration(hours: 4));
    });

    test('JSON roundtrip stores durations as minutes', () {
      final record = SleepRecord(
        date: date,
        totalSleep: const Duration(hours: 7, minutes: 30),
        deepSleep: const Duration(hours: 1, minutes: 30),
        remSleep: const Duration(hours: 2),
        coreSleep: const Duration(hours: 4),
      );
      final json = record.toJson();
      expect(json['totalSleepMinutes'], 450);
      expect(json['deepSleepMinutes'], 90);
      expect(json['remSleepMinutes'], 120);
      expect(json['coreSleepMinutes'], 240);

      final restored = SleepRecord.fromJson(json);
      expect(restored.date, record.date);
      expect(restored.totalSleep, record.totalSleep);
      expect(restored.deepSleep, record.deepSleep);
      expect(restored.remSleep, record.remSleep);
      expect(restored.coreSleep, record.coreSleep);
    });
  });

  group('HrvRecord', () {
    final date = DateTime(2026, 1, 15);

    test('constructs with SDNN and optional RHR', () {
      final record = HrvRecord(
        date: date,
        sdnn: 65.0,
        restingHeartRate: 55.0,
      );
      expect(record.date, date);
      expect(record.sdnn, 65.0);
      expect(record.restingHeartRate, 55.0);
    });

    test('restingHeartRate is nullable', () {
      final record = HrvRecord(
        date: date,
        sdnn: 60.0,
        restingHeartRate: null,
      );
      expect(record.restingHeartRate, isNull);
    });

    test('JSON roundtrip with RHR', () {
      final record = HrvRecord(
        date: date,
        sdnn: 65.0,
        restingHeartRate: 55.0,
      );
      final json = record.toJson();
      final restored = HrvRecord.fromJson(json);
      expect(restored.date, record.date);
      expect(restored.sdnn, record.sdnn);
      expect(restored.restingHeartRate, record.restingHeartRate);
    });

    test('JSON roundtrip without RHR', () {
      final record = HrvRecord(
        date: date,
        sdnn: 60.0,
        restingHeartRate: null,
      );
      final json = record.toJson();
      final restored = HrvRecord.fromJson(json);
      expect(restored.restingHeartRate, isNull);
    });
  });
}
