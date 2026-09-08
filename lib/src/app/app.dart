import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/app/router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

ThemeMode _resolveThemeMode(String pref) {
  switch (pref) {
    case 'light':
      return ThemeMode.light;
    case 'dark':
      return ThemeMode.dark;
    default:
      return ThemeMode.system;
  }
}

class StrengthTrainingApp extends ConsumerStatefulWidget {
  const StrengthTrainingApp({super.key});

  @override
  ConsumerState<StrengthTrainingApp> createState() =>
      _StrengthTrainingAppState();
}

class _StrengthTrainingAppState extends ConsumerState<StrengthTrainingApp>
    with WidgetsBindingObserver {
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      if (!isOffline) unawaited(_retryPendingWrites());
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;

      final ctx = _messengerKey.currentContext;
      if (ctx == null) return;
      if (!ctx.mounted) return;
      final l10n = AppLocalizations.of(ctx)!;

      if (isOffline && !_wasOffline) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.offlineMessage),
            duration: const Duration(seconds: 3),
          ),
        );
      } else if (!isOffline && _wasOffline) {
        messenger.showSnackBar(
          SnackBar(
            content: Text(l10n.backOnline),
            duration: const Duration(seconds: 2),
          ),
        );
      }
      _wasOffline = isOffline;
    });
  }

  Future<void> _retryPendingWrites() async {
    if (!mounted) return;
    try {
      await ref.read(appStateControllerProvider.notifier).retrySave();
    } catch (_) {
      // The controller keeps the durable outbox and exposes save status in UI.
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_retryPendingWrites());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connectivitySub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final preferredLanguage = ref.watch(
      appStateControllerProvider.select((s) => s.preferredLanguage),
    );
    final preferredTheme = ref.watch(
      appStateControllerProvider.select((s) => s.preferredTheme),
    );

    Locale? localeOverride;
    if (preferredLanguage.isNotEmpty) {
      localeOverride = Locale(preferredLanguage);
    }

    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      title: 'Kotrana: Musculation',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _resolveThemeMode(preferredTheme),
      routerConfig: router,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: localeOverride,
    );
  }
}
