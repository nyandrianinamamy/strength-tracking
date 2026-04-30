import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/debug_surface.dart';

void main() {
  test('training engine debug surface is hidden in release by default', () {
    expect(
      shouldShowTrainingEngineDebug(
        isDebugMode: false,
        explicitDebugSurface: false,
      ),
      isFalse,
    );
  });

  test('training engine debug surface remains available in debug builds', () {
    expect(
      shouldShowTrainingEngineDebug(
        isDebugMode: true,
        explicitDebugSurface: false,
      ),
      isTrue,
    );
  });

  test('training engine debug surface can be explicitly enabled', () {
    expect(
      shouldShowTrainingEngineDebug(
        isDebugMode: false,
        explicitDebugSurface: true,
      ),
      isTrue,
    );
  });
}
