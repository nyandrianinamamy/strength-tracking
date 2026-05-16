import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('release onboarding hides demo data and shows invite message', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: OnboardingScreen(
            showDemoDataButton: false,
            showProfileSetup: false,
          ),
        ),
      ),
    );

    expect(
      find.text(
        "Access to Kotrana is currently invite-only. If you've been invited, sign in with the method linked to your account.",
      ),
      findsOneWidget,
    );
    expect(find.text('Explore with Demo Data'), findsNothing);
    expect(find.text('Your name'), findsNothing);
    expect(find.text('Next'), findsNothing);
    expect(find.text('Email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Continue with Apple'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
