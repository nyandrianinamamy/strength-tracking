import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/app/router.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';

void main() {
  testWidgets(
    'online admission unlocks profile setup on the visible welcome page',
    (tester) async {
      final container = ProviderContainer(
        overrides: [
          initialAppStateProvider.overrideWithValue(AppState.empty()),
          appStateRepositoryProvider.overrideWithValue(
            MemoryAppStateRepository(initialState: AppState.empty()),
          ),
          authServiceProvider.overrideWithValue(_SignedInAuth()),
          accountAccessAvailableProvider.overrideWith((ref) => false),
        ],
      );
      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: router,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsNothing);
      container.read(accountAccessAvailableProvider.notifier).state = true;
      await tester.pumpAndSettle();
      expect(find.text('Next'), findsOneWidget);
      await tester.tap(find.text('Next'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Your name'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
      container.dispose();
    },
  );
}

class _SignedInAuth extends AuthService {
  _SignedInAuth() : super(null);
  @override
  User get currentUser => _User();
}

class _User implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
