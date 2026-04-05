import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'e2e_helpers.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  late FirebaseFirestore firestore;
  late FirebaseAuth auth;

  // Connect emulators ONCE for the entire process.
  setUpAll(() async {
    final emulators = await connectEmulators();
    firestore = emulators.firestore;
    auth = emulators.auth;
  });

  // Reset data between each test group.
  setUp(() async {
    await resetEmulators();
    // Allow emulators to fully process the reset before starting next test.
    await Future<void>.delayed(const Duration(milliseconds: 500));
  });

  // ── Suite 1: Onboarding ──────────────────────────────────────────────
  group('Onboarding', () {
    testWidgets('completes onboarding skipping About You page',
        (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);

      // Page 1: Welcome
      expect(find.widgetWithText(FilledButton, 'Next'), findsOneWidget);
      await tester.enterText(find.byType(TextField).first, 'TestUser');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Page 2: About You — verify it shows, then skip
      expect(find.text('About You'), findsOneWidget);
      expect(find.text('Sex'), findsOneWidget);
      expect(find.text('Fitness Goal'), findsOneWidget);
      // Use .last — page 1's "Next" button still exists off-screen in the PageView.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next').last);
      await tester.pumpAndSettle();

      // Page 3: Units
      expect(find.text('KG'), findsOneWidget);
      expect(find.text('LBS'), findsOneWidget);
      await tester.ensureVisible(find.text('Start Training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Training'));
      await tester.pumpAndSettle();

      expect(find.text('TestUser'), findsOneWidget);
    });

    testWidgets('completes onboarding with full profile details',
        (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);

      // Page 1: Welcome
      await tester.enterText(find.byType(TextField).first, 'ProfileUser');
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next'));
      await tester.pumpAndSettle();

      // Page 2: About You — fill all fields
      expect(find.text('About You'), findsOneWidget);

      // Sex defaults to Male — switch to Female
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();

      // Enter age
      await tester.enterText(find.widgetWithText(TextField, 'Age'), '25');
      await tester.pumpAndSettle();

      // Enter weight
      await tester.enterText(find.widgetWithText(TextField, 'Weight'), '65');
      await tester.pumpAndSettle();

      // Select fitness goal
      await tester.ensureVisible(find.text('Endurance'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Endurance'));
      await tester.pumpAndSettle();

      // Use .last — page 1's "Next" button still exists off-screen in the PageView.
      await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next').last);
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Next').last);
      await tester.pumpAndSettle();

      // Page 3: Units — choose LBS
      await tester.ensureVisible(find.text('LBS'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('LBS'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Start Training'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Start Training'));
      await tester.pumpAndSettle();

      // On dashboard
      expect(find.text('ProfileUser'), findsOneWidget);

      // Verify data persisted by navigating to settings
      await navigateToSettings(tester);

      expect(find.text('ProfileUser'), findsOneWidget);
      expect(find.text('25'), findsOneWidget); // age (int)
      expect(find.text('65.0'), findsOneWidget); // weight (double → "65.0")
    });
  });

  // ── Suite 2: Exercise CRUD ───────────────────────────────────────────
  group('Exercise CRUD', () {
    testWidgets('create, verify, edit, and archive an exercise',
        (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);

      await navigateToTab(tester, 'EXERCISES');

      await tester.tap(find.text('New Exercise'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Exercise Name'),
        'E2E Test Press',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Chest').first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('E2E Test Press'), findsOneWidget);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, 'Exercise Name'),
        'E2E Renamed Press',
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();

      expect(find.text('E2E Renamed Press'), findsOneWidget);
      expect(find.text('E2E Test Press'), findsNothing);

      await tester.tap(find.byType(PopupMenuButton<String>).first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Archive'));
      await tester.pumpAndSettle();

      expect(find.text('E2E Renamed Press'), findsNothing);
    });
  });

  // ── Suite 3: Routine CRUD ────────────────────────────────────────────
  group('Routine CRUD', () {
    testWidgets('create routine with exercise, verify in list',
        (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);

      await createTestExercise(tester,
          name: 'E2E Bench Press', muscle: 'Chest');

      await createTestRoutine(
        tester,
        routineName: 'E2E Push Day',
        exerciseName: 'E2E Bench Press',
      );

      expect(find.text('E2E Push Day'), findsWidgets);
    });
  });

  // ── Suite 4: Workout Flow ────────────────────────────────────────────
  group('Workout Flow', () {
    testWidgets('start workout, log set, finish, see summary',
        (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);
      await createTestExercise(tester,
          name: 'E2E Squat', muscle: 'Quadriceps');
      await createTestRoutine(
        tester,
        routineName: 'E2E Leg Day',
        exerciseName: 'E2E Squat',
      );

      await completeQuickWorkout(tester, weight: '100', reps: '5');

      // E2E Squat may appear multiple times on summary (title + set details)
      expect(find.text('E2E Squat'), findsWidgets);
    });
  });

  // ── Suite 5: Progress & PRs ──────────────────────────────────────────
  group('Progress and PRs', () {
    testWidgets('completed workout produces a PR on progress screen',
        (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);
      await createTestExercise(tester,
          name: 'E2E Deadlift', muscle: 'Hamstrings');
      await createTestRoutine(
        tester,
        routineName: 'E2E Pull Day',
        exerciseName: 'E2E Deadlift',
      );
      await completeQuickWorkout(tester, weight: '140', reps: '3');

      // Summary screen is outside ShellRoute (no bottom nav).
      // Use "Finish & Go Home" to return to dashboard, then navigate to Progress.
      // Scroll to find the button since it may be below the fold.
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -500));
      for (int i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      await tester.tap(find.text('Finish & Go Home'));
      await tester.pumpAndSettle();

      // Now we're back on dashboard inside ShellRoute — bottom nav available
      await navigateToTab(tester, 'PROGRESS');

      // Overview tab shows "Personal Records" section
      // Exercise name may appear multiple times across sections
      expect(find.text('E2E Deadlift'), findsWidgets);

      // Tap "Lifts" tab
      await tester.tap(find.text('Lifts'));
      await tester.pumpAndSettle();

      expect(find.text('E2E Deadlift'), findsWidgets);
      expect(find.text('Best Set'), findsWidgets);
    });
  });

  // ── Suite 6: Settings Page ────────────────────────────────────────────
  group('Settings Page', () {
    testWidgets('navigates to settings and shows all sections',
        (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);

      await navigateToSettings(tester);

      // AppBar title
      expect(find.text('Settings'), findsOneWidget);

      // Profile section
      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('Sex'), findsOneWidget);
      expect(find.text('Male'), findsOneWidget);
      expect(find.text('Female'), findsOneWidget);
      expect(find.text('Fitness Goal'), findsOneWidget);
      expect(find.text('Strength'), findsOneWidget);
      expect(find.text('Hypertrophy'), findsOneWidget);

      // Scroll to see more sections
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pumpAndSettle();

      // Preferences section
      expect(find.text('Preferences'), findsOneWidget);
      expect(find.text('Unit Preference'), findsOneWidget);
      expect(find.text('KG'), findsWidgets);
      expect(find.text('LBS'), findsWidgets);
    });

    testWidgets('edits profile fields and persists values', (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);

      await navigateToSettings(tester);

      // Change name
      await tester.enterText(
        find.widgetWithText(TextField, 'Your name'),
        'UpdatedName',
      );
      await tester.pumpAndSettle();
      // Wait for debounce (500ms)
      await tester.pump(const Duration(milliseconds: 600));

      // Enter age
      await tester.enterText(find.widgetWithText(TextField, 'Age'), '30');
      await tester.pumpAndSettle();

      // Enter weight
      await tester.enterText(find.widgetWithText(TextField, 'Weight'), '75');
      await tester.pumpAndSettle();

      // Select fitness goal
      await tester.tap(find.text('Strength'));
      await tester.pumpAndSettle();

      // Go back to dashboard
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      // Verify name updated on dashboard
      expect(find.text('UpdatedName'), findsOneWidget);

      // Navigate back to settings and verify persistence
      await navigateToSettings(tester);

      expect(find.text('UpdatedName'), findsOneWidget);
      expect(find.text('30'), findsOneWidget); // age (int)
      expect(find.text('75.0'), findsOneWidget); // weight (double → "75.0")
    });

    testWidgets('switches sex to Female', (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);

      await navigateToSettings(tester);

      // Default is Male — switch to Female
      await tester.tap(find.text('Female'));
      await tester.pumpAndSettle();

      // Go back and re-enter settings
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      await navigateToSettings(tester);

      // Female should still be selected (segmented button shows checkmark)
      // Verify by checking the SegmentedButton state — Female is in the selected set
      final segmented = tester.widget<SegmentedButton<String>>(
        find.byType(SegmentedButton<String>).first,
      );
      expect(segmented.selected, equals({'female'}));
    });

    testWidgets('scrolls to Account and Data sections', (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);
      await completeOnboarding(tester);

      await navigateToSettings(tester);

      // Scroll to bottom
      await tester.drag(find.byType(Scrollable).last, const Offset(0, -800));
      await tester.pumpAndSettle();

      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Anonymous Account'), findsOneWidget);
      expect(find.text('Link Google Account'), findsOneWidget);

      await tester.drag(find.byType(Scrollable).last, const Offset(0, -400));
      await tester.pumpAndSettle();

      expect(find.text('Data'), findsOneWidget);
      expect(find.text('Load Sample Exercises & Routines'), findsOneWidget);
      expect(find.text('Clear Exercises & Routines'), findsOneWidget);
      expect(find.text('Clear Workout History'), findsOneWidget);
    });
  });
}
