import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/features/auth/invite_access.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<
    ({
      ProviderContainer container,
      _Auth auth,
      _Factory factory,
      AccountContext first,
    })
  >
  setup() async {
    SharedPreferences.setMockInitialValues({});
    final factory = _Factory(await SharedPreferences.getInstance());
    final auth = _Auth()..user = _User('A');
    final first = await factory.open(auth.user);
    final container = ProviderContainer(
      overrides: [
        appStateRepositoryProvider.overrideWithValue(first.repository),
        trainingEngineStateRepositoryProvider.overrideWithValue(
          first.engineRepository,
        ),
        initialAppStateProvider.overrideWithValue(first.state),
        accountRepositoryFactoryProvider.overrideWithValue(factory),
        authServiceProvider.overrideWithValue(auth),
        accountAccessAvailableProvider.overrideWith((ref) => true),
        boundAccountIdProvider.overrideWith((ref) => 'A'),
      ],
    );
    addTearDown(container.dispose);
    return (container: container, auth: auth, factory: factory, first: first);
  }

  test(
    'denied account switch detaches old data and preserves it durably',
    () async {
      final fixture = await setup();
      fixture.factory.denied = 'B';
      final app = fixture.container.read(appStateControllerProvider.notifier);
      app.updateState((state) => state.copyWith(userName: 'A durable edit'));
      await app.flushLocal();
      await expectLater(
        fixture.container.read(accountSessionControllerProvider).signIn(
          () async {
            return fixture.auth.user = _User('B');
          },
        ),
        throwsA(isA<InviteAccessDeniedException>()),
      );
      expect(fixture.auth.currentUser, isNull);
      expect(fixture.container.read(boundAccountIdProvider), isNull);
      expect(fixture.container.read(accountAccessAvailableProvider), isFalse);
      expect(
        fixture.container.read(appStateControllerProvider).userName,
        isEmpty,
      );
      expect(
        (await AccountAppStateRepository(
          preferences: fixture.factory.preferences,
          accountId: 'A',
        ).load()).userName,
        'A durable edit',
      );
      app.updateState((state) => state.copyWith(userName: 'Guest edit'));
      await app.flushLocal();
      expect(
        (await AccountAppStateRepository(
          preferences: fixture.factory.preferences,
          accountId: null,
        ).load()).userName,
        'Guest edit',
      );
      expect(
        (await AccountAppStateRepository(
          preferences: fixture.factory.preferences,
          accountId: 'B',
        ).load()).userName,
        isEmpty,
      );
    },
  );

  test(
    'provider cancellation retains the current account and repository',
    () async {
      final fixture = await setup();
      await expectLater(
        fixture.container.read(accountSessionControllerProvider).signIn(
          () async {
            throw const AuthOperationCancelled();
          },
        ),
        throwsA(isA<AuthOperationCancelled>()),
      );
      expect(fixture.auth.currentUser!.uid, 'A');
      expect(
        fixture.container.read(appStateControllerProvider.notifier).repository,
        same(fixture.first.repository),
      );
      expect(fixture.container.read(appStateControllerProvider).userName, 'A');
    },
  );

  test('revoked admission for the same identity is also detached', () async {
    final fixture = await setup();
    fixture.factory.denied = 'A';
    await expectLater(
      fixture.container
          .read(accountSessionControllerProvider)
          .signIn(() async => fixture.auth.user!),
      throwsA(isA<InviteAccessDeniedException>()),
    );
    expect(fixture.auth.currentUser, isNull);
    expect(fixture.container.read(accountAccessAvailableProvider), isFalse);
  });
  test(
    'synchronous state listeners see the new account engine and identity together',
    () async {
      final fixture = await setup();
      final observed = <String?>[];
      final correctEngine = <bool>[];
      fixture.container.listen(appStateControllerProvider, (previous, next) {
        if (next.userName == 'B') {
          observed.add(fixture.container.read(boundAccountIdProvider));
          correctEngine.add(
            identical(
              fixture.container.read(
                activeTrainingEngineStateRepositoryProvider,
              ),
              fixture.factory.opened['B']!.engineRepository,
            ),
          );
        }
      });
      await fixture.container
          .read(accountSessionControllerProvider)
          .signIn(() async => fixture.auth.user = _User('B'));
      expect(observed, ['B']);
      expect(correctEngine, [true]);
    },
  );
}

class _Auth extends AuthService {
  _Auth() : super(null);
  User? user;
  @override
  User? get currentUser => user;
  @override
  Future<void> signOut() async {
    user = null;
  }
}

class _User implements User {
  _User(this.uid);
  @override
  final String uid;
  @override
  String get email => '$uid@example.invalid';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Factory extends AccountRepositoryFactory {
  _Factory(SharedPreferences preferences) : super(preferences: preferences);
  String? denied;
  final opened = <String?, AccountContext>{};
  @override
  Future<AccountContext> open(User? user, {bool requireOnline = false}) async {
    if (user != null && user.uid == denied) {
      throw InviteAccessDeniedException(user.email!);
    }
    final repo = AccountAppStateRepository(
      preferences: preferences,
      accountId: user?.uid,
      remote: user == null
          ? null
          : MemoryAppStateRepository(
              initialState: AppState.empty().copyWith(userName: user.uid),
            ),
    );
    return opened[user?.uid] = AccountContext(
      repository: repo,
      engineRepository: MemoryTrainingEngineStateRepository(),
      state: await repo.load(),
      accessAvailable: user != null,
    );
  }
}
