import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';

class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.routineId});

  final String? routineId;

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final _nameController = TextEditingController();
  String _category = 'Strength';
  List<RoutineExercise> _exercises = [];
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    final routineId = widget.routineId;
    if (routineId == null) {
      return;
    }

    final routine = ref.read(appStateControllerProvider).routineById(routineId);
    if (routine != null) {
      _nameController.text = routine.name;
      _category = routine.category;
      _exercises = [...routine.exercises]
        ..sort((a, b) => a.order.compareTo(b.order));
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateControllerProvider);
    final availableExercises =
        state.exercises.where((exercise) => !exercise.archived).toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    if (!_initialized && widget.routineId != null) {
      final routine = state.routineById(widget.routineId!);
      if (routine != null) {
        _nameController.text = routine.name;
        _category = routine.category;
        _exercises = [...routine.exercises]
          ..sort((a, b) => a.order.compareTo(b.order));
      }
      _initialized = true;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routineId == null ? 'New Routine' : 'Edit Routine'),
        actions: [
          TextButton(
            onPressed: _exercises.isEmpty ? null : () => _save(context),
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
              labelText: 'Routine Name',
              hintText: 'e.g. Upper Body Power',
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: const ['Strength', 'Hypertrophy', 'Mobility']
                .map(
                  (category) =>
                      DropdownMenuItem(value: category, child: Text(category)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _category = value);
              }
            },
            decoration: const InputDecoration(labelText: 'Category'),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Exercises',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
              ),
              OutlinedButton.icon(
                onPressed: availableExercises.isEmpty
                    ? null
                    : () => _showExercisePicker(context, availableExercises),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Exercise'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_exercises.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(18),
                child: Text('Add at least one exercise to save this routine.'),
              ),
            )
          else
            ..._exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final exercise = state.exerciseById(item.exerciseId);

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              exercise?.name ?? 'Exercise',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(fontWeight: FontWeight.w800),
                            ),
                          ),
                          IconButton(
                            onPressed: () {
                              setState(() {
                                _exercises.removeAt(index);
                                _reindexExercises();
                              });
                            },
                            icon: const Icon(Icons.delete_outline_rounded),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StepperField(
                              label: 'Sets',
                              value: item.targetSets,
                              onChanged: (value) => _updateExercise(
                                index,
                                item.copyWith(targetSets: value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StepperField(
                              label: 'Reps',
                              value: item.targetReps,
                              onChanged: (value) => _updateExercise(
                                index,
                                item.copyWith(targetReps: value),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _StepperField(
                              label: 'Rest (s)',
                              value: item.restSeconds,
                              step: 15,
                              onChanged: (value) => _updateExercise(
                                index,
                                item.copyWith(restSeconds: value),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _showExercisePicker(
    BuildContext context,
    List<dynamic> exercises,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            children: exercises.map((exercise) {
              final alreadyAdded = _exercises.any(
                (item) => item.exerciseId == exercise.id,
              );
              return ListTile(
                enabled: !alreadyAdded,
                title: Text(exercise.name as String),
                subtitle: Text(
                  (exercise.primaryMuscles as List<String>).join(', '),
                ),
                trailing: alreadyAdded
                    ? const Text('Added')
                    : const Icon(Icons.add_rounded),
                onTap: alreadyAdded
                    ? null
                    : () => context.pop(exercise.id as String),
              );
            }).toList(),
          ),
        );
      },
    );

    if (picked == null) {
      return;
    }

    setState(() {
      _exercises = [
        ..._exercises,
        RoutineExercise(
          exerciseId: picked,
          targetSets: 3,
          targetReps: 8,
          restSeconds: 90,
          order: _exercises.length,
        ),
      ];
    });
  }

  void _updateExercise(int index, RoutineExercise exercise) {
    setState(() {
      _exercises[index] = exercise;
      _reindexExercises();
    });
  }

  void _reindexExercises() {
    _exercises = _exercises.asMap().entries.map((entry) {
      return entry.value.copyWith(order: entry.key);
    }).toList();
  }

  void _save(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty || _exercises.isEmpty) {
      return;
    }

    final estimatedDurationMin = _exercises.fold<int>(
      0,
      (total, exercise) =>
          total +
          (exercise.targetSets * 2) +
          ((exercise.targetSets * exercise.restSeconds) ~/ 60),
    );

    final controller = ref.read(routineControllerProvider);

    if (widget.routineId == null) {
      controller.create(
        name: name,
        category: _category,
        exercises: _exercises,
        estimatedDurationMin: estimatedDurationMin,
      );
    } else {
      controller.update(
        routineId: widget.routineId!,
        name: name,
        category: _category,
        exercises: _exercises,
        estimatedDurationMin: estimatedDurationMin,
      );
    }

    context.pop();
  }
}

class _StepperField extends StatelessWidget {
  const _StepperField({
    required this.label,
    required this.value,
    required this.onChanged,
    this.step = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD5DDEA)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Colors.black54,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged((value - step).clamp(step, 999)),
                  icon: const Icon(Icons.remove_rounded),
                ),
                Expanded(
                  child: Text(
                    '$value',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => onChanged(value + step),
                  icon: const Icon(Icons.add_rounded),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
