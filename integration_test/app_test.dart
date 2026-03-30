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
  });

  // ── Suite 1: Onboarding ──────────────────────────────────────────────
  group('Onboarding', () {
    testWidgets('completes onboarding and reaches dashboard', (tester) async {
      final container = await bootstrapTestApp(
        firestore: firestore,
        auth: auth,
      );
      await pumpApp(tester, container);

      expect(find.text('Next'), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, 'TestUser');
      await tester.pumpAndSettle();

      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();

      expect(find.text('KG'), findsOneWidget);
      expect(find.text('LBS'), findsOneWidget);

      await tester.tap(find.text('Start Training'));
      await tester.pumpAndSettle();

      expect(find.text('TestUser'), findsOneWidget);
      expect(find.text('DASHBOARD'), findsOneWidget);
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

      expect(find.text('E2E Push Day'), findsOneWidget);
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
}
