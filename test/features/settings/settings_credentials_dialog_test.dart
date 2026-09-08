import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/features/settings/settings_screen.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_provider.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';

void main() {
  Future<_Auth> showSettings(WidgetTester tester) async {
    tester.view.physicalSize = const Size(900, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Kotrana',
      packageName: 'dev.mamy-r.kotrana',
      version: '1.0.31',
      buildNumber: '309',
      buildSignature: '',
    );
    final state = AppState.empty().copyWith(userName: 'Account owner');
    final repository = AccountAppStateRepository(
      preferences: await SharedPreferences.getInstance(),
      accountId: 'dialog-test',
      remote: MemoryAppStateRepository(initialState: state),
    );
    await repository.load();
    final auth = _Auth();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStateRepositoryProvider.overrideWithValue(repository),
          initialAppStateProvider.overrideWithValue(state),
          trainingEngineStateRepositoryProvider.overrideWithValue(
            MemoryTrainingEngineStateRepository(),
          ),
          authServiceProvider.overrideWithValue(auth),
          boundAccountIdProvider.overrideWith((ref) => 'dialog-test'),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const SettingsScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return auth;
  }

  for (final submit in [false, true]) {
    testWidgets(
      'email dialog ${submit ? 'submits' : 'cancels'} through its closing animation',
      (tester) async {
        await showSettings(tester);
        await tester.ensureVisible(find.text('Sign in with Email'));
        await tester.tap(find.text('Sign in with Email'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextField, 'Email'),
          'account@example.invalid',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'dialog-password',
        );
        await tester.tap(
          find.widgetWithText(TextButton, submit ? 'Switch' : 'Cancel'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (submit) {
          expect(find.text('Switch Account?'), findsOneWidget);
          await tester.tap(find.widgetWithText(TextButton, 'Cancel'));
          await tester.pumpAndSettle();
        }
        expect(find.widgetWithText(TextField, 'Password'), findsNothing);
      },
    );

    testWidgets(
      'deletion password ${submit ? 'submits' : 'cancels'} through its closing animation',
      (tester) async {
        final auth = await showSettings(tester);
        await tester.ensureVisible(find.text('Delete Account'));
        await tester.tap(find.text('Delete Account'));
        await tester.pumpAndSettle();
        await tester.tap(find.widgetWithText(TextButton, 'Delete Account'));
        await tester.pumpAndSettle();
        expect(
          find.text('Sign in again to delete this account.'),
          findsOneWidget,
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Password'),
          'dialog-password',
        );
        await tester.tap(
          find.widgetWithText(TextButton, submit ? 'Delete Account' : 'Cancel'),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        expect(
          auth.reauthenticationPassword,
          submit ? 'dialog-password' : isNull,
        );
        expect(find.widgetWithText(TextField, 'Password'), findsNothing);
        expect(find.text('Account owner'), findsWidgets);
      },
    );
  }
}

class _Auth extends AuthService {
  _Auth() : super(null);
  String? reauthenticationPassword;
  @override
  User get currentUser => _User();
  @override
  String get currentProviderId => 'password';
  @override
  Future<void> reauthenticateWithEmailPassword(String password) async {
    reauthenticationPassword = password;
    throw const AuthOperationCancelled();
  }
}

class _User implements User {
  @override
  String get uid => 'dialog-test';
  @override
  String get email => 'account@example.invalid';
  @override
  String get displayName => 'Account owner';
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
