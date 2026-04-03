// test/features/smart_planner/widgets/day_picker_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/features/smart_planner/widgets/day_picker.dart';

Widget _buildTestApp(Widget child) {
  return MaterialApp(home: Scaffold(body: child));
}

void main() {
  group('DayPicker', () {
    testWidgets('1. renders 7 day buttons (FilterChip widgets)', (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          DayPicker(
            selectedDays: const {},
            onDayToggled: (_) {},
          ),
        ),
      );

      expect(find.byType(FilterChip), findsNWidgets(7));
    });

    testWidgets('2. tapping a day calls onDayToggled with the correct day value',
        (tester) async {
      int? tappedDay;

      await tester.pumpWidget(
        _buildTestApp(
          DayPicker(
            selectedDays: const {},
            onDayToggled: (day) => tappedDay = day,
          ),
        ),
      );

      // Tap "Mon" — ISO weekday value 1
      await tester.tap(find.widgetWithText(FilterChip, 'Mon'));
      await tester.pump();

      expect(tappedDay, equals(1));
    });

    testWidgets('3. tapping Sunday calls onDayToggled with value 0',
        (tester) async {
      int? tappedDay;

      await tester.pumpWidget(
        _buildTestApp(
          DayPicker(
            selectedDays: const {},
            onDayToggled: (day) => tappedDay = day,
          ),
        ),
      );

      // Tap "Sun" — value 0
      await tester.tap(find.widgetWithText(FilterChip, 'Sun'));
      await tester.pump();

      expect(tappedDay, equals(0));
    });

    testWidgets('4. selected days are visually marked (FilterChip.selected = true)',
        (tester) async {
      // Select Monday (1) and Wednesday (3)
      const selectedDays = {1, 3};

      await tester.pumpWidget(
        _buildTestApp(
          DayPicker(
            selectedDays: selectedDays,
            onDayToggled: (_) {},
          ),
        ),
      );

      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip)).toList();

      // Day order: Mon(1), Tue(2), Wed(3), Thu(4), Fri(5), Sat(6), Sun(0)
      // Index 0 = Mon = selected, Index 1 = Tue = not selected,
      // Index 2 = Wed = selected
      expect(chips[0].selected, isTrue);   // Mon
      expect(chips[1].selected, isFalse);  // Tue
      expect(chips[2].selected, isTrue);   // Wed
      expect(chips[3].selected, isFalse);  // Thu
      expect(chips[4].selected, isFalse);  // Fri
      expect(chips[5].selected, isFalse);  // Sat
      expect(chips[6].selected, isFalse);  // Sun
    });

    testWidgets('5. shows split label text when splitLabel is provided',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          DayPicker(
            selectedDays: const {1, 3, 5},
            onDayToggled: (_) {},
            splitLabel: 'Full Body',
          ),
        ),
      );

      expect(find.text('Full Body'), findsOneWidget);
    });

    testWidgets('6. does not show split label when splitLabel is null',
        (tester) async {
      await tester.pumpWidget(
        _buildTestApp(
          DayPicker(
            selectedDays: const {1},
            onDayToggled: (_) {},
          ),
        ),
      );

      // No unexpected text other than day labels
      expect(find.text('Full Body'), findsNothing);
      expect(find.text('Upper/Lower'), findsNothing);
      expect(find.text('Push/Pull/Legs'), findsNothing);
    });
  });
}
