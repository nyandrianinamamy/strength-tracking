import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

/// Keep the foreground app rendering while the external driver observes it.
/// Awaiting the response alone can starve frame-scheduled provider work.
Future<T> pumpUntilHostResponse<T>(
  WidgetTester tester,
  Future<T> response, {
  Duration timeout = const Duration(seconds: 120),
}) async {
  var finished = false;
  T? value;
  Object? failure;
  StackTrace? failureStack;
  response.then(
    (result) {
      value = result;
      finished = true;
    },
    onError: (Object error, StackTrace stack) {
      failure = error;
      failureStack = stack;
      finished = true;
    },
  );
  final elapsed = Stopwatch()..start();
  while (!finished) {
    if (elapsed.elapsed >= timeout) {
      throw TimeoutException(
        'The Watch host did not acknowledge the checkpoint.',
        timeout,
      );
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  if (failure != null) Error.throwWithStackTrace(failure!, failureStack!);
  return value as T;
}
