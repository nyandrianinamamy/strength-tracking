import 'package:test/test.dart';
import 'package:training_engine/src/e1rm/formulas.dart';

void main() {
  group('rirFromRpe', () {
    test('RPE 10 -> 0', () => expect(rirFromRpe(10.0), 0.0));
    test('RPE 9 -> 1', () => expect(rirFromRpe(9.0), 1.0));
    test('RPE 8 -> 2', () => expect(rirFromRpe(8.0), 2.0));
    test('RPE 9.5 -> 0.5', () => expect(rirFromRpe(9.5), 0.5));
  });

  group('rMax', () {
    test('8 reps @ RPE 8 -> 10', () => expect(rMax(8, 8.0), 10.0));
    test('8 reps @ RPE 10 -> 8', () => expect(rMax(8, 10.0), 8.0));
    test('5 reps @ RPE 9 -> 6', () => expect(rMax(5, 9.0), 6.0));
  });

  group('epley', () {
    test('100kg x rMax 8 -> ~126.67', () {
      expect(epley(100, 8), closeTo(126.67, 0.01));
    });
    test('100kg x rMax 10 -> ~133.33', () {
      expect(epley(100, 10), closeTo(133.33, 0.01));
    });
  });

  group('brzycki', () {
    test('100kg x rMax 8 -> ~124.14', () {
      expect(brzycki(100, 8), closeTo(124.14, 0.01));
    });
    test('returns null for rMax > 30', () {
      expect(brzycki(100, 31), isNull);
    });
    test('returns null for rMax exactly 31', () {
      expect(brzycki(100, 31), isNull);
    });
    test('returns value for rMax exactly 30', () {
      expect(brzycki(100, 30), isNotNull);
    });
  });

  group('lander', () {
    test('100kg x rMax 8 -> ~125.11', () {
      // (100 * 100) / (101.3 - 2.67123 * 8) = 125.109
      expect(lander(100, 8), closeTo(125.11, 0.01));
    });
    test('produces higher estimate for higher rMax', () {
      expect(lander(100, 10), greaterThan(lander(100, 8)));
    });
  });

  group('lombardi', () {
    test('100kg x rMax 8 -> ~123.11', () {
      // 100 * 8^0.10 = 123.114
      expect(lombardi(100, 8), closeTo(123.11, 0.01));
    });
    test('produces higher estimate for higher rMax', () {
      expect(lombardi(100, 10), greaterThan(lombardi(100, 8)));
    });
  });

  group('Paper Table 3 verification', () {
    // 100kg x 8 reps at RPE 10/9/8/7 (rMax 8/9/10/11) using Epley
    test('100kg x 8 @ RPE 10 (rMax 8) -> ~126.67', () {
      final rm = rMax(8, 10.0);
      expect(rm, 8.0);
      expect(epley(100, rm), closeTo(126.67, 0.01));
    });
    test('100kg x 8 @ RPE 9 (rMax 9) -> ~130.00', () {
      final rm = rMax(8, 9.0);
      expect(rm, 9.0);
      expect(epley(100, rm), closeTo(130.0, 0.01));
    });
    test('100kg x 8 @ RPE 8 (rMax 10) -> ~133.33', () {
      final rm = rMax(8, 8.0);
      expect(rm, 10.0);
      expect(epley(100, rm), closeTo(133.33, 0.01));
    });
    test('100kg x 8 @ RPE 7 (rMax 11) -> ~136.67', () {
      final rm = rMax(8, 7.0);
      expect(rm, 11.0);
      expect(epley(100, rm), closeTo(136.67, 0.01));
    });
  });
}
