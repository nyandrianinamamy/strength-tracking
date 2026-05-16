import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:strength_training_tracker/src/core/app_bootstrap.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';

void main() {
  test(
    'unauthenticated bootstrap state ignores legacy local profile data',
    () async {
      SharedPreferences.setMockInitialValues({
        'strength_training_tracker_state_v1': AppState.empty()
            .copyWith(userName: 'Legacy Local User')
            .toJsonString(),
      });

      final repository = buildUnauthenticatedRepositoryForTest();

      expect((await repository.load()).userName, isEmpty);
    },
  );
}

extension on AppState {
  String toJsonString() => jsonEncode(toJson());
}
