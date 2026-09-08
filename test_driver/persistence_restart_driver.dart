import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

Future<void> main() async {
  FlutterDriver? driver;
  try {
    final phase = Platform.environment['E2E_RESTART_PHASE'];
    if (!['write', 'read'].contains(phase)) {
      throw StateError('The host must select E2E_RESTART_PHASE=write or read.');
    }
    driver = await FlutterDriver.connect();
    final accepted = await driver.requestData('persistence:phase:$phase');
    if (accepted != phase) {
      throw StateError('Persistence phase was not accepted.');
    }
    final response = Response.fromJson(
      await driver.requestData(null, timeout: const Duration(minutes: 12)),
    );
    final output = Platform.environment['IOS_E2E_OUTPUT_DIR'];
    if (output != null) {
      await File(
        '$output/persistence-$phase-result.json',
      ).writeAsString(response.toJson());
    }
    if (!response.allTestsPassed || response.data?['phase'] != phase) {
      throw StateError(
        'Persistence $phase failed: ${response.formattedFailureDetails}',
      );
    }
    stdout.writeln('Persistence $phase passed.');
  } catch (error) {
    stderr.writeln(error);
    exitCode = 1;
  } finally {
    await driver?.close();
  }
}
