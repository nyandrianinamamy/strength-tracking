import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/app/app.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';

/// Mounts the production app shell. [start] uses isolated auth and the real local
/// repository; [fromBootstrap] preserves the production bootstrap container.
/// Neither invokes main() or its Watch/Live Activity service startup.
class IosTestApp {
  IosTestApp._(this.preferences, this.authService, {this.bootstrap});

  final SharedPreferences preferences;
  final AuthService authService;
  final AppBootstrapResult? bootstrap;
  ProviderContainer? _container;

  ProviderContainer get container => _container!;
  AppState get state => container.read(appStateControllerProvider);
  AppStateRepository get repository =>
      bootstrap?.repository ?? SharedPreferencesAppStateRepository(preferences);

  static Future<IosTestApp> start(
    WidgetTester tester,
    AppState initialState, {
    bool signedIn = true,
    AuthService? authService,
  }) async {
    final preferences = await SharedPreferences.getInstance();
    final app = IosTestApp._(
      preferences,
      authService ?? _IsolatedAuth(signedIn),
    );
    // The entrypoint sets a test-only prefix before loading preferences.
    await preferences.clear();
    await app.repository.save(
      initialState.copyWith(preferredLanguage: 'en', healthKitEnabled: false),
    );
    await app.mount(tester);
    return app;
  }

  /// Mounts the exact production bootstrap container, without replacing its
  /// auth, repository selection, initial state, or training-engine repository.
  static Future<IosTestApp> fromBootstrap(
    WidgetTester tester,
    AppBootstrapResult result,
  ) async {
    final app = IosTestApp._(
      await SharedPreferences.getInstance(),
      AuthService(result.auth),
      bootstrap: result,
    );
    await app.mount(tester);
    return app;
  }

  Future<void> mount(WidgetTester tester) async {
    await preferences.reload();
    _container = bootstrap != null
        ? buildContainer(bootstrap!)
        : ProviderContainer(
            overrides: [
              appStateRepositoryProvider.overrideWithValue(repository),
              initialAppStateProvider.overrideWithValue(
                await repository.load(),
              ),
              trainingEngineStateRepositoryProvider.overrideWithValue(
                SharedPreferencesTrainingEngineStateRepository(preferences),
              ),
              authServiceProvider.overrideWithValue(authService),
              accountAccessAvailableProvider.overrideWith(
                (ref) => authService.currentUser != null,
              ),
            ],
          );
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const StrengthTrainingApp(),
      ),
    );
    await uiFrames(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox.shrink());
    _container?.dispose();
    _container = null;
    await tester.pump();
  }

  /// Rebuilds providers and reloads native storage; this is not a process kill.
  Future<void> restart(WidgetTester tester) async {
    if (bootstrap != null) {
      throw StateError(
        'Re-run initializeApp to restart a bootstrap-backed app.',
      );
    }
    await expectPersisted(
      tester,
      (saved) => saved.toJson().toString() == state.toJson().toString(),
    );
    await unmount(tester);
    await mount(tester);
  }

  Future<void> expectPersisted(
    WidgetTester tester,
    bool Function(AppState) predicate,
  ) async {
    for (var attempt = 0; attempt < 60; attempt++) {
      await preferences.reload();
      if (predicate(await repository.load())) return;
      await tester.pump(const Duration(milliseconds: 100));
    }
    fail('Expected state was not persisted by the app within 6 seconds.');
  }
}

class _IsolatedAuth implements AuthService {
  _IsolatedAuth(this.signedIn);
  final bool signedIn;

  @override
  User? get currentUser => signedIn ? _FixtureUser() : null;
  @override
  Stream<User?> authStateChanges() => Stream.value(currentUser);
  @override
  Future<void> signOut() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'External auth is excluded from the isolated iOS UI suite: '
    '${invocation.memberName}',
  );
}

class _FixtureUser implements User {
  @override
  String get uid => 'ios-e2e-fixture';
  @override
  String get email => 'ios-e2e@example.invalid';
  @override
  String? get displayName => 'iOS E2E';
  @override
  List<UserInfo> get providerData => const [];
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected identity property: ${invocation.memberName}',
  );
}

Future<void> uiFrames(WidgetTester tester) async {
  // Workout timers never settle. Every subsequent action asserts its target.
  for (var i = 0; i < 4; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> waitForUi(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 100; i++) {
    if (target.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    target,
    findsWidgets,
    reason: 'UI target did not appear in 10 seconds',
  );
}

Future<void> waitForUiToDisappear(WidgetTester tester, Finder target) async {
  for (var i = 0; i < 100; i++) {
    if (target.evaluate().isEmpty) return;
    await tester.pump(const Duration(milliseconds: 100));
  }
  expect(
    target,
    findsNothing,
    reason: 'UI target did not disappear in 10 seconds',
  );
}

Future<Finder> revealUi(WidgetTester tester, Finder target) async {
  FocusManager.instance.primaryFocus?.unfocus();
  await uiFrames(tester);
  for (var i = 0; i < 20; i++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target.first);
      await uiFrames(tester);
      final hittable = target.hitTestable();
      if (hittable.evaluate().isNotEmpty) {
        expect(
          hittable,
          findsOneWidget,
          reason:
              'Scope an ambiguous UI target to the intended screen or control',
        );
        return hittable;
      }
    }
    final scrollables = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          widget.physics?.allowUserScrolling != false &&
          (widget.axisDirection == AxisDirection.down ||
              widget.axisDirection == AxisDirection.up),
    );
    expect(
      scrollables.hitTestable(),
      findsWidgets,
      reason: 'Cannot reveal offscreen target $target',
    );
    await tester.drag(scrollables.hitTestable().first, const Offset(0, -250));
    await uiFrames(tester);
  }
  fail('UI target is missing or cannot be hit: $target');
}

Future<void> tapUi(WidgetTester tester, Finder target) async {
  final visible = await revealUi(tester, target);
  await tester.tap(visible);
  await uiFrames(tester);
}

Future<void> enterUi(WidgetTester tester, Finder target, String value) async {
  final visible = await revealUi(tester, target);
  await tester.enterText(visible, value);
  FocusManager.instance.primaryFocus?.unfocus();
  await uiFrames(tester);
}

Future<void> tabUi(WidgetTester tester, String label) => tapUi(
  tester,
  find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
);

Future<void> logStrengthUi(
  WidgetTester tester,
  String weight,
  String reps,
) async {
  await enterUi(
    tester,
    find.byKey(const ValueKey('active-workout-weight-input')),
    weight,
  );
  await enterUi(
    tester,
    find.byKey(const ValueKey('active-workout-reps-input')),
    reps,
  );
  await tapUi(
    tester,
    find.byKey(const ValueKey('active-workout-log-set-button')),
  );
  await waitForUi(tester, find.text('Save & Log Set'));
  await tapUi(tester, find.text('Save & Log Set'));
}

Future<void> finishUi(WidgetTester tester) async {
  await tapUi(tester, find.text('FINISH'));
  await tapUi(tester, find.text('Finish & Save'));
  await revealUi(tester, find.text('Finish & Go Home'));
}
