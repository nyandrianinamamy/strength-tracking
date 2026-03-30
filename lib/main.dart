import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:strength_training_tracker/src/features/live_activity/workout_live_activity_service.dart';
import 'package:strength_training_tracker/src/features/watch/watch_sync_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final result = await initializeApp();
  final container = buildContainer(result);

  if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
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
}
