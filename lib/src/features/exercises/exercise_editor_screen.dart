import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_controller.dart';

class ExerciseEditorScreen extends ConsumerStatefulWidget {
  const ExerciseEditorScreen({super.key, this.exerciseId});

  final String? exerciseId;

  @override
  ConsumerState<ExerciseEditorScreen> createState() =>
      _ExerciseEditorScreenState();
}

class _ExerciseEditorScreenState extends ConsumerState<ExerciseEditorScreen> {
  final _nameController = TextEditingController();
  final _instructionsController = TextEditingController();
  final Set<String> _muscles = {};
  final Set<String> _equipment = {};
  bool _initialized = false;

  static const _muscleOptions = [
    'Chest',
    'Back',
    'Legs',
    'Shoulders',
    'Arms',
    'Abs',
    'Glutes',
    'Hamstrings',
  ];

  static const _equipmentOptions = [
    'Barbell',
    'Dumbbells',
    'Bench',
    'Rack',
    'Machine',
    'Cable Machine',
    'Pull-Up Bar',
    'Plate',
  ];

  @override
  void initState() {
    super.initState();
    if (widget.exerciseId == null) {
      return;
    }

    final exercise = ref
        .read(appStateControllerProvider)
        .exerciseById(widget.exerciseId!);
    if (exercise != null) {
      _nameController.text = exercise.name;
      _instructionsController.text = exercise.instructions;
      _muscles.addAll(exercise.primaryMuscles);
      _equipment.addAll(exercise.equipment);
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateControllerProvider);
    if (!_initialized && widget.exerciseId != null) {
      final exercise = state.exerciseById(widget.exerciseId!);
      if (exercise != null) {
        _nameController.text = exercise.name;
        _instructionsController.text = exercise.instructions;
        _muscles.addAll(exercise.primaryMuscles);
        _equipment.addAll(exercise.equipment);
      }
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exerciseId == null ? 'New Exercise' : 'Edit Exercise',
        ),
        actions: [
          TextButton(
            onPressed: _muscles.isEmpty ? null : () => _save(context),
            child: const Text('Save'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Exercise Name',
              hintText: 'e.g. Incline Dumbbell Press',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Primary Muscles',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _muscleOptions.map((muscle) {
              return FilterChip(
                label: Text(muscle),
                selected: _muscles.contains(muscle),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _muscles.add(muscle);
                    } else {
                      _muscles.remove(muscle);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            'Equipment',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _equipmentOptions.map((item) {
              return FilterChip(
                label: Text(item),
                selected: _equipment.contains(item),
                onSelected: (selected) {
                  setState(() {
                    if (selected) {
                      _equipment.add(item);
                    } else {
                      _equipment.remove(item);
                    }
                  });
                },
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _instructionsController,
            maxLines: 6,
            decoration: const InputDecoration(
              labelText: 'Instructions & Form Tips',
              hintText:
                  'Describe setup, execution cues, and common errors to avoid.',
            ),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty || _muscles.isEmpty) {
      return;
    }

    final controller = ref.read(exerciseControllerProvider);
    if (widget.exerciseId == null) {
      controller.create(
        name: name,
        primaryMuscles: _muscles.toList(),
        equipment: _equipment.toList(),
        instructions: _instructionsController.text,
      );
    } else {
      controller.update(
        exerciseId: widget.exerciseId!,
        name: name,
        primaryMuscles: _muscles.toList(),
        equipment: _equipment.toList(),
        instructions: _instructionsController.text,
      );
    }

    context.pop();
  }
}
