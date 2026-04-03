import 'package:test/test.dart';
import 'package:training_engine/src/readiness/sleep_scorer.dart';
import 'package:training_engine/src/readiness/hrv_scorer.dart';
import 'package:training_engine/src/readiness/composite_readiness.dart';
import 'package:training_engine/src/acwr/acwr_classifier.dart';
import 'package:training_engine/src/models/sleep_record.dart';
import 'package:training_engine/src/models/hrv_record.dart';
import 'package:training_engine/src/models/enums.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

SleepRecord _sleep(
  DateTime date, {
  int totalH = 8,
  int totalM = 0,
  int deepM = 90,
  int remM = 100,
  int coreM = 200,
}) {
  return SleepRecord(
    date: date,
    totalSleep: Duration(hours: totalH, minutes: totalM),
    deepSleep: Duration(minutes: deepM),
    remSleep: Duration(minutes: remM),
    coreSleep: Duration(minutes: coreM),
  );
}

HrvRecord _hrv(DateTime date, double sdnn, {double? rhr}) =>
    HrvRecord(date: date, sdnn: sdnn, restingHeartRate: rhr);

void main() {
  final now = DateTime.utc(2026, 3, 15);

  // ---------------------------------------------------------------------------
  // scoreSleep
  // ---------------------------------------------------------------------------
  group('scoreSleep', () {
    test('returns null for empty list', () {
      expect(scoreSleep([], now), isNull);
    });

    test('good sleep (8h, good ratios) scores high (>70)', () {
      final records = List.generate(
        7,
        (i) => _sleep(
          now.subtract(Duration(days: i)),
          totalH: 8,
          deepM: 80, // 80/480 = 16.7% > 15%
          remM: 100, // 100/480 = 20.8% > 20%
        ),
      );
      final score = scoreSleep(records, now)!;
      expect(score, greaterThanOrEqualTo(70.0));
    });

    test('acute deprivation (last night < 5h) subtracts 20 points', () {
      // Build 6 nights of good sleep
      final records = List.generate(
        6,
        (i) => _sleep(
          now.subtract(Duration(days: i + 1)),
          totalH: 8,
          deepM: 80,
          remM: 100,
        ),
      );
      // Last night: only 4h sleep
      final lastNight = _sleep(now, totalH: 4, deepM: 40, remM: 50);

      final withDeprivation = scoreSleep([lastNight, ...records], now)!;
      final withoutDeprivation = scoreSleep(records, now)!;

      // Score with deprivation should be meaningfully lower
      expect(withDeprivation, lessThan(withoutDeprivation - 5));
    });

    test('poor total sleep (5h) scores lower than good sleep', () {
      final good = List.generate(
        7,
        (i) => _sleep(now.subtract(Duration(days: i)), totalH: 8),
      );
      final poor = List.generate(
        7,
        (i) => _sleep(now.subtract(Duration(days: i)), totalH: 5),
      );
      final goodScore = scoreSleep(good, now)!;
      final poorScore = scoreSleep(poor, now)!;
      expect(goodScore, greaterThan(poorScore));
    });

    test('records outside 14-day window are ignored', () {
      final recent = _sleep(now, totalH: 8, deepM: 80, remM: 100);
      final old = _sleep(now.subtract(const Duration(days: 20)), totalH: 3);
      final scoreWithOld = scoreSleep([recent, old], now)!;
      final scoreWithout = scoreSleep([recent], now)!;
      expect(scoreWithOld, closeTo(scoreWithout, 0.001));
    });

    test('score is clamped between 0 and 100', () {
      // Even with terrible sleep, score should be >= 0
      final records = List.generate(
        7,
        (i) => _sleep(now.subtract(Duration(days: i)), totalH: 2),
      );
      final score = scoreSleep(records, now)!;
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(100.0));
    });

    test('recent nights are weighted more than older nights', () {
      // 13 poor nights + 1 excellent recent night
      final poor = List.generate(
        13,
        (i) => _sleep(now.subtract(Duration(days: i + 1)), totalH: 4),
      );
      final excellent = _sleep(now, totalH: 9, deepM: 100, remM: 120);
      final scoreWithExcellentRecent = scoreSleep([excellent, ...poor], now)!;

      // Compare against 13 poor nights + 1 old excellent night (at day 13)
      final excellentOld = _sleep(now.subtract(const Duration(days: 13)), totalH: 9, deepM: 100, remM: 120);
      final recentPoor = _sleep(now, totalH: 4, deepM: 20, remM: 30);
      final scoreWithPoorRecent = scoreSleep([recentPoor, ...poor.take(12), excellentOld], now)!;

      expect(scoreWithExcellentRecent, greaterThan(scoreWithPoorRecent));
    });
  });

  // ---------------------------------------------------------------------------
  // scoreHrv
  // ---------------------------------------------------------------------------
  group('scoreHrv', () {
    test('returns null for fewer than 3 records', () {
      expect(scoreHrv([], now), isNull);
      expect(scoreHrv([_hrv(now, 50.0)], now), isNull);
      expect(scoreHrv([_hrv(now, 50.0), _hrv(now.subtract(const Duration(days: 1)), 50.0)], now), isNull);
    });

    test('stable SDNN at mean scores in 70-100 range', () {
      final records = List.generate(
        7,
        (i) => _hrv(now.subtract(Duration(days: i)), 60.0),
      );
      final score = scoreHrv(records, now)!;
      expect(score, greaterThanOrEqualTo(70.0));
      expect(score, lessThanOrEqualTo(100.0));
    });

    test('today SDNN well above mean scores high', () {
      // Baseline 60.0, today 80.0 (well above +1 SD)
      final baseline = List.generate(
        6,
        (i) => _hrv(now.subtract(Duration(days: i + 1)), 60.0),
      );
      final today = _hrv(now, 90.0); // far above mean
      final score = scoreHrv([today, ...baseline], now)!;
      expect(score, greaterThan(75.0));
    });

    test('today SDNN well below mean scores low', () {
      final baseline = List.generate(
        6,
        (i) => _hrv(now.subtract(Duration(days: i + 1)), 60.0),
      );
      final today = _hrv(now, 20.0); // far below
      final score = scoreHrv([today, ...baseline], now)!;
      expect(score, lessThan(60.0));
    });

    test('returns null when fewer than 3 records within 14-day window', () {
      // Provide 2 records within window + 1 outside
      final records = [
        _hrv(now, 60.0),
        _hrv(now.subtract(const Duration(days: 1)), 60.0),
        _hrv(now.subtract(const Duration(days: 20)), 60.0), // outside window
      ];
      expect(scoreHrv(records, now), isNull);
    });

    test('RHR rising > 5bpm over 7 days applies -10 penalty', () {
      // 7 records with stable SDNN but rising RHR
      final stable = List.generate(
        7,
        (i) => _hrv(
          now.subtract(Duration(days: 6 - i)),
          60.0,
          rhr: 55.0 + i * 1.2, // rising from 55 to ~62.2 (>5 bpm)
        ),
      );
      final risingRhrScore = scoreHrv(stable, now)!;

      // Same records but flat RHR
      final flatRhr = List.generate(
        7,
        (i) => _hrv(now.subtract(Duration(days: 6 - i)), 60.0, rhr: 60.0),
      );
      final flatRhrScore = scoreHrv(flatRhr, now)!;

      expect(flatRhrScore, greaterThan(risingRhrScore));
    });

    test('score is clamped between 0 and 100', () {
      final records = List.generate(
        7,
        (i) => _hrv(now.subtract(Duration(days: i)), 50.0),
      );
      final score = scoreHrv(records, now)!;
      expect(score, greaterThanOrEqualTo(0.0));
      expect(score, lessThanOrEqualTo(100.0));
    });
  });

  // ---------------------------------------------------------------------------
  // computeReadiness
  // ---------------------------------------------------------------------------
  group('computeReadiness', () {
    AcwrStatus acwrStatus(AcwrZone zone, {double ratio = 1.0}) => AcwrStatus(
          ratio: ratio,
          zone: zone,
          acuteEwma: 100.0,
          chronicEwma: 100.0,
          recommendation: '',
        );

    test('full tier when all three sources provided', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        sleepScore: 80.0,
        hrvScore: 75.0,
      );
      expect(result.tier, ReadinessTier.full);
      expect(result.confidence, ReadinessConfidence.high);
    });

    test('noHrv tier when ACWR + sleep only', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        sleepScore: 80.0,
      );
      expect(result.tier, ReadinessTier.noHrv);
      expect(result.confidence, ReadinessConfidence.moderate);
    });

    test('noSleep tier when ACWR + HRV only', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        hrvScore: 75.0,
      );
      expect(result.tier, ReadinessTier.noSleep);
      expect(result.confidence, ReadinessConfidence.moderate);
    });

    test('acwrOnly tier when only ACWR provided', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
      );
      expect(result.tier, ReadinessTier.acwrOnly);
      expect(result.confidence, ReadinessConfidence.low);
    });

    test('manualOnly tier when only manual slider provided', () {
      final result = computeReadiness(manualSlider: 4.0);
      expect(result.tier, ReadinessTier.manualOnly);
      expect(result.confidence, ReadinessConfidence.low);
    });

    test('cold tier when nothing provided', () {
      final result = computeReadiness();
      expect(result.tier, ReadinessTier.cold);
      expect(result.confidence, ReadinessConfidence.unavailable);
      expect(result.flags, contains(ReadinessFlag.coldStart));
    });

    test('danger zone flag when ACWR ratio > 1.50', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.danger, ratio: 1.7),
      );
      expect(result.flags, contains(ReadinessFlag.acwrDangerZone));
    });

    test('no danger zone flag for optimal ACWR', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal, ratio: 1.0),
      );
      expect(result.flags, isNot(contains(ReadinessFlag.acwrDangerZone)));
    });

    test('full tier produces score in plausible range', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        sleepScore: 80.0,
        hrvScore: 75.0,
      );
      expect(result.score, greaterThan(50.0));
      expect(result.score, lessThanOrEqualTo(100.0));
    });

    test('danger zone ACWR produces lower score than optimal ACWR (all else equal)', () {
      final optimal = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        sleepScore: 80.0,
        hrvScore: 75.0,
      );
      final danger = computeReadiness(
        acwr: acwrStatus(AcwrZone.danger, ratio: 1.7),
        sleepScore: 80.0,
        hrvScore: 75.0,
      );
      expect(optimal.score, greaterThan(danger.score));
    });

    test('componentScores contains acwr key when ACWR provided', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        sleepScore: 80.0,
      );
      expect(result.componentScores.containsKey('acwr'), isTrue);
      expect(result.componentScores.containsKey('sleep'), isTrue);
    });

    test('manual slider weight is 1.0 when no other sources', () {
      const sliderValue = 3.0; // should map to 55
      final result = computeReadiness(manualSlider: sliderValue);
      // With only manual slider, score should equal manual slider score
      expect(result.score, closeTo(55.0, 1.0));
    });

    test('manual slider reduces influence when all 3 objective sources present', () {
      final fullWithoutManual = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        sleepScore: 80.0,
        hrvScore: 75.0,
      );
      // Add a very low manual score – should not drag down much (10% weight)
      final fullWithManual = computeReadiness(
        acwr: acwrStatus(AcwrZone.optimal),
        sleepScore: 80.0,
        hrvScore: 75.0,
        manualSlider: 1.0, // low: maps to 10
      );
      // Difference should be small (manual has small weight)
      final diff = fullWithoutManual.score - fullWithManual.score;
      expect(diff, lessThan(20.0));
    });

    test('score is clamped to 0-100', () {
      final result = computeReadiness(
        acwr: acwrStatus(AcwrZone.danger, ratio: 2.0),
        sleepScore: 0.0,
        hrvScore: 0.0,
      );
      expect(result.score, greaterThanOrEqualTo(0.0));
      expect(result.score, lessThanOrEqualTo(100.0));
    });

    test('coldStart flag not set when ACWR is available', () {
      final result = computeReadiness(acwr: acwrStatus(AcwrZone.optimal));
      expect(result.flags, isNot(contains(ReadinessFlag.coldStart)));
    });
  });
}
