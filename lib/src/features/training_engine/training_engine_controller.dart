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

  Future<TrainingEngine> ingestSession(EngineSession session) {
    return _mutate((engine) => engine.ingestSession(session));
  }

  Future<TrainingEngine> ingestSleep(SleepRecord record) {
    return _mutate((engine) => engine.ingestSleep(record));
  }

  Future<TrainingEngine> ingestHrv(HrvRecord record) {
    return _mutate((engine) => engine.ingestHrv(record));
  }

  Future<TrainingEngine> _mutate(void Function(TrainingEngine engine) update) async {
    final engine = await loadTrainingEngine(
      appState: _ref.read(appStateControllerProvider),
      adapter: _ref.read(trainingEngineAdapterProvider),
      healthKit: _ref.read(healthKitDataSourceProvider),
      repository: _ref.read(trainingEngineStateRepositoryProvider),
    );
    update(engine);
    await _ref
        .read(trainingEngineStateRepositoryProvider)
        .save(engine.serializeState());
    _ref.invalidate(trainingEngineProvider);
    return engine;
  }
}
