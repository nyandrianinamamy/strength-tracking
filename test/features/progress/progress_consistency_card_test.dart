import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/progress/progress_screen.dart';
import 'package:strength_training_tracker/src/features/progress/progress_service.dart';

void main() {
  testWidgets(
    'progress overview shows weekly consistency instead of a streak',
    (tester) async {
      final initialState = AppState.empty();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            appStateRepositoryProvider.overrideWithValue(
              MemoryAppStateRepository(initialState: initialState),
            ),
            initialAppStateProvider.overrideWithValue(initialState),
            progressSnapshotProvider.overrideWith((ref) async {
              return const ProgressSnapshot(
                averageWorkoutDaysPerWeek: 2.4,
                currentWeekWorkoutDays: 4,
                weeklyTrainingTargetDays: 3,
                weeksOnTrack: 5,
                calendarSessions: [],
                personalRecords: [],
                weeklyVolume: [],
                topLifts: [],
              );
            }),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ProgressScreen()),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('CONSISTENCY'), findsOneWidget);
      expect(find.text('3 / 3 this week'), findsOneWidget);
      expect(find.text('5 weeks on track'), findsOneWidget);
      expect(find.text('Active Streak'), findsNothing);
    },
  );
}
