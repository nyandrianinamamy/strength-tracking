import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/firebase_options.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:http/http.dart' as http;

const projectId = 'myappv4';
const firestoreHost = 'localhost';
const firestorePort = 8081;
const authHost = 'localhost';
const authPort = 9099;

/// Initialize Firebase and connect singletons to emulators. Call ONCE per process.
Future<({FirebaseFirestore firestore, FirebaseAuth auth})> connectEmulators() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final firestore = FirebaseFirestore.instance;
  firestore.useFirestoreEmulator(firestoreHost, firestorePort);
  final auth = FirebaseAuth.instance;
  auth.useAuthEmulator(authHost, authPort);
  return (firestore: firestore, auth: auth);
}

/// Clear all Firestore data via emulator REST API.
Future<void> clearFirestoreEmulator() async {
  final url = Uri.parse(
    'http://$firestoreHost:$firestorePort'
    '/emulator/v1/projects/$projectId/databases/(default)/documents',
  );
  await http.delete(url);
}

/// Clear all Auth accounts via emulator REST API.
Future<void> clearAuthEmulator() async {
  final url = Uri.parse(
    'http://$authHost:$authPort'
    '/emulator/v1/projects/$projectId/accounts',
  );
  await http.delete(url);
}

/// Reset emulator state (both Auth and Firestore).
Future<void> resetEmulators() async {
  await Future.wait([clearFirestoreEmulator(), clearAuthEmulator()]);
}

/// Bootstrap using the REAL app initialization path from app_bootstrap.dart.
Future<ProviderContainer> bootstrapTestApp({
  required FirebaseFirestore firestore,
  required FirebaseAuth auth,
}) async {
  // Sign out any stale user from previous test (emulator reset deletes accounts
  // but the SDK still caches the old token).
  if (auth.currentUser != null) {
    await auth.signOut();
  }
  final result = await initializeApp(firestore: firestore, auth: auth);
  return buildContainer(result);
}

/// Pump the app widget and wait for it to settle.
Future<void> pumpApp(WidgetTester tester, ProviderContainer container) async {
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: const StrengthTrainingApp(),
    ),
  );
  await tester.pumpAndSettle();
}

/// Navigate to a tab by tapping the bottom nav label.
Future<void> navigateToTab(WidgetTester tester, String label) async {
  await tester.tap(find.text(label));
  await tester.pumpAndSettle();
}

