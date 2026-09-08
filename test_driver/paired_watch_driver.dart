import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_driver/flutter_driver.dart';
import 'package:integration_test/common.dart';

const _watchBundleId = 'dev.mamy-r.kotrana.watchkitapp';

Future<void> main() async {
  FlutterDriver? driver;
  try {
    final host = await _WatchHost.create();
    driver = await FlutterDriver.connect();
    final checkpoints = <Map<String, Object?>>[];
    while (true) {
      final request =
          jsonDecode(
                await driver.requestData(
                  'paired-watch:next',
                  timeout: const Duration(seconds: 90),
                ),
              )
              as Map<String, dynamic>;
      if (request['finished'] == true) break;
      final result = await host.check(request);
      checkpoints.add(result);
      await File(
        '${host.output.path}/checkpoints.json',
      ).writeAsString(const JsonEncoder.withIndent('  ').convert(checkpoints));
      stdout.writeln('${result['name']}: ${result['detail']}');
      await driver.requestData('paired-watch:ack:${jsonEncode(result)}');
    }
    final response = Response.fromJson(await driver.requestData(null));
    await File(
      '${host.output.path}/result.json',
    ).writeAsString(response.toJson());
    if (!response.allTestsPassed) {
      stderr.writeln(response.formattedFailureDetails);
      exitCode = 1;
    } else {
      stdout.writeln('Paired Watch transport and UI acceptance passed.');
    }
  } catch (error, stack) {
    stderr.writeln('Paired Watch acceptance failed: $error\n$stack');
    exitCode = 1;
  } finally {
    await driver?.close();
  }
}

class _WatchHost {
  _WatchHost(this.phoneId, this.watchId, this.output);

  final String phoneId;
  final String watchId;
  final Directory output;
  String? _cachePath;
  bool _receivedSession = false;
  Map<String, Object?> _lastObserved = {};

  static Future<_WatchHost> create() async {
    if (!Platform.isMacOS) throw StateError('This driver requires macOS.');
    final phoneId = _simulatorId('IOS_E2E_SIMULATOR_UDID');
    final watchId = _simulatorId('WATCH_SIMULATOR_UDID');
    final inventory =
        jsonDecode(await _simctl(['list', 'devices', '-j']))
            as Map<String, dynamic>;
    final devices = inventory['devices'] as Map<String, dynamic>;
    void requireBooted(String id, String platform) {
      for (final entry in devices.entries) {
        if (!entry.key.contains('SimRuntime.$platform-')) continue;
        for (final candidate in entry.value as List<dynamic>) {
          final device = candidate as Map<String, dynamic>;
          if (device['udid'] == id &&
              device['isAvailable'] == true &&
              device['state'] == 'Booted') {
            return;
          }
        }
      }
      throw StateError('$id must be an available, booted $platform simulator.');
    }

    requireBooted(phoneId, 'iOS');
    requireBooted(watchId, 'watchOS');
    final pairs =
        (jsonDecode(await _simctl(['list', 'pairs', '-j']))
                as Map<String, dynamic>)['pairs']
            as Map<String, dynamic>;
    final paired = pairs.values.any((dynamic candidate) {
      final pair = candidate as Map<String, dynamic>;
      return (pair['phone'] as Map<String, dynamic>)['udid'] == phoneId &&
          (pair['watch'] as Map<String, dynamic>)['udid'] == watchId;
    });
    if (!paired) throw StateError('The selected simulators are not paired.');
    final output = Directory(
      Platform.environment['PAIRED_WATCH_OUTPUT_DIR'] ??
          'build/paired-watch-e2e/${DateTime.now().millisecondsSinceEpoch}',
    );
    await output.create(recursive: true);
    return _WatchHost(phoneId, watchId, output);
  }

