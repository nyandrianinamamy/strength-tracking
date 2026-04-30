import 'package:flutter/foundation.dart';

const bool _explicitTrainingEngineDebugSurface = bool.fromEnvironment(
  'SHOW_TRAINING_ENGINE_DEBUG',
);

bool shouldShowTrainingEngineDebug({
  bool isDebugMode = kDebugMode,
  bool explicitDebugSurface = _explicitTrainingEngineDebugSurface,
}) {
  return isDebugMode || explicitDebugSurface;
}
