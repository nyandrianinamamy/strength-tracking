import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';

import 'ios_app_helpers.dart';
import 'ios_auth_helpers.dart';
import 'ios_fixtures.dart';

void main() {
  final binding = _PersistenceBinding();
  WidgetController.hitTestWarningShouldBeFatal = true;
  SharedPreferences.setPrefix('kotrana_ios_process_restart.');

  testWidgets('durable workout across a terminated app process', (
    tester,
  ) async {
    final phase = await binding.phase.future.timeout(
      const Duration(seconds: 60),
    );
    binding.reportData = {'phase': phase};
    expect(defaultTargetPlatform, TargetPlatform.iOS);
    expect(kIsWeb, isFalse);
    expect(const bool.fromEnvironment('E2E_DISPOSABLE_SIMULATOR'), isTrue);
    expect(
      ['write', 'read'],
      contains(phase),
      reason: 'The host must select write then read on the same built app',
    );
    final connected = await connectInviteEmulators();
    final auth = connected.auth;
    final firestore = connected.firestore;
    final preferences = await SharedPreferences.getInstance();

    if (phase == 'write') {
      await resetInviteEmulators(auth);
      await preferences.clear();
      final uid = await createInviteAccount(
        auth,
        'restart@example.invalid',
        allowed: true,
      );
      final cloud = FirestoreAppStateRepository(
        auth: auth,
        firestore: firestore,
      );
      await cloud.save(
        e2eRichState(
          userName: 'Restart Athlete',
          includeActiveSession: true,
          includeCompletedSessions: false,
        ),
      );
      final result = await initializeApp(
        auth: auth,
        firestore: firestore,
        firebaseOptions: inviteTestOptions,
      );
      final app = await IosTestApp.fromBootstrap(tester, result);
      addTearDown(() => app.unmount(tester));
      await waitForUi(tester, find.text('Restart Athlete'));
      expect(await preferences.setString('expected_uid', uid), isTrue);
      expect(
        await preferences.setString(
          'expected_session',
          app.state.activeSession!.id,
        ),
        isTrue,
      );
      await firestore.disableNetwork();
      await tapUi(tester, find.text('RESUME SESSION'));
      await logStrengthUi(tester, '85', '6');
      final controller = app.container.read(
        appStateControllerProvider.notifier,
      );
      await controller.flushLocal();
      await controller.retrySave();
      final repository = controller.repository as AccountAppStateRepository;
      expect(repository.hasPendingChanges, isTrue);
      expect(
        repository.currentState.activeSession!.completedSets.single.weightKg,
        85,
      );
      expect(preferences.getString(repository.storageKey), contains('85.0'));
      // The host ends this process. No cloud write or manual identity injection
      // is allowed between this checkpoint and the read invocation.
    } else {
      // Deliberately do not seed accounts, clear preferences, or sign in here.
      final expectedUid = preferences.getString('expected_uid');
      final expectedSession = preferences.getString('expected_session');
      expect(
        expectedUid,
        isNotNull,
        reason: 'The write process sandbox must survive',
      );
      expect(expectedSession, isNotNull);
      expect(
        auth.currentUser?.uid,
        expectedUid,
        reason: 'Firebase identity must survive process termination',
      );
      await firestore.enableNetwork();
      final result = await initializeApp(
        auth: auth,
        firestore: firestore,
        firebaseOptions: inviteTestOptions,
      );
      final app = await IosTestApp.fromBootstrap(tester, result);
      addTearDown(() => app.unmount(tester));
      expect(app.state.activeSession!.id, expectedSession);
      expect(app.state.activeSession!.completedSets.single.weightKg, 85);
      expect(app.state.activeSession!.completedSets.single.reps, 6);
      await tapUi(tester, find.text('RESUME SESSION'));
      await revealUi(tester, find.textContaining(RegExp(r'^Set 1: 85')));
      final saved = await FirestoreAppStateRepository(
        auth: auth,
        firestore: firestore,
      ).load();
      expect(saved.activeSession!.id, expectedSession);
      expect(saved.activeSession!.completedSets.single.weightKg, 85);
      expect(
        (result.repository as AccountAppStateRepository).hasPendingChanges,
        isFalse,
      );
    }
  });
}

/// Select a phase at runtime so both fresh processes run the exact same binary.
class _PersistenceBinding extends IntegrationTestWidgetsFlutterBinding {
  final phase = Completer<String>();

  @override
  Future<Map<String, dynamic>> callback(Map<String, String> params) async {
    final message = params['message'];
    if (params['command'] != 'request_data' ||
        message == null ||
        !message.startsWith('persistence:phase:')) {
      return super.callback(params);
    }
    final selected = message.substring('persistence:phase:'.length);
    if (phase.isCompleted || !['write', 'read'].contains(selected)) {
      throw StateError('Invalid or duplicate persistence phase.');
    }
    phase.complete(selected);
    return {
      'isError': false,
      'response': {'message': selected},
    };
  }
}