  Future<Map<String, Object?>> check(Map<String, dynamic> request) async {
    final name = request['name'] as String;
    if (!RegExp(r'^[a-z0-9-]+$').hasMatch(name)) {
      throw StateError('Invalid checkpoint name.');
    }
    try {
      if (request['mode'] == 'prepare') {
        if (request['phoneSimulatorId'] != phoneId ||
            request['isPhysicalDevice'] != false) {
          throw StateError(
            'The app must verify native simulator execution and the runner target.',
          );
        }
        _receivedSession = false;
        _lastObserved = {};
        // flutter drive installs the phone once before both scenarios. Install
        // its companion once too; repeated installation invalidates the Watch
        // accessibility connection even when the replacement UI is visible.
        if (_cachePath == null) {
          final watchApp = Directory(
            Platform.environment['PAIRED_WATCH_APP_PATH'] ??
                'build/ios/iphonesimulator/Runner.app/Watch/StrengthAppWatch Watch App.app',
          ).absolute;
          if (!await watchApp.exists()) {
            throw StateError('The built Watch simulator companion is missing.');
          }
          final identifier = await Process.run('/usr/bin/plutil', [
            '-extract',
            'CFBundleIdentifier',
            'raw',
            '-o',
            '-',
            '${watchApp.path}/Info.plist',
          ]).timeout(const Duration(seconds: 5));
          if (identifier.exitCode != 0 ||
              identifier.stdout.toString().trim() != _watchBundleId) {
            throw StateError(
              'The selected Watch app has an unexpected bundle ID.',
            );
          }
          await _simctl([
            'install',
            watchId,
            watchApp.path,
          ], timeout: const Duration(seconds: 60));
          await _simctl([
            'launch',
            '--terminate-running-process',
            watchId,
            _watchBundleId,
          ]);
          final container = await _simctl([
            'get_app_container',
            watchId,
            _watchBundleId,
            'data',
          ]);
          _cachePath = '$container/Library/Preferences/$_watchBundleId.plist';
        } else {
          await _simctl(['launch', watchId, _watchBundleId]);
        }
      } else if (request['mode'] == 'relaunch') {
        if (_cachePath == null) {
          throw StateError('Watch preparation is missing.');
        }
        await _simctl([
          'launch',
          '--terminate-running-process',
          watchId,
          _watchBundleId,
        ]);
      } else {
        if (_cachePath == null) {
          throw StateError('Watch preparation is missing.');
        }
        await _expectReceipt(request);
        await _expectVisibleUI(request);
        await _expectAuthorizationSettled();
        await File(
          '${output.path}/$name-receipt.json',
        ).writeAsString(jsonEncode(_lastObserved));
        await _simctl([
          'io',
          watchId,
          'screenshot',
          '${output.absolute.path}/$name-watch.png',
        ]);
        await _simctl([
          'io',
          phoneId,
          'screenshot',
          '${output.absolute.path}/$name-phone.png',
        ]);
      }
      return {'name': name, 'ok': true, 'detail': 'verified'};
    } catch (error) {
      await File('${output.path}/$name-last-observed.json').writeAsString(
        const JsonEncoder.withIndent('  ').convert(_lastObserved),
      );
      // Screenshots are diagnostic artifacts, never substitutes for receipt.
      try {
        await _simctl([
          'io',
          watchId,
          'screenshot',
          '${output.absolute.path}/$name-failed.png',
        ]);
      } catch (_) {
        // Preserve the original assertion/setup error if capture also fails.
      }
      return {
        'name': name,
        'ok': false,
        'detail': error.toString(),
        'lastObserved': _lastObserved,
      };
    }
  }

  Future<void> _expectVisibleUI(Map<String, dynamic> request) async {
    final expectedText = request['expectedVisibleText'];
    if (expectedText is! String || expectedText.trim().isEmpty) {
      throw StateError('The checkpoint must declare its expected Watch UI.');
    }
    final process = await Process.start('python3', [
      'tool/ci/resolve_watch_permissions.py',
      '--udid',
      watchId,
      '--expected-exercise',
      expectedText,
      '--output-dir',
      '${output.absolute.path}/${request['name']}-ui',
      '--timeout',
      '60',
    ]);
    final standardOutput = process.stdout.transform(utf8.decoder).join();
    final standardError = process.stderr.transform(utf8.decoder).join();
    final status = await process.exitCode.timeout(
      const Duration(seconds: 75),
      onTimeout: () {
        process.kill(ProcessSignal.sigkill);
        throw TimeoutException('Watch UI helper exceeded 75 seconds.');
      },
    );
    final outputText = await standardOutput;
    final errorText = await standardError;
    await File(
      '${output.path}/${request['name']}-ui.log',
    ).writeAsString('$outputText$errorText');
    if (status != 0) {
      throw StateError(
        'Watch UI verification failed ($status): $outputText$errorText',
      );
    }
    _lastObserved['visibleText'] = expectedText;
  }

  Future<void> _expectAuthorizationSettled() async {
    // A dismissed system dialog can precede the persisted authorization update,
    // especially while a fresh simulator is finishing its first-run setup.
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    do {
      final preferences = await _readPreferences();
      final status = preferences['healthAuthorization'];
      final pending = preferences['healthAuthorizationPending'];
      _lastObserved['healthAuthorization'] = status;
      _lastObserved['healthAuthorizationPending'] = pending;
      // Health is optional. Both a real denial and a real grant must leave
      // transport and the workout UI working, with no pending permission flow.
      if ((status == 1 || status == 2) && pending == false) return;
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } while (DateTime.now().isBefore(deadline));
    throw StateError('Watch Health authorization has not settled.');
  }

