import 'package:flutter_test/flutter_test.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';

void main() {
  group('Exercise', () {
    test('new fields default to null/0', () {
      const exercise = Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
      );
      expect(exercise.useCount, 0);
      expect(exercise.lastUsedAt, isNull);
    });

    test('copyWith preserves usage fields', () {
      final now = DateTime.now();
      final exercise = Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 5,
        lastUsedAt: now,
      );
      final updated = exercise.copyWith(name: 'Incline Press');
      expect(updated.useCount, 5);
      expect(updated.lastUsedAt, now);
    });

    test('toJson includes usage fields', () {
      final now = DateTime(2026, 4, 8, 12, 0);
      final exercise = Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 3,
        lastUsedAt: now,
      );
      final json = exercise.toJson();
      expect(json['useCount'], 3);
      expect(json['lastUsedAt'], now.toIso8601String());
    });

    test('fromJson reads usage fields', () {
      final json = {
        'id': 'ex1',
        'name': 'Bench Press',
        'primaryMuscles': ['Chest'],
        'equipment': ['Barbell'],
        'instructions': '',
        'archived': false,
        'useCount': 7,
        'lastUsedAt': '2026-04-08T12:00:00.000',
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.useCount, 7);
      expect(exercise.lastUsedAt, DateTime(2026, 4, 8, 12, 0));
    });

    test('copyWith clearLastUsedAt resets to null', () {
      final exercise = Exercise(
        id: 'ex1',
        name: 'Bench Press',
        primaryMuscles: ['Chest'],
        equipment: ['Barbell'],
        instructions: '',
        archived: false,
        useCount: 5,
        lastUsedAt: DateTime(2026, 4, 8),
      );
      final cleared = exercise.copyWith(clearLastUsedAt: true);
      expect(cleared.lastUsedAt, isNull);
      expect(cleared.useCount, 5);
    });

    test('fromJson defaults when usage fields absent', () {
      final json = {
        'id': 'ex1',
        'name': 'Bench Press',
        'primaryMuscles': ['Chest'],
        'equipment': ['Barbell'],
        'instructions': '',
        'archived': false,
      };
      final exercise = Exercise.fromJson(json);
      expect(exercise.useCount, 0);
      expect(exercise.lastUsedAt, isNull);
    });
  });
}
