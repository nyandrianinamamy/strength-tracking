import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final loader = FontLoader('Lexend');
    for (final weight in ['Regular', 'Bold', 'ExtraBold', 'Black']) {
      loader.addFont(rootBundle.load('assets/fonts/Lexend-$weight.ttf'));
    }
    await loader.load();
  });

  // A 335-point summary row gives each card exactly the 121.5-point inner
  // width recorded in the iPad compatibility-window failure. The former grid
  // also constrained the inner height to 106.8, too short for wrapped labels.
  for (final width in [335.0, 362.0]) {
    for (final locale in ['en', 'fr']) {
      for (final textScale in [1.0, 2.0]) {
        for (final showBadges in [true, false]) {
          testWidgets('${showBadges ? 'dashboard' : 'progress'} metrics fit '
              '$width points, $locale, text scale $textScale', (tester) async {
            tester.view.physicalSize = const Size(900, 1200);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            var tapCount = 0;
            await tester.pumpWidget(
              MaterialApp(
                theme: AppTheme.light(),
                locale: Locale(locale),
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: TextScaler.linear(textScale)),
                  child: child!,
                ),
                home: Scaffold(
                  body: Align(
                    alignment: Alignment.topCenter,
                    child: SizedBox(
                      width: width,
                      child: SingleChildScrollView(
                        child: Builder(
                          builder: (context) {
                            final l10n = AppLocalizations.of(context)!;
                            return MetricCardRow(
                              children: [
                                MetricCard(
                                  label: showBadges
                                      ? l10n.workouts
                                      : l10n.workoutDays,
                                  value: showBadges ? '12' : '3.5',
                                  detail: l10n.perWeekAverage,
                                  icon: Icons.calendar_month_rounded,
                                  badge: showBadges
                                      ? const Padding(
                                          padding: EdgeInsets.all(4),
                                          child: Text('+12'),
                                        )
                                      : null,
                                ),
                                MetricCard(
                                  label: showBadges
                                      ? l10n.recentPrs
                                      : l10n.consistency,
                                  value: showBadges
                                      ? '2'
                                      : l10n.thisWeekProgress(3, 4),
                                  detail: l10n.weeksOnTrack(0),
                                  icon: Icons.workspace_premium_rounded,
                                  badge: showBadges
                                      ? Padding(
                                          padding: const EdgeInsets.all(4),
                                          child: Text(l10n.newBadge),
                                        )
                                      : null,
                                  onTap: () => tapCount++,
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            final cards = find.byType(MetricCard);
            expect(cards, findsNWidgets(2));
            final firstRect = tester.getRect(cards.first);
            final secondRect = tester.getRect(cards.last);
            expect(firstRect.width, secondRect.width);
            expect(firstRect.height, secondRect.height);
            expect(firstRect.right, lessThan(secondRect.left));

            for (final card in [cards.first, cards.last]) {
              final cardRect = tester.getRect(card);
              final texts = find.descendant(
                of: card,
                matching: find.byType(Text),
              );
              for (final element in texts.evaluate()) {
                final text = element.widget as Text;
                final paragraph =
                    element.findRenderObject()! as RenderParagraph;
                expect(paragraph.didExceedMaxLines, isFalse);
                expect(text.maxLines, isNull);
                final rect = MatrixUtils.transformRect(
                  paragraph.getTransformTo(null),
                  Offset.zero & paragraph.size,
                );
                expect(rect.left, greaterThanOrEqualTo(cardRect.left));
                expect(rect.top, greaterThanOrEqualTo(cardRect.top));
                expect(rect.right, lessThanOrEqualTo(cardRect.right + 0.01));
                expect(rect.bottom, lessThanOrEqualTo(cardRect.bottom));
              }
            }

            await tester.tap(cards.last);
            await tester.pump();
            expect(tapCount, 1);
            expect(tester.takeException(), isNull);
          });
        }
      }
    }
  }
}
