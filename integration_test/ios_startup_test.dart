import 'dart:async';
import 'dart:ui' as ui;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/main.dart' as application;
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/shared/widgets/app_loading_screen.dart';

import 'ios_app_helpers.dart';
import 'ios_auth_helpers.dart';

/// Exercises the entry path called by main(), including its loading UI, font
/// license, production container and native service initialization. Firebase
/// failure below is injected; it does not claim an operating-system outage.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  SharedPreferences.setPrefix('kotrana_ios_startup_e2e.');

  setUpAll(() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        !const bool.fromEnvironment('E2E_DISPOSABLE_SIMULATOR')) {
      throw UnsupportedError(
        'Run startup acceptance on a disposable iOS simulator.',
      );
    }
    final device = await const MethodChannel(
      'dev.fluttercommunity.plus/device_info',
    ).invokeMapMethod<String, dynamic>('getDeviceInfo');
    expect(device?['isPhysicalDevice'], isFalse);
  });

  testWidgets(
    'launch loading UI survives injected Firebase initialization failure',
    (tester) async {
      final preferences = await SharedPreferences.getInstance();
      await preferences.clear();
      await AccountAppStateRepository(
        preferences: preferences,
        accountId: null,
      ).save(
        AppState.empty().copyWith(
          userName: 'Offline Startup Athlete',
          preferredLanguage: 'en',
        ),
      );
      final trace = _NativeStartupTrace()..start();
      ProviderContainer? container;
      addTearDown(() => _unmount(tester, container, trace));
      final continueStartup = Completer<void>();
      final launching = application.launchKotranaApp(
        firebaseInitializer: () async {
          await continueStartup.future;
          throw StateError('Injected Firebase initialization failure');
        },
      );
      await waitForUi(tester, find.byType(AppLoadingScreen));
      expect(find.text('Preparing your training space...'), findsOneWidget);
      continueStartup.complete();
      container = await launching;
      await waitForUi(tester, find.text('Offline Startup Athlete'));
      expect(container.read(authServiceProvider).isAvailable, isFalse);
      final repository =
          container.read(appStateControllerProvider.notifier).repository
              as AccountAppStateRepository;
      expect(repository.accountId, isNull);
      expect(repository.remote, isNull);
      expect(
        container.read(appStateControllerProvider).userName,
        'Offline Startup Athlete',
      );
      await trace.expectInitialized(tester);

      final licenses = await LicenseRegistry.licenses.toList();
      expect(
        licenses.any(
          (license) =>
              license.packages.contains('Lexend') &&
              license.paragraphs.any(
                (paragraph) => paragraph.text.contains('SIL OPEN FONT LICENSE'),
              ),
        ),
        isTrue,
        reason: 'The actual launch path must retain the bundled font license.',
      );
    },
  );

  testWidgets(
    'launch invitation gate, email login and profile use real repositories',
    (tester) async {
      final connected = await connectInviteEmulators();
      final auth = connected.auth;
      final firestore = connected.firestore;
      await firestore.enableNetwork();
      await resetInviteEmulators(auth);
      await (await SharedPreferences.getInstance()).clear();
      const email = 'startup@example.invalid';
      final accountId = await createInviteAccount(auth, email, allowed: true);
      await auth.signOut();

      final trace = _NativeStartupTrace()..start();
      ProviderContainer? container;
      addTearDown(() async {
        await _unmount(tester, container, trace);
        await auth.signOut();
      });
      final continueStartup = Completer<void>();
      final launching = application.launchKotranaApp(
        firebaseOptions: inviteTestOptions,
        auth: auth,
        firestore: firestore,
        firebaseInitializer: () => continueStartup.future,
      );
      await waitForUi(tester, find.byType(AppLoadingScreen));
      continueStartup.complete();
      container = await launching;
      await waitForUi(tester, find.text("Let's Get Started"));
      expect(find.textContaining('invite-only'), findsWidgets);
      expect(find.widgetWithText(TextField, 'Your name'), findsNothing);
      expect(container.read(accountAccessAvailableProvider), isFalse);
      final initial =
          container.read(appStateControllerProvider.notifier).repository
              as AccountAppStateRepository;
      expect(initial.accountId, isNull);
      expect(initial.remote, isNull);
      await trace.expectInitialized(tester);

      await enterUi(tester, find.widgetWithText(TextField, 'Email'), email);
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Password'),
        inviteTestPassword,
      );
      await tapUi(tester, find.text('Sign in with Email'));
      await waitForUi(tester, find.widgetWithText(TextField, 'Your name'));
      expect(auth.currentUser?.uid, accountId);
      expect(container.read(accountAccessAvailableProvider), isTrue);
      final account =
          container.read(appStateControllerProvider.notifier).repository
              as AccountAppStateRepository;
      expect(account.accountId, accountId);
      expect(account.remote, isA<FirestoreAppStateRepository>());

      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Your name'),
        'Startup Athlete',
      );
      await tapUi(
        tester,
        find.widgetWithText(FilledButton, 'Next').hitTestable(),
      );
      await waitForUi(tester, find.text('About You'));
      await tapUi(
        tester,
        find.widgetWithText(FilledButton, 'Next').hitTestable(),
      );
      await waitForUi(tester, find.text('Choose Your Unit'));
      await tapUi(tester, find.text('Start Training'));
      await waitForUi(tester, find.text('Startup Athlete'));
      await container.read(appStateControllerProvider.notifier).retrySave();
      final saved = await firestore
          .doc('users/$accountId/data/state')
          .get(const GetOptions(source: Source.server));
      expect(saved.data()?['userName'], 'Startup Athlete');
      expect(trace.errors, isEmpty);
    },
  );
}

Future<void> _unmount(
  WidgetTester tester,
  ProviderContainer? container,
  _NativeStartupTrace trace,
) async {
  await tester.pumpWidget(const SizedBox.shrink());
  container?.dispose();
  await uiFrames(tester);
  trace.stop();
}

/// Observe successful native replies while forwarding the original bytes to
/// the engine. No reply, service, native handler or event stream is mocked.
class _NativeStartupTrace {
  static const channels = [
    'com.strengthapp/watch',
    'com.strengthapp/watch_events',
    'com.strengthapp/live_activity',
  ];
  final calls = <String>[];
  final errors = <Object>[];

  void start() {
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, (message) async {
            const codec = StandardMethodCodec();
            final call = codec.decodeMethodCall(message);
            final reply = Completer<ByteData?>();
            ui.PlatformDispatcher.instance.sendPlatformMessage(
              channel,
              message,
              reply.complete,
            );
            final response = await reply.future.timeout(
              const Duration(seconds: 10),
            );
            try {
              if (response == null) throw MissingPluginException(channel);
              codec.decodeEnvelope(response);
              calls.add('$channel/${call.method}');
            } catch (error) {
              errors.add(error);
            }
            return response;
          });
    }
  }

  Future<void> expectInitialized(WidgetTester tester) async {
    const expected = [
      'com.strengthapp/watch_events/listen',
      'com.strengthapp/watch/sendSessionIdle',
      'com.strengthapp/live_activity/endWorkout',
    ];
    for (var attempt = 0; attempt < 100; attempt++) {
      if (expected.every(calls.contains) || errors.isNotEmpty) break;
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(errors, isEmpty);
    expect(
      calls,
      containsAll(expected),
      reason: 'main must initialize both native services.',
    );
  }

  void stop() {
    for (final channel in channels) {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMessageHandler(channel, null);
    }
  }
}
