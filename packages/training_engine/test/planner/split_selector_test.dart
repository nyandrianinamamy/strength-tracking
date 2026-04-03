import 'package:test/test.dart';
import 'package:training_engine/src/planner/split_selector.dart';

void main() {
  // ---------------------------------------------------------------------------
  // selectSplit
  // ---------------------------------------------------------------------------
  group('selectSplit', () {
    test('1 day → fullBody', () {
      expect(selectSplit([1]), equals(SplitType.fullBody));
    });

    test('2 days → fullBody', () {
      expect(selectSplit([1, 3]), equals(SplitType.fullBody));
    });

    test('3 non-consecutive days → fullBody', () {
      // Mon(1), Wed(3), Fri(5) – no two are adjacent
      expect(selectSplit([1, 3, 5]), equals(SplitType.fullBody));
    });

    test('3 consecutive days → pushPullLegs', () {
      // Mon(1), Tue(2), Wed(3)
      expect(selectSplit([1, 2, 3]), equals(SplitType.pushPullLegs));
    });

    test('4 days → upperLower', () {
      expect(selectSplit([1, 2, 4, 5]), equals(SplitType.upperLower));
    });

    test('5 days → pushPullLegs', () {
      expect(selectSplit([1, 2, 3, 4, 5]), equals(SplitType.pushPullLegs));
    });

    test('6 days → pushPullLegs', () {
      expect(selectSplit([0, 1, 2, 3, 4, 5]), equals(SplitType.pushPullLegs));
    });

    test('empty list → fullBody', () {
      expect(selectSplit([]), equals(SplitType.fullBody));
    });
  });

  // ---------------------------------------------------------------------------
  // hasConsecutiveDays
  // ---------------------------------------------------------------------------
  group('hasConsecutiveDays', () {
    test('Mon-Tue adjacent → true', () {
      expect(hasConsecutiveDays([1, 2]), isTrue);
    });

    test('Mon, Wed, Fri not adjacent → false', () {
      expect(hasConsecutiveDays([1, 3, 5]), isFalse);
    });

    test('Sat(6) and Sun(0) wrap → true', () {
      expect(hasConsecutiveDays([6, 0]), isTrue);
    });

    test('Sun(0), Tue(2), Fri(5) no wrap → false', () {
      expect(hasConsecutiveDays([0, 2, 5]), isFalse);
    });

    test('Fri(5), Sat(6) adjacent → true', () {
      expect(hasConsecutiveDays([5, 6]), isTrue);
    });

    test('single day → false', () {
      expect(hasConsecutiveDays([3]), isFalse);
    });

    test('empty list → false', () {
      expect(hasConsecutiveDays([]), isFalse);
    });
  });

  // ---------------------------------------------------------------------------
  // focusesForSplit
  // ---------------------------------------------------------------------------
  group('focusesForSplit', () {
    test('fullBody × 3 → all fullBody', () {
      final focuses = focusesForSplit(SplitType.fullBody, 3);
      expect(focuses, equals([
        SessionFocus.fullBody,
        SessionFocus.fullBody,
        SessionFocus.fullBody,
      ]));
    });

    test('upperLower × 4 → upper/lower/upper/lower', () {
      final focuses = focusesForSplit(SplitType.upperLower, 4);
      expect(focuses, equals([
        SessionFocus.upper,
        SessionFocus.lower,
        SessionFocus.upper,
        SessionFocus.lower,
      ]));
    });

    test('pushPullLegs × 5 → push/pull/legs/push/pull', () {
      final focuses = focusesForSplit(SplitType.pushPullLegs, 5);
      expect(focuses, equals([
        SessionFocus.push,
        SessionFocus.pull,
        SessionFocus.legs,
        SessionFocus.push,
        SessionFocus.pull,
      ]));
    });

    test('upperLower × 2 → upper/lower', () {
      final focuses = focusesForSplit(SplitType.upperLower, 2);
      expect(focuses, equals([SessionFocus.upper, SessionFocus.lower]));
    });

    test('zero days → empty list', () {
      expect(focusesForSplit(SplitType.fullBody, 0), isEmpty);
    });
  });
}
