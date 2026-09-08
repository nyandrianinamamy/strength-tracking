import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/features/live_activity/workout_live_activity_service.dart';
import 'package:strength_training_tracker/src/features/watch/watch_sync_service.dart';
import 'package:strength_training_tracker/src/shared/widgets/app_loading_screen.dart';

Future<void> main() async {
  await launchKotranaApp();
}

/// Starts the complete application. Optional backends support isolated runtime
/// verification while keeping production bootstrap and repository selection.
Future<ProviderContainer> launchKotranaApp({
  FirebaseOptions? firebaseOptions,
  FirebaseAuth? auth,
  FirebaseFirestore? firestore,
  Future<void> Function()? firebaseInitializer,
}) async {
  WidgetsFlutterBinding.ensureInitialized();
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks([
      'Lexend',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
  });

  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const AppLoadingScreen(),
    ),
  );

  final result = await initializeApp(
    firebaseOptions: firebaseOptions,
    auth: auth,
    firestore: firestore,
    firebaseInitializer: firebaseInitializer,
  );
  final container = buildContainer(result);

  if (defaultTargetPlatform == TargetPlatform.iOS) {
    try {
      container.read(workoutLiveActivityServiceProvider).initialize();
    } catch (e) {
      debugPrint('Live Activity initialization failed: $e');
    }
    try {
      container.read(watchSyncServiceProvider).initialize();
    } catch (e) {
      debugPrint('Watch sync initialization failed: $e');
    }
  }

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const StrengthTrainingApp(),
    ),
  );
  return container;
}
