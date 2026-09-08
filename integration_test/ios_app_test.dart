import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/features/routines/routines_screen.dart';

import 'ios_fixtures.dart';
import 'ios_app_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  SharedPreferences.setPrefix('kotrana_ios_e2e.');

  setUpAll(() {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        !const bool.fromEnvironment('E2E_DISPOSABLE_SIMULATOR')) {
      throw UnsupportedError(
        'Run with tool/ci/run_ios_e2e.sh on an isolated iOS simulator.',
      );
    }
  });

  testWidgets('signed-out native entry requires an invitation', (tester) async {
    final app = await IosTestApp.start(
      tester,
      AppState.empty(),
      signedIn: false,
    );
    addTearDown(() => app.unmount(tester));
    await waitForUi(tester, find.text("Let's Get Started"));
    expect(find.text('Next'), findsNothing);
    expect(find.textContaining('invite-only'), findsOneWidget);
    await revealUi(tester, find.text('Sign in with Email'));
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, 'Sign in with Email'),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets(
    'profile, exercise, routine, full workout, progress and storage',
    (tester) async {
      final app = await IosTestApp.start(tester, AppState.empty());
      addTearDown(() => app.unmount(tester));
      await waitForUi(tester, find.widgetWithText(FilledButton, 'Next'));
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
            .onPressed,
        isNull,
      );
      await enterUi(tester, find.byType(TextField).first, 'Native Athlete');
      await tapUi(tester, find.widgetWithText(FilledButton, 'Next'));
      await waitForUi(tester, find.text('About You'));
      await enterUi(tester, find.widgetWithText(TextField, 'Age'), '31');
      await enterUi(tester, find.widgetWithText(TextField, 'Weight'), '68');
      await tapUi(tester, find.text('Female'));
      await tapUi(tester, find.widgetWithText(FilledButton, 'Next').last);
      await tapUi(tester, find.text('Start Training'));
      await waitForUi(tester, find.text('Native Athlete'));

      await tabUi(tester, 'Exercises');
      await tapUi(tester, find.text('New Exercise'));
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Exercise Name'),
        'Native Press',
      );
      await tapUi(tester, find.text('Chest').first);
      await tapUi(tester, find.text('Save'));
      expect(app.state.exercises.single.name, 'Native Press');

      await tabUi(tester, 'Routines');
      await tapUi(tester, find.text('Create New Routine'));
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Routine Name'),
        'Native Push',
      );
      await tapUi(tester, find.text('Tap to add exercises'));
      await tapUi(tester, find.text('Native Press').last);
      await tapUi(tester, find.text('Create Routine'));
      expect(
        app.state.routines.single.exercises.single.exerciseId,
        app.state.exercises.single.id,
      );

      await tapUi(tester, find.byIcon(Icons.play_arrow).first);
      await waitForUi(tester, find.text('FINISH'));
      final targetSets = app.state.routines.single.exercises.single.targetSets;
      for (var set = 1; set <= targetSets; set++) {
        await logStrengthUi(tester, '60', '8');
        expect(app.state.activeSession!.completedSets.length, set);
      }
      await finishUi(tester);
      expect(app.state.activeSession, isNull);
      expect(
        app.state.completedSessions.single.completedSets.length,
        targetSets,
      );
      expect(
        app.state.completedSessions.single.completedSets.every(
          (set) => set.weightKg == 60 && set.reps == 8,
        ),
        isTrue,
      );
      await tapUi(tester, find.text('Finish & Go Home'));
      await tabUi(tester, 'Progress');
      await revealUi(tester, find.text('Native Press'));
      await tapUi(tester, find.text('Lifts'));
      await revealUi(tester, find.text('Best Set'));

      await tabUi(tester, 'Dashboard');
      await tapUi(tester, find.byIcon(Icons.settings_outlined));
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Your name'),
        'Persisted Athlete',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await app.expectPersisted(
        tester,
        (s) =>
            s.userName == 'Persisted Athlete' &&
            s.completedSessions.length == 1,
      );
      await app.restart(tester);
      await waitForUi(tester, find.text('Persisted Athlete'));
      expect(app.state.age, 31);
      expect(app.state.sex, 'female');
      expect(
        app.state.completedSessions.single.completedSets.length,
        targetSets,
      );
      await tabUi(tester, 'Routines');
      await revealUi(
        tester,
        find.descendant(
          of: find.byType(RoutinesScreen),
          matching: find.text('Native Push'),
        ),
      );
    },
  );

  testWidgets('edit and archive exercises and routines through UI', (
    tester,
  ) async {
    final app = await IosTestApp.start(tester, e2eRichState());
    addTearDown(() => app.unmount(tester));
    await tabUi(tester, 'Routines');
    await tapUi(
      tester,
      find.descendant(
        of: find.byType(RoutinesScreen),
        matching: find.text('Flow Push Strength'),
      ),
    );
    await enterUi(
      tester,
      find.widgetWithText(TextField, 'Routine Name'),
      'Native Edited Routine',
    );
    await tapUi(tester, find.text('Save'));
    expect(
      app.state.routineById('e2e_push_routine')!.name,
      'Native Edited Routine',
    );
    await tapUi(
      tester,
      find.descendant(
        of: find.byType(RoutinesScreen),
        matching: find.text('Native Edited Routine'),
      ),
    );
    await tapUi(tester, find.byTooltip('Archive Routine'));
    await tapUi(tester, find.widgetWithText(TextButton, 'Archive Routine'));
    expect(app.state.routineById('e2e_push_routine')!.archived, isTrue);

    await tabUi(tester, 'Exercises');
    await enterUi(tester, find.byType(TextField).first, 'Flow Bench Press');
    await tapUi(tester, find.byType(PopupMenuButton<String>).first);
    await tapUi(tester, find.text('Edit'));
    await enterUi(
      tester,
      find.widgetWithText(TextField, 'Exercise Name'),
      'Native Edited Press',
    );
    await tapUi(tester, find.text('Save'));
    await enterUi(tester, find.byType(TextField).first, 'Native Edited Press');
    await tapUi(tester, find.byType(PopupMenuButton<String>).first);
    await tapUi(tester, find.text('Archive'));
    expect(app.state.exerciseById('e2e_strength_press')!.archived, isTrue);
    expect(
      find.byWidgetPredicate(
        (widget) => widget is Text && widget.data == 'Native Edited Press',
      ),
      findsNothing,
    );
  });

  testWidgets('resume persisted active workout, cancel finish, then discard', (
    tester,
  ) async {
    final app = await IosTestApp.start(
      tester,
      e2eRichState(includeActiveSession: true, includeCompletedSessions: false),
    );
    addTearDown(() => app.unmount(tester));
    await tapUi(tester, find.text('RESUME SESSION'));
    await logStrengthUi(tester, '75', '5');
    await app.restart(tester);
    await tapUi(tester, find.text('RESUME SESSION'));
    expect(app.state.activeSession!.completedSets.single.weightKg, 75);
    await tapUi(tester, find.text('FINISH'));
    await tapUi(tester, find.text('Keep Training'));
    expect(app.state.activeSession, isNotNull);
    await tapUi(tester, find.text('FINISH'));
    await tapUi(tester, find.text('Discard Session'));
    await app.expectPersisted(tester, (s) => s.activeSession == null);
    expect(app.state.completedSessions, isEmpty);
  });

  testWidgets('stale session can be discarded explicitly', (tester) async {
    final app = await IosTestApp.start(
      tester,
      e2eRichState(includeActiveSession: true, staleActiveSession: true),
    );
    addTearDown(() => app.unmount(tester));
    await tapUi(tester, find.text('Review session'));
    await waitForUi(tester, find.text('Resume stale session?'));
    await tapUi(tester, find.text('Discard'));
    expect(app.state.activeSession, isNull);
    expect(app.state.completedSessions.length, 2);
  });

  testWidgets('timed workout countdown, manual set, finish and progress', (
    tester,
  ) async {
    final app = await IosTestApp.start(
      tester,
      e2eRichState(
        includeActiveSession: true,
        activeRoutineId: 'e2e_timed_routine',
        includeCompletedSessions: false,
      ),
    );
    addTearDown(() => app.unmount(tester));
    await tapUi(tester, find.text('RESUME SESSION'));
    await tapUi(tester, find.text('Start'));
    await tester.pump(const Duration(seconds: 2));
    await tapUi(tester, find.text('Pause'));
    await tapUi(tester, find.text('Reset'));
    await enterUi(tester, find.byType(TextField).first, '2');
    await tapUi(tester, find.text('LOG'));
    expect(app.state.activeSession!.completedSets.single.durationSeconds, 120);
    await finishUi(tester);
    await tapUi(tester, find.text('Finish & Go Home'));
    await tabUi(tester, 'Progress');
    await revealUi(tester, find.text('Flow Plank Hold'));
    expect(app.state.routineGroupById('e2e_group')!.pendingRoutineIds, [
      'e2e_push_routine',
    ]);
  });

  testWidgets('routine group creation, edit and deletion persist', (
    tester,
  ) async {
    final app = await IosTestApp.start(
      tester,
      e2eRichState().copyWith(
        routineGroups: const [],
        clearActiveRoutineGroupId: true,
      ),
    );
    addTearDown(() => app.unmount(tester));
    await tabUi(tester, 'Routines');
    await tapUi(tester, find.text('Groups'));
    await tapUi(tester, find.byTooltip('New group'));
    await enterUi(
      tester,
      find.widgetWithText(TextField, 'Group name'),
      'Native Rotation',
    );
    await tapUi(tester, find.text('Add Routines'));
    await tapUi(tester, find.text('Flow Push Strength'));
    await tapUi(tester, find.text('Add more routines'));
    await tapUi(tester, find.text('Flow Core Timer'));
    await tapUi(tester, find.text('Create Group'));
    expect(app.state.routineGroups.last.routineIds, [
      'e2e_push_routine',
      'e2e_timed_routine',
    ]);
    final groupId = app.state.routineGroups.last.id;
    await tapUi(tester, find.text('Native Rotation'));
    await enterUi(
      tester,
      find.widgetWithText(TextField, 'Group name'),
      'Native Rotation Edited',
    );
    await tapUi(tester, find.text('Save Changes'));
    await app.expectPersisted(
      tester,
      (s) => s.routineGroupById(groupId)?.name == 'Native Rotation Edited',
    );
    await tapUi(tester, find.text('Native Rotation Edited'));
    await tapUi(tester, find.text('Delete Group'));
    await tapUi(tester, find.widgetWithText(TextButton, 'Delete'));
    expect(app.state.routineGroupById(groupId), isNull);
    await app.expectPersisted(
      tester,
      (s) => s.routineGroupById(groupId) == null,
    );
  });

  testWidgets('smart planner validates days, generates and adopts a plan', (
    tester,
  ) async {
    final app = await IosTestApp.start(
      tester,
      e2eRichState(includeCompletedSessions: false),
    );
    addTearDown(() => app.unmount(tester));
    await tabUi(tester, 'Routines');
    await tapUi(tester, find.text('Generate Smart Plan'));
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Next'))
          .onPressed,
      isNull,
    );
    for (final day in ['Mon', 'Wed', 'Fri']) {
      await tapUi(tester, find.text(day));
    }
    await tapUi(tester, find.widgetWithText(FilledButton, 'Next'));
    await tapUi(tester, find.text('Strength'));
    await tapUi(tester, find.widgetWithText(FilledButton, 'Next').last);
    await tapUi(
      tester,
      find.byKey(const ValueKey('preferred_e2e_strength_press')),
    );
    await tapUi(tester, find.widgetWithText(FilledButton, 'Generate'));
    await waitForUi(tester, find.text('Adopt Plan'));
    await tapUi(tester, find.text('Adopt Plan'));
    final adopted = app.state.routines
        .where(
          (routine) => routine.exercises.any(
            (exercise) => exercise.plannerMetadata['source'] == 'smart_planner',
          ),
        )
        .toList();
    expect(adopted.length, 3);
    await app.expectPersisted(
      tester,
      (s) => s.routines.length == app.state.routines.length,
    );
    await revealUi(tester, find.text(adopted.first.name));
  });

  testWidgets('language, units and theme persist across app restart', (
    tester,
  ) async {
    final app = await IosTestApp.start(tester, e2eRichState());
    addTearDown(() => app.unmount(tester));
    await tapUi(tester, find.byIcon(Icons.settings_outlined));
    await tapUi(tester, find.text('LBS'));
    await tapUi(tester, find.byIcon(Icons.dark_mode));
    await tapUi(tester, find.text('FR'));
    await waitForUi(tester, find.text('Paramètres'));
    await app.expectPersisted(
      tester,
      (state) =>
          state.preferredUnit == 'lbs' &&
          state.preferredTheme == 'dark' &&
          state.preferredLanguage == 'fr',
    );
    await app.restart(tester);
    expect(app.state.preferredUnit, 'lbs');
    expect(app.state.preferredTheme, 'dark');
    expect(app.state.preferredLanguage, 'fr');
    await tapUi(tester, find.byIcon(Icons.settings_outlined));
    await waitForUi(tester, find.text('Paramètres'));
    await revealUi(tester, find.text('Politique de confidentialité'));
    await revealUi(tester, find.text("Conditions d'utilisation"));
    await tapUi(tester, find.text('EN'));
    await waitForUi(tester, find.text('Settings'));
    await app.expectPersisted(
      tester,
      (state) => state.preferredLanguage == 'en',
    );
  });

  testWidgets('clear history requires confirmation and keeps the library', (
    tester,
  ) async {
    final app = await IosTestApp.start(tester, e2eRichState());
    addTearDown(() => app.unmount(tester));
    final exercises = app.state.exercises.map((e) => e.id).toList();
    final routines = app.state.routines.map((r) => r.id).toList();
    expect(app.state.completedSessions.length, 2);
    await tapUi(tester, find.byIcon(Icons.settings_outlined));
    await tapUi(tester, find.text('Clear Workout History'));
    await waitForUi(tester, find.text('Clear Workout History?'));
    await tapUi(tester, find.widgetWithText(TextButton, 'Cancel'));
    expect(app.state.completedSessions.length, 2);
    await tapUi(tester, find.text('Clear Workout History'));
    await tapUi(tester, find.widgetWithText(TextButton, 'Clear'));
    await app.expectPersisted(tester, (state) => state.sessions.isEmpty);
    expect(app.state.exercises.map((e) => e.id).toList(), exercises);
    expect(app.state.routines.map((r) => r.id).toList(), routines);
    await app.restart(tester);
    expect(app.state.sessions, isEmpty);
    expect(app.state.exercises.map((e) => e.id).toList(), exercises);
  });

  testWidgets('clear library preserves workout history and its definitions', (
    tester,
  ) async {
    final app = await IosTestApp.start(tester, e2eRichState());
    addTearDown(() => app.unmount(tester));
    final sessions = app.state.completedSessions.map((s) => s.id).toList();
    await tapUi(tester, find.byIcon(Icons.settings_outlined));
    await tapUi(tester, find.text('Clear Exercises & Routines'));
    await waitForUi(tester, find.text('Clear Exercises & Routines?'));
    await tapUi(tester, find.widgetWithText(TextButton, 'Cancel'));
    expect(app.state.exercises.any((exercise) => !exercise.archived), isTrue);
    await tapUi(tester, find.text('Clear Exercises & Routines'));
    await tapUi(tester, find.widgetWithText(TextButton, 'Clear'));
    await app.expectPersisted(
      tester,
      (state) =>
          state.exercises.every((e) => e.archived) &&
          state.routines.every((r) => r.archived) &&
          state.completedSessions.length == 2,
    );
    expect(app.state.completedSessions.map((s) => s.id).toList(), sessions);
    for (final session in app.state.completedSessions) {
      expect(app.state.routines.any((r) => r.id == session.routineId), isTrue);
      for (final set in session.completedSets) {
        expect(app.state.exercises.any((e) => e.id == set.exerciseId), isTrue);
      }
    }
    await app.restart(tester);
    expect(app.state.completedSessions.map((s) => s.id).toList(), sessions);
  });
}
