import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';

import 'package:strength_training_tracker/src/features/dashboard/dashboard_screen.dart';

void main() {
  const userName = 'Offline Startup Athlete';
  for (final width in [320.0, 362.0, 402.0]) {
    for (final textScale in [1.0, 1.5, 2.0]) {
      testWidgets(
        'full name and Settings fit width $width at text scale $textScale',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final semantics = tester.ensureSemantics();
          try {
            final router = GoRouter(
              routes: [
                GoRoute(
                  path: '/',
                  builder: (context, state) => const Scaffold(
                    body: Padding(
                      padding: EdgeInsets.all(20),
                      child: DashboardProfileHeader(userName: userName),
                    ),
                  ),
                ),
                GoRoute(
                  path: '/settings',
                  builder: (context, state) =>
                      const Scaffold(body: Text('Settings destination')),
                ),
              ],
            );
            addTearDown(router.dispose);
            await tester.pumpWidget(
              MaterialApp.router(
                theme: AppTheme.light(),
                routerConfig: router,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text(userName), findsOneWidget);
            expect(find.bySemanticsLabel(userName), findsOneWidget);
            final nameWidget = tester.widget<Text>(find.text(userName));
            expect(
              nameWidget.maxLines,
              isNull,
              reason:
                  'The persisted name stays readable without clipping or ellipsis',
            );
            final settings = find.byTooltip('Settings');
            expect(settings.hitTestable(), findsOneWidget);
            final nameRect = tester.getRect(find.text(userName));
            final buttonRect = tester.getRect(settings);
            expect(nameRect.right, lessThanOrEqualTo(buttonRect.left));
            expect(buttonRect.right, lessThanOrEqualTo(width));
            await tester.tap(settings);
            await tester.pumpAndSettle();
            expect(find.text('Settings destination'), findsOneWidget);
            expect(tester.takeException(), isNull);
          } finally {
            semantics.dispose();
          }
        },
      );
    }
  }
}
