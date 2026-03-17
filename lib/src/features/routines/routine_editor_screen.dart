import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

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

  int get _estimatedDurationMin {
    return _exercises.fold<int>(
      0,
      (total, exercise) =>
          total +
          (exercise.targetSets * 2) +
          ((exercise.targetSets * exercise.restSeconds) ~/ 60),
    );
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
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _exercises.isEmpty ? null : () => _save(context),
              style: FilledButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(999),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              ),
              child: const Text('Save'),
            ),
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
          Text(
            'Exercises',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          if (_exercises.isEmpty)
            DashedBorderCard(
              onTap: availableExercises.isEmpty
                  ? null
                  : () => _showExercisePicker(context, availableExercises),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: AppTheme.slateInactive),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to add exercises',
                    style: TextStyle(color: AppTheme.slateInactive),
                  ),
                ],
              ),
            )
          else
            ..._exercises.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final exercise = state.exerciseById(item.exerciseId);
              final muscles =
                  exercise?.primaryMuscles.join(', ') ?? '';

              return Card(
                margin: const EdgeInsets.only(bottom: 14),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              color: const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.fitness_center,
                                color: AppTheme.slateInactive),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  exercise?.name ?? 'Exercise',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w800),
                                ),
                                if (muscles.isNotEmpty)
                                  Text(
                                    muscles,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: AppTheme.slateInactive,
                                    ),
                                  ),
                              ],
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline,
                                color: AppTheme.slateInactive),
                            onPressed: () {
                              setState(() {
                                _exercises.removeAt(index);
                                _reindexExercises();
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _StepperField(
                              label: 'SETS',
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
                              label: 'REPS',
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
                              label: 'REST',
                              value: item.restSeconds,
                              step: 15,
                              suffix: 's',
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
          if (_exercises.isNotEmpty) ...[
            DashedBorderCard(
              onTap: availableExercises.isEmpty
                  ? null
                  : () => _showExercisePicker(context, availableExercises),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: AppTheme.slateInactive),
                  const SizedBox(width: 8),
                  Text(
                    'Tap to add more exercises',
                    style: TextStyle(color: AppTheme.slateInactive),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Est. duration: $_estimatedDurationMin min',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slateInactive,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(Icons.fitness_center, size: 18, color: AppTheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${_exercises.length} exercises',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppTheme.slateInactive,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _exercises.isEmpty ? null : () => _save(context),
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
              ),
              icon: const Icon(Icons.check_circle_outline),
              label: Text(
                widget.routineId == null ? 'Create Routine' : 'Save Changes',
              ),
            ),
          ],
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

    final controller = ref.read(routineControllerProvider);

    if (widget.routineId == null) {
      controller.create(
        name: name,
        category: _category,
        exercises: _exercises,
        estimatedDurationMin: _estimatedDurationMin,
      );
    } else {
      controller.update(
        routineId: widget.routineId!,
        name: name,
        category: _category,
        exercises: _exercises,
        estimatedDurationMin: _estimatedDurationMin,
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
    this.suffix,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final String? suffix;

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
                GestureDetector(
                  onTap: () => onChanged((value - step).clamp(step, 999)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.remove, size: 16, color: AppTheme.ink),
                  ),
                ),
                Expanded(
                  child: Text(
                    suffix != null ? '$value$suffix' : '$value',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => onChanged(value + step),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: const BoxDecoration(
                      color: Color(0xFFF1F5F9),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.add, size: 16, color: AppTheme.ink),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