/// Complete onboarding: enter name, skip About You, select KG, start training.
Future<void> completeOnboarding(WidgetTester tester) async {
  // Page 1: Welcome — enter name and advance
  await tester.enterText(find.byType(TextField).first, 'TestUser');
  await tester.pumpAndSettle();
  // Scroll the Next button into view — on smaller viewports the button may
  // be below the keyboard or safe area, causing hit-test failures.
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();

  // Page 2: About You — skip (all fields optional)
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();

  // Page 3: Units — start training
  await tester.ensureVisible(find.text('Start Training'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start Training'));
  await tester.pumpAndSettle();
}

/// Complete onboarding with full profile details.
Future<void> completeOnboardingWithProfile(
  WidgetTester tester, {
  String name = 'TestUser',
  String age = '28',
  String weight = '82',
  String fitnessGoal = 'Hypertrophy',
}) async {
  // Page 1: Welcome — enter name
  await tester.enterText(find.byType(TextField).first, name);
  await tester.pumpAndSettle();
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();

  // Page 2: About You — fill in details
  // Sex defaults to Male (pre-selected)
  // Enter age
  await tester.enterText(find.widgetWithText(TextField, 'Age'), age);
  await tester.pumpAndSettle();
  // Enter weight
  await tester.enterText(find.widgetWithText(TextField, 'Weight'), weight);
  await tester.pumpAndSettle();
  // Select fitness goal chip — scroll into view first
  await tester.ensureVisible(find.text(fitnessGoal));
  await tester.pumpAndSettle();
  await tester.tap(find.text(fitnessGoal));
  await tester.pumpAndSettle();
  // Proceed to units page
  await tester.ensureVisible(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(FilledButton, 'Next'));
  await tester.pumpAndSettle();

  // Page 3: Units — start training
  await tester.ensureVisible(find.text('Start Training'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start Training'));
  await tester.pumpAndSettle();
}

/// Navigate to settings page from dashboard.
Future<void> navigateToSettings(WidgetTester tester) async {
  // Tap the settings gear icon (top-right of dashboard header)
  await tester.tap(find.byIcon(Icons.settings_outlined));
  await tester.pumpAndSettle();
}

/// Create a minimal test exercise via the UI.
Future<void> createTestExercise(
  WidgetTester tester, {
  String name = 'E2E Press',
  String muscle = 'Chest',
}) async {
  await navigateToTab(tester, 'EXERCISES');
  await tester.tap(find.text('New Exercise'));
  await tester.pumpAndSettle();
  await tester.enterText(
    find.widgetWithText(TextField, 'Exercise Name'),
    name,
  );
  await tester.pumpAndSettle();
  // Muscle name appears in both primary and secondary sections — tap the first one (primary).
  await tester.tap(find.text(muscle).first);
  await tester.pumpAndSettle();
  await tester.tap(find.text('Save'));
  await tester.pumpAndSettle();
}

/// Create a minimal test routine via the UI.
/// Requires [exerciseName] exercise to already exist.
Future<void> createTestRoutine(
  WidgetTester tester, {
  String routineName = 'E2E Routine',
  String exerciseName = 'E2E Press',
}) async {
  await navigateToTab(tester, 'ROUTINES');
  await tester.tap(find.text('Create New Routine'));
  await tester.pumpAndSettle();

  // Fill routine name (l10n label: "Routine Name")
  await tester.enterText(
    find.widgetWithText(TextField, 'Routine Name'),
    routineName,
  );
  await tester.pumpAndSettle();

  // Add exercise — tap the "Tap to add exercises" dashed card
  await tester.tap(find.text('Tap to add exercises'));
  await tester.pumpAndSettle();

  // In the exercise picker bottom sheet, tap the exercise name
  await tester.tap(find.text(exerciseName).last);
  await tester.pumpAndSettle();

  // Save — the bottom button says "Create Routine" for new routines
  await tester.tap(find.text('Create Routine'));
  await tester.pumpAndSettle();
}

/// Start a workout from the routines screen play button, log one set, finish.
///
/// Uses pump() instead of pumpAndSettle() on the active workout screen
/// because the session timer prevents settling.
Future<void> completeQuickWorkout(
  WidgetTester tester, {
  String weight = '100',
  String reps = '5',
}) async {
  // Start workout from the routines screen's play button instead of dashboard
  // (dashboard may have START SESSION below the fold on small viewports)
  await navigateToTab(tester, 'ROUTINES');
  // Tap the play button (circular icon button) on the routine card
  await tester.tap(find.byIcon(Icons.play_arrow).first);
  // Active workout screen has a running timer — use pump() not pumpAndSettle()
  // Give it enough time to fully render including Firestore round-trips
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Enter weight (first TextField on active workout screen)
  await tester.enterText(find.byType(TextField).first, weight);
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Enter reps — second TextField in the input row
  final textFields = find.byType(TextField);
  await tester.enterText(textFields.at(1), reps);
  for (int i = 0; i < 5; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Tap LOG (l10n: "LOG") — opens RPE modal
  await tester.tap(find.text('LOG'));
  for (int i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // RPE modal: accept default RPE and tap "Save & Log Set"
  await tester.tap(find.text('Save & Log Set'));
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Trigger finish — bottom bar has "FINISH" text (l10n: "FINISH")
  await tester.tap(find.text('FINISH'));
  for (int i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }

  // Confirmation bottom sheet — tap "Finish & Save" (l10n: "Finish & Save")
  await tester.tap(find.text('Finish & Save'));
  // Wait for navigation to summary screen
  for (int i = 0; i < 30; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
