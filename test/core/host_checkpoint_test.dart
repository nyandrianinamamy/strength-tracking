import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/host_checkpoint.dart';

void main() {
  testWidgets('host observation can depend on successive foreground frames', (
    tester,
  ) async {
    final reply = Completer<String>();
    tester.binding.addPostFrameCallback((_) {
      tester.binding.addPostFrameCallback((_) => reply.complete('observed'));
      tester.binding.scheduleFrame();
    });
    tester.binding.scheduleFrame();
    expect(await pumpUntilHostResponse(tester, reply.future), 'observed');
  });

  testWidgets('missing host acknowledgment cannot pass', (tester) async {
    await expectLater(
      pumpUntilHostResponse(
        tester,
        Completer<String>().future,
        timeout: Duration.zero,
      ),
      throwsA(isA<TimeoutException>()),
    );
  });

  testWidgets('host errors remain failures', (tester) async {
    final reply = Completer<String>();
    tester.binding.addPostFrameCallback(
      (_) => reply.completeError(StateError('receipt failed')),
    );
    tester.binding.scheduleFrame();
    Object? failure;
    try {
      await pumpUntilHostResponse(tester, reply.future);
    } catch (error) {
      failure = error;
    }
    expect(failure, isA<StateError>());
  });
}
