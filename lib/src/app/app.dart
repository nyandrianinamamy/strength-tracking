import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/app/router.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';

final _messengerKey = GlobalKey<ScaffoldMessengerState>();

class StrengthTrainingApp extends ConsumerStatefulWidget {
  const StrengthTrainingApp({super.key});

  @override
  ConsumerState<StrengthTrainingApp> createState() =>
      _StrengthTrainingAppState();
}

class _StrengthTrainingAppState extends ConsumerState<StrengthTrainingApp> {
  late final StreamSubscription<List<ConnectivityResult>> _connectivitySub;
  bool _wasOffline = false;

  @override
  void initState() {
    super.initState();
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      final isOffline = results.contains(ConnectivityResult.none);
      final messenger = _messengerKey.currentState;
      if (messenger == null) return;

      if (isOffline && !_wasOffline) {
        messenger.showSnackBar(const SnackBar(
          content: Text('You\'re offline — changes saved locally'),
          duration: Duration(seconds: 3),
        ));
      } else if (!isOffline && _wasOffline) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Back online'),
          duration: Duration(seconds: 2),
        ));
      }
      _wasOffline = isOffline;
    });
  }

  @override
  void dispose() {
    _connectivitySub.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      scaffoldMessengerKey: _messengerKey,
      title: 'Strength Training Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      routerConfig: router,
    );
  }
}
