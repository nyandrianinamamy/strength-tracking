import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';

void main() {
  const exercise = Exercise(
    id: 'ex1',
    name: 'Bench Press',
    primaryMuscles: ['chest'],
    secondaryMuscles: ['triceps'],
    equipment: ['barbell'],
    instructions: 'Press the bar up',
    archived: false,
    photoBase64: 'dGVzdA==', // base64 of "test"
  );

  test('json round-trip preserves photoBase64', () {
    final json = exercise.toJson();
    final restored = Exercise.fromJson(json);

    expect(restored.photoBase64, 'dGVzdA==');
    expect(restored.name, 'Bench Press');
    expect(restored.primaryMuscles, ['chest']);
  });

  test('json round-trip with null photoBase64', () {
    final noPhoto = exercise.copyWith(clearPhoto: true);
    expect(noPhoto.photoBase64, isNull);

    final json = noPhoto.toJson();
    expect(json.containsKey('photoBase64'), isFalse);

    final restored = Exercise.fromJson(json);
    expect(restored.photoBase64, isNull);
  });

  test('copyWith clearPhoto removes photoBase64', () {
    final cleared = exercise.copyWith(clearPhoto: true);
    expect(cleared.photoBase64, isNull);
    expect(cleared.name, 'Bench Press');
  });

  test('copyWith photoBase64 replaces value', () {
    final updated = exercise.copyWith(photoBase64: 'bmV3');
    expect(updated.photoBase64, 'bmV3');
  });
}
