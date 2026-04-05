import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';

final initialAppStateProvider = Provider<AppState>(
  (ref) =>
      throw UnimplementedError('initialAppStateProvider must be overridden'),
);

final appStateRepositoryProvider = Provider<AppStateRepository>(
  (ref) =>
      throw UnimplementedError('appStateRepositoryProvider must be overridden'),
);

final appStateControllerProvider =
    NotifierProvider<AppStateController, AppState>(AppStateController.new);

class AppStateController extends Notifier<AppState> {
  @override
  AppState build() => ref.watch(initialAppStateProvider);

  void replaceState(AppState nextState) {
    state = nextState;
    unawaited(
      ref.read(appStateRepositoryProvider).save(nextState).catchError((e) {
        debugPrint('Failed to save state: $e');
      }),
    );
  }

  /// Clear in-memory state without persisting to the repository.
  /// Used during sign-out to avoid writing empty state over the user's cloud data.
  void clearLocal() {
    state = AppState.empty();
  }

  void updateState(AppState Function(AppState currentState) update) {
    replaceState(update(state));
  }
}
