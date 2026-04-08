import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/routine_exercise.dart';
import 'package:strength_training_tracker/src/features/routines/routine_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';
import 'package:strength_training_tracker/src/shared/widgets/exercise_picker_sheet.dart';

class RoutineEditorScreen extends ConsumerStatefulWidget {
  const RoutineEditorScreen({super.key, this.routineId});

  final String? routineId;

  @override
  ConsumerState<RoutineEditorScreen> createState() =>
      _RoutineEditorScreenState();
}

class _RoutineEditorScreenState extends ConsumerState<RoutineEditorScreen> {
  final _nameController = TextEditingController();
  String _category = 'strength';
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
      _category = Routine.normalizeCategory(routine.category);
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
        _category = Routine.normalizeCategory(routine.category);
        _exercises = [...routine.exercises]
          ..sort((a, b) => a.order.compareTo(b.order));
      }
      _initialized = true;
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.routineId == null ? l10n.newRoutine : l10n.editRoutine),
        actions: [
          if (widget.routineId != null &&
              state.routineById(widget.routineId!) != null &&
              !(state.routineById(widget.routineId!)!.archived))
            IconButton(
              icon: const Icon(Icons.archive_outlined),
              tooltip: l10n.archiveRoutine,
              onPressed: () => _confirmArchive(context, l10n),
            ),
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
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(
              labelText: l10n.routineName,
              hintText: l10n.routineNameHint,
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            items: <String, String>{
              'strength': l10n.strength,
              'hypertrophy': l10n.hypertrophy,
              'mobility': l10n.mobility,
            }
                .entries
                .map(
                  (e) =>
                      DropdownMenuItem<String>(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (value) {
              if (value != null) {
                setState(() => _category = value);
              }
            },
            decoration: InputDecoration(labelText: l10n.category),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.exercises,
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
                      color: context.appColors.subtleText),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tapToAddExercises,
                    style: TextStyle(color: context.appColors.subtleText),
                  ),
                ],
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) newIndex--;
                  final item = _exercises.removeAt(oldIndex);
                  _exercises.insert(newIndex, item);
                  _reindexExercises();
                });
              },
              children: [
                for (final entry in _exercises.asMap().entries)
                  _buildExerciseCard(context, state, entry.key, entry.value),
              ],
            ),
          if (_exercises.isNotEmpty) ...[
            DashedBorderCard(
              onTap: availableExercises.isEmpty
                  ? null
                  : () => _showExercisePicker(context, availableExercises),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.add_circle_outline,
                      color: context.appColors.subtleText),
                  const SizedBox(width: 8),
                  Text(
                    l10n.tapToAddMore,
                    style: TextStyle(color: context.appColors.subtleText),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Icon(Icons.schedule, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  'Est. duration: $_estimatedDurationMin min',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.subtleText,
                  ),
                ),
                const SizedBox(width: 20),
                Icon(Icons.fitness_center, size: 18, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 6),
                Text(
                  '${_exercises.length} exercises',
                  style: TextStyle(
                    fontSize: 13,
                    color: context.appColors.subtleText,
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
                widget.routineId == null ? l10n.createRoutine : l10n.saveChanges,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildExerciseCard(
    BuildContext context,
    AppState state,
    int index,
    RoutineExercise item,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final exercise = state.exerciseById(item.exerciseId);
    final muscles = exercise?.primaryMuscles.join(', ') ?? '';

    return Card(
      key: ValueKey(index),
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.fitness_center,
                      color: context.appColors.subtleText),
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
                            color: context.appColors.subtleText,
                          ),
                        ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                  onPressed: () async {
                    final picked = await showExercisePickerSheet(
                      context,
                      isSwap: true,
                      excludeIds: _exercises.map((e) => e.exerciseId).toSet(),
                    );
                    if (picked == null) return;
                    setState(() {
                      _exercises[index] = _exercises[index].copyWith(
                        exerciseId: picked.id,
                      );
                    });
                  },
                ),
                IconButton(
                  icon: Icon(Icons.delete_outline,
                      color: context.appColors.subtleText),
                  onPressed: () {
                    setState(() {
                      _exercises.removeAt(index);
                      _reindexExercises();
                    });
                  },
                ),
                ReorderableDragStartListener(
                  index: index,
                  child: Icon(Icons.drag_handle,
                      color: context.appColors.subtleText),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                if (exercise?.exerciseType == 'timed') ...[
                  Expanded(
                    child: _StepperField(
                      label: l10n.durationLabel,
                      value: item.targetDurationSeconds ~/ 60,
                      step: 1,
                      min: 1,
                      suffix: 'min',
                      onChanged: (value) => _updateExercise(
                        index,
                        item.copyWith(targetDurationSeconds: value * 60),
                      ),
                    ),
                  ),
                ] else ...[
                  Expanded(
                    child: _StepperField(
                      label: l10n.sets,
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
                      label: l10n.reps,
                      value: item.targetReps,
                      onChanged: (value) => _updateExercise(
                        index,
                        item.copyWith(targetReps: value),
                      ),
                    ),
                  ),
                ],
                const SizedBox(width: 10),
                Expanded(
                  child: _StepperField(
                    label: l10n.rest,
                    value: item.restSeconds,
                    step: 10,
                    min: 0,
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
  }

  Future<void> _showExercisePicker(
    BuildContext context,
    List<Exercise> exercises,
  ) async {
    final picked = await showExercisePickerSheet(
      context,
      excludeIds: _exercises.map((e) => e.exerciseId).toSet(),
    );

    if (picked == null) return;

    final isTimed = picked.exerciseType == 'timed';
    setState(() {
      _exercises = [
        ..._exercises,
        RoutineExercise(
          exerciseId: picked.id,
          targetSets: isTimed ? 1 : 3,
          targetReps: isTimed ? 0 : 8,
          targetDurationSeconds: isTimed ? 60 : 60,
          restSeconds: isTimed ? 0 : 90,
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

  Future<void> _confirmArchive(BuildContext context, AppLocalizations l10n) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.archiveRoutineTitle),
        content: Text(l10n.archiveRoutineConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(dialogContext).colorScheme.error,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(l10n.archiveRoutine),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      ref.read(routineControllerProvider).archive(widget.routineId!);
      context.pop();
    }
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
    this.min = 1,
  });

  final String label;
  final int value;
  final ValueChanged<int> onChanged;
  final int step;
  final String? suffix;
  final int min;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bgColor = theme.colorScheme.surface;
    final borderColor = context.appColors.border;
    final labelColor = context.appColors.subtleText;
    final buttonBg = context.appColors.surfaceMuted;
    final buttonIcon = context.appColors.ink;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: labelColor,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                GestureDetector(
                  onTap: () => onChanged((value - step).clamp(min, 999)),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: buttonBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.remove, size: 16, color: buttonIcon),
                  ),
                ),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      suffix != null ? '$value$suffix' : '$value',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
                GestureDetector(
                  onTap: () => onChanged(value + step),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: buttonBg,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.add, size: 16, color: buttonIcon),
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

