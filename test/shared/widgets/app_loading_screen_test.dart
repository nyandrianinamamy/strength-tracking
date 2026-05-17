import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/shared/widgets/app_loading_screen.dart';

void main() {
  testWidgets('renders branded loading state', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const AppLoadingScreen(
          message: 'Restoring your training data...',
        ),
      ),
    );

    expect(find.text('Kotrana'), findsOneWidget);
    expect(find.text('Restoring your training data...'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(
      find.image(const AssetImage('assets/icon/app_icon.png')),
      findsOneWidget,
    );
  });
}
