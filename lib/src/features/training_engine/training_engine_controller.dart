import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:training_engine/training_engine.dart';

import '../../core/app_state_controller.dart';
import 'training_engine_provider.dart';

final trainingEngineControllerProvider = Provider<TrainingEngineController>(
  TrainingEngineController.new,
);

class TrainingEngineController {
  TrainingEngineController(this._ref);
  final Ref _ref;

  /// Derivatives are always rebuilt from the same persisted app facts that a
  /// restart reads. Capturing the repository before awaiting keeps writes with
  /// their originating account during a sign-out or account switch.
  Future<TrainingEngine> refreshFromAppHistory() async {
    final repository = _ref.read(activeTrainingEngineStateRepositoryProvider);
    final engine = await loadTrainingEngine(
      appState: _ref.read(appStateControllerProvider),
      adapter: _ref.read(trainingEngineAdapterProvider),
      healthKit: _ref.read(healthKitDataSourceProvider),
      repository: repository,
    );
    return engine;
  }
}
