import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';

import 'ios_app_helpers.dart';
import 'ios_auth_helpers.dart';

void main() => registerTests();

void registerTests({bool configurePreferences = true}) {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  WidgetController.hitTestWarningShouldBeFatal = true;
  if (configurePreferences) {
    SharedPreferences.setPrefix('kotrana_ios_invite_e2e.');
  }
  late FirebaseAuth auth;
  late FirebaseFirestore firestore;

  setUpAll(() async {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        !const bool.fromEnvironment('E2E_DISPOSABLE_SIMULATOR')) {
      throw UnsupportedError(
        'Use run_ios_e2e.sh --with-auth on a disposable simulator.',
      );
    }
    final connected = await connectInviteEmulators();
    auth = connected.auth;
    firestore = connected.firestore;
  });

  setUp(() async {
    await firestore.enableNetwork();
    await resetInviteEmulators(auth);
    await (await SharedPreferences.getInstance()).clear();
  });

  Future<IosTestApp> bootUi(
    WidgetTester tester, {
    bool signedIn = false,
  }) async {
    final result = await initializeApp(
      firestore: firestore,
      auth: auth,
      firebaseOptions: inviteTestOptions,
    );
    expect(result.repository, isA<AccountAppStateRepository>());
    final repository = result.repository as AccountAppStateRepository;
    expect(repository.accountId, signedIn ? auth.currentUser!.uid : null);
    expect(
      repository.remote,
      signedIn ? isA<FirestoreAppStateRepository>() : isNull,
    );
    return IosTestApp.fromBootstrap(tester, result);
  }

  Future<String> createAccount(String email, {bool? allowed}) =>
      createInviteAccount(auth, email, allowed: allowed);

  Future<void> signInUi(WidgetTester tester, String email) async {
    await enterUi(tester, find.widgetWithText(TextField, 'Email'), email);
    await enterUi(
      tester,
      find.widgetWithText(TextField, 'Password'),
      inviteTestPassword,
    );
    await tapUi(tester, find.text('Sign in with Email'));
  }

  for (final allowed in <bool?>[null, false]) {
    testWidgets(
      'email invitation ${allowed == null ? 'missing' : 'disabled'} is rejected',
      (tester) async {
        const email = 'denied@example.invalid';
        await createAccount(email, allowed: allowed);
        await auth.signOut();
        final app = await bootUi(tester);
        addTearDown(() => app.unmount(tester));
        await signInUi(tester, email);
        await waitForUi(tester, find.byType(SnackBar));
        expect(auth.currentUser, isNull);
        expect(app.state.userName, isEmpty);
        expect(find.text("Let's Get Started"), findsOneWidget);
        expect(find.textContaining('invite-only'), findsWidgets);
      },
    );
  }

  testWidgets('enabled invitation restores cloud state and saves later edits', (
    tester,
  ) async {
    const email = 'invited@example.invalid';
    await createAccount(email, allowed: true);
    final cloud = FirestoreAppStateRepository(auth: auth, firestore: firestore);
    await cloud.save(
      AppState.empty().copyWith(
        userName: 'Invited Athlete',
        preferredLanguage: 'en',
      ),
    );
    await auth.signOut();
    final app = await bootUi(tester);
    addTearDown(() => app.unmount(tester));
    await signInUi(tester, email);
    await waitForUi(tester, find.text('Invited Athlete'));
    expect(auth.currentUser!.email, email);
    await tapUi(tester, find.byIcon(Icons.settings_outlined));
    await enterUi(
      tester,
      find.widgetWithText(TextField, 'Your name'),
      'Cloud Edit',
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(app.state.userName, 'Cloud Edit');
    // A successful UI sign-in must also switch the long-lived repository.
    // Assert the production repository switched as part of the UI sign-in.
    await app.container.read(appStateControllerProvider.notifier).retrySave();
    expect(
      (await cloud.load()).userName,
      'Cloud Edit',
      reason:
          'Post-sign-in edits must persist to the signed-in cloud repository',
    );
  });

  testWidgets(
    'bootstrap with an invited signed-in user loads and saves cloud state',
    (tester) async {
      await createAccount('cold-boot@example.invalid', allowed: true);
      final cloud = FirestoreAppStateRepository(
        auth: auth,
        firestore: firestore,
      );
      await cloud.save(
        AppState.empty().copyWith(
          userName: 'Cold Boot Athlete',
          preferredLanguage: 'en',
        ),
      );
      final app = await bootUi(tester, signedIn: true);
      addTearDown(() => app.unmount(tester));
      await waitForUi(tester, find.text('Cold Boot Athlete'));
      await tapUi(tester, find.byIcon(Icons.settings_outlined));
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Your name'),
        'Saved On Boot',
      );
      await tester.pump(const Duration(milliseconds: 700));
      await app.container.read(appStateControllerProvider.notifier).retrySave();
      expect((await cloud.load()).userName, 'Saved On Boot');
    },
  );
  testWidgets(
    'denied switch signs out without losing the previous account cache',
    (tester) async {
      const firstEmail = 'first@example.invalid';
      final firstUid = await createAccount(firstEmail, allowed: true);
      final firstCloud = FirestoreAppStateRepository(
        auth: auth,
        firestore: firestore,
      );
      await firstCloud.save(
        AppState.empty().copyWith(
          userName: 'First Athlete',
          preferredLanguage: 'en',
        ),
      );
      await createAccount('blocked@example.invalid', allowed: false);
      await auth.signInWithEmailAndPassword(
        email: firstEmail,
        password: inviteTestPassword,
      );
      final app = await bootUi(tester, signedIn: true);
      addTearDown(() => app.unmount(tester));
      await tapUi(tester, find.byIcon(Icons.settings_outlined));
      await tapUi(tester, find.text('Sign in with Email'));
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Email'),
        'blocked@example.invalid',
      );
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Password'),
        inviteTestPassword,
      );
      await tapUi(tester, find.widgetWithText(TextButton, 'Switch'));
      await waitForUi(tester, find.text('Switch Account?'));
      await tapUi(tester, find.widgetWithText(TextButton, 'Switch'));
      await waitForUi(tester, find.byType(SnackBar));
      expect(auth.currentUser, isNull);
      expect(app.container.read(boundAccountIdProvider), isNull);
      expect(app.state.userName, isEmpty);
      final retained = AccountAppStateRepository(
        preferences: await SharedPreferences.getInstance(),
        accountId: firstUid,
      );
      expect((await retained.load()).userName, 'First Athlete');
    },
  );

  testWidgets(
    'cached offline edits survive bootstrap and reconcile when connected',
    (tester) async {
      await createAccount('offline@example.invalid', allowed: true);
      final cloud = FirestoreAppStateRepository(
        auth: auth,
        firestore: firestore,
      );
      await cloud.save(
        AppState.empty().copyWith(
          userName: 'Online Name',
          preferredLanguage: 'en',
        ),
      );
      final app = await bootUi(tester, signedIn: true);
      await tapUi(tester, find.byIcon(Icons.settings_outlined));
      await firestore.disableNetwork();
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Your name'),
        'Offline Name',
      );
      await app.container
          .read(appStateControllerProvider.notifier)
          .flushLocal();
      await app.container.read(appStateControllerProvider.notifier).retrySave();
      await app.unmount(tester);
      final restored = await bootUi(tester, signedIn: true);
      addTearDown(() => restored.unmount(tester));
      expect(restored.state.userName, 'Offline Name');
      expect(restored.container.read(accountAccessAvailableProvider), isTrue);
      await firestore.enableNetwork();
      await restored.container
          .read(appStateControllerProvider.notifier)
          .retrySave();
      expect((await cloud.load()).userName, 'Offline Name');
    },
  );

  testWidgets(
    'uncached offline bootstrap keeps the account gated until verified online',
    (tester) async {
      await createAccount('uncached@example.invalid', allowed: true);
      final cloud = FirestoreAppStateRepository(
        auth: auth,
        firestore: firestore,
      );
      await cloud.save(
        AppState.empty().copyWith(
          userName: 'Existing Cloud Data',
          preferredLanguage: 'en',
        ),
      );
      await firestore.disableNetwork();
      final app = await bootUi(tester, signedIn: true);
      addTearDown(() => app.unmount(tester));
      expect(app.container.read(accountAccessAvailableProvider), isFalse);
      expect(find.text('Next'), findsNothing);
      await firestore.enableNetwork();
      await app.container.read(appStateControllerProvider.notifier).retrySave();
      expect(app.container.read(accountAccessAvailableProvider), isTrue);
      expect(app.state.userName, 'Existing Cloud Data');
      await waitForUi(tester, find.byIcon(Icons.settings_outlined));
      await waitForUiToDisappear(tester, find.text("Let's Get Started"));
      expect((await cloud.load()).userName, 'Existing Cloud Data');
    },
  );

  testWidgets(
    'uncached empty account can complete profile setup after reconnect',
    (tester) async {
      await createAccount('uncached-new@example.invalid', allowed: true);
      await firestore.disableNetwork();
      final app = await bootUi(tester, signedIn: true);
      addTearDown(() => app.unmount(tester));
      expect(app.container.read(accountAccessAvailableProvider), isFalse);
      expect(find.text('Next'), findsNothing);
      await firestore.enableNetwork();
      await app.container.read(appStateControllerProvider.notifier).retrySave();
      await waitForUi(tester, find.text('Next'));
      await tapUi(tester, find.text('Next'));
      await waitForUi(tester, find.widgetWithText(TextField, 'Your name'));
      expect(app.container.read(accountAccessAvailableProvider), isTrue);
    },
  );

  testWidgets(
    'deletion cancellation preserves data; reauthentication deletes only the current account',
    (tester) async {
      final uid = await createAccount('delete@example.invalid', allowed: true);
      final cloud = FirestoreAppStateRepository(
        auth: auth,
        firestore: firestore,
      );
      await cloud.save(
        AppState.empty().copyWith(
          userName: 'Delete Fixture',
          preferredLanguage: 'en',
        ),
      );
      final app = await bootUi(tester, signedIn: true);
      addTearDown(() => app.unmount(tester));
      await tapUi(tester, find.byIcon(Icons.settings_outlined));
      await tapUi(tester, find.text('Delete Account'));
      await tapUi(tester, find.widgetWithText(TextButton, 'Delete Account'));
      await waitForUi(
        tester,
        find.text('Sign in again to delete this account.'),
      );
      await tapUi(tester, find.widgetWithText(TextButton, 'Cancel'));
      expect(auth.currentUser!.uid, uid);
      expect((await cloud.load()).userName, 'Delete Fixture');
      await tapUi(tester, find.text('Delete Account'));
      await tapUi(tester, find.widgetWithText(TextButton, 'Delete Account'));
      await enterUi(
        tester,
        find.widgetWithText(TextField, 'Password'),
        inviteTestPassword,
      );
      await tapUi(tester, find.widgetWithText(TextButton, 'Delete Account'));
      await waitForUi(tester, find.text("Let's Get Started"));
      expect(auth.currentUser, isNull);
      expect(app.container.read(boundAccountIdProvider), isNull);
      final preferences = await SharedPreferences.getInstance();
      expect(
        preferences.containsKey(
          AccountAppStateRepository(
            preferences: preferences,
            accountId: uid,
          ).storageKey,
        ),
        isFalse,
      );
    },
  );
}
