import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';

void main() {
  test(
    'shared preferences repository persists and reloads app state',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      final repository = SharedPreferencesAppStateRepository(preferences);
      final state = DemoSeedData.initialState();

      await repository.save(state);
      final loaded = await repository.load();

      expect(loaded.exercises.length, state.exercises.length);
      expect(loaded.routines.length, state.routines.length);
      expect(loaded.sessions.length, state.sessions.length);
      expect(loaded.completedSessions.length, state.completedSessions.length);
    },
  );
}
