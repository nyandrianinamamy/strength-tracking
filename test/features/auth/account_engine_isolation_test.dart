import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_state_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'empty-history accounts cannot restore another account HRV or sleep state',
    () async {
      SharedPreferences.setMockInitialValues({
        'training_engine_state_v1': '{"sleep":"unowned legacy data"}',
      });
      final preferences = await SharedPreferences.getInstance();
      final first = SharedPreferencesTrainingEngineStateRepository(
        preferences,
        accountId: 'A',
      );
      await first.save({
        'sleepRecords': ['A sleep'],
        'hrvRecords': [75],
        'historyFingerprint': 'empty-history',
      });
      final second = SharedPreferencesTrainingEngineStateRepository(
        preferences,
        accountId: 'B',
      );
      expect(await second.load(), isNull);
      await second.save({
        'hrvRecords': [20],
        'historyFingerprint': 'empty-history',
      });
      await first.clear();
      expect((await second.load())!['hrvRecords'], [20]);
      expect(
        await SharedPreferencesTrainingEngineStateRepository(
          preferences,
        ).load(),
        isNull,
      );
    },
  );

  test(
    'an account literally named guest does not share anonymous storage',
    () async {
      SharedPreferences.setMockInitialValues({});
      final preferences = await SharedPreferences.getInstance();
      await SharedPreferencesTrainingEngineStateRepository(
        preferences,
        accountId: 'guest',
      ).save({'hrv': 99});
      expect(
        await SharedPreferencesTrainingEngineStateRepository(
          preferences,
        ).load(),
        isNull,
      );
    },
  );
}