  Future<void> _expectReceipt(Map<String, dynamic> request) async {
    final idle = request['mode'] == 'idle';
    if (!idle && request['mode'] != 'snapshot') {
      throw StateError('Unsupported Watch checkpoint mode.');
    }
    if (idle && !_receivedSession) {
      throw StateError('Idle cannot pass before this run receives a session.');
    }
    final expected = idle ? null : request['expected'] as Map<String, dynamic>;
    final stableFor = Duration(
      seconds: request['stableForSeconds'] as int? ?? 0,
    );
    final deadline = DateTime.now().add(const Duration(seconds: 25));
    DateTime? matchedAt;
    Map<String, Object?>? lastSummary;
    do {
      final preferences = await _readPreferences();
      final snapshot = preferences['snapshot'] as Map<String, dynamic>?;
      final summary = snapshot == null ? null : _summary(snapshot);
      lastSummary = summary;
      _lastObserved = {
        ...?summary,
        if (summary == null) 'cache': 'idle or absent',
        'healthAuthorization': preferences['healthAuthorization'],
        'healthAuthorizationPending': preferences['healthAuthorizationPending'],
      };
      final observedID = _lastObserved['sessionId'];
      if (observedID is String && !observedID.startsWith('paired-watch-')) {
        _lastObserved['sessionId'] = 'another session';
      }
      final matches = idle
          ? snapshot == null
          : summary != null &&
                expected!.entries.every(
                  (entry) => summary[entry.key] == entry.value,
                );
      if (matches) {
        matchedAt ??= DateTime.now();
        if (DateTime.now().difference(matchedAt) >= stableFor) {
          _receivedSession |= !idle;
          await File(
            '${output.path}/${request['name']}-receipt.json',
          ).writeAsString(jsonEncode(_lastObserved));
          return;
        }
      } else if (matchedAt != null) {
        throw StateError(
          'Watch state changed during the required stability window.',
        );
      }
      await Future<void>.delayed(const Duration(milliseconds: 200));
    } while (DateTime.now().isBefore(deadline));
    final observed = lastSummary == null
        ? 'idle/missing cache'
        : 'different state';
    throw StateError(
      'No matching Watch receipt within 25 seconds ($observed).',
    );
  }

  Future<Map<String, dynamic>> _readPreferences() async {
    // Read one coherent plist and distinguish a not-yet-delivered snapshot
    // from malformed data without depending on plutil's diagnostic wording.
    final result = await Process.run('python3', [
      'tool/ci/read_watch_preferences.py',
      _cachePath!,
    ]).timeout(const Duration(seconds: 5));
    if (result.exitCode != 0) {
      throw StateError(
        'Cannot read Watch preferences (${result.exitCode}): '
        '${result.stderr.toString().trim()}',
      );
    }
    return jsonDecode(result.stdout.toString()) as Map<String, dynamic>;
  }

  static Map<String, Object?> _summary(Map<String, dynamic> snapshot) {
    final exercises = snapshot['exercises'] as List<dynamic>;
    return {
      'sessionId': snapshot['sessionId'],
      'currentExerciseIndex': snapshot['currentExerciseIndex'],
      'exerciseCount': exercises.length,
      'firstExerciseCompletedSets': exercises.isEmpty
          ? 0
          : ((exercises.first as Map<String, dynamic>)['completedSets'] as List)
                .length,
      'locale': snapshot['locale'],
      'unit': snapshot['unit'],
    };
  }
}

String _simulatorId(String variable) {
  final value = Platform.environment[variable] ?? '';
  if (!RegExp(
    r'^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$',
  ).hasMatch(value)) {
    throw StateError('$variable must contain an explicit simulator UDID.');
  }
  return value;
}

Future<String> _simctl(
  List<String> arguments, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final process = await Process.start('xcrun', ['simctl', ...arguments]);
  final standardOutput = process.stdout.transform(utf8.decoder).join();
  final standardError = process.stderr.transform(utf8.decoder).join();
  final status = await process.exitCode.timeout(
    timeout,
    onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      throw TimeoutException('simctl ${arguments.first} timed out.', timeout);
    },
  );
  final outputText = await standardOutput;
  final errorText = await standardError;
  if (status != 0) {
    throw StateError('simctl ${arguments.first} failed: $errorText');
  }
  return outputText.trim();
}
