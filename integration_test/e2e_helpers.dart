import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:http/http.dart' as http;

const projectId = 'myappv4';
const firestoreHost = 'localhost';
const firestorePort = 8081;
const authHost = 'localhost';
const authPort = 9099;

/// Connect Firebase singletons to emulators. Call ONCE per process.
({FirebaseFirestore firestore, FirebaseAuth auth}) connectEmulators() {
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

/// Complete onboarding: enter name, select KG, start training.
Future<void> completeOnboarding(WidgetTester tester) async {
  await tester.enterText(find.byType(TextField).first, 'TestUser');
  await tester.pumpAndSettle();
  await tester.tap(find.text('Next'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Start Training'));
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
  await tester.tap(find.text(muscle));
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

/// Start a workout from dashboard, log one set, finish.
Future<void> completeQuickWorkout(
  WidgetTester tester, {
  String weight = '100',
  String reps = '5',
}) async {
  await navigateToTab(tester, 'DASHBOARD');

  // Dashboard button label (l10n): "START SESSION"
  await tester.tap(find.text('START SESSION'));
  await tester.pumpAndSettle();

  // Enter weight (first TextField on active workout screen)
  await tester.enterText(find.byType(TextField).first, weight);
  await tester.pumpAndSettle();

  // Enter reps — second TextField in the input row
  final textFields = find.byType(TextField);
  await tester.enterText(textFields.at(1), reps);
  await tester.pumpAndSettle();

  // Tap LOG (l10n: "LOG")
  await tester.tap(find.text('LOG'));
  await tester.pumpAndSettle();

  // Trigger finish — bottom bar has "FINISH" text (l10n: "FINISH")
  await tester.tap(find.text('FINISH'));
  await tester.pumpAndSettle();

  // Confirmation bottom sheet — tap "Finish & Save" (l10n: "Finish & Save")
  await tester.tap(find.text('Finish & Save'));
  await tester.pumpAndSettle();
}
