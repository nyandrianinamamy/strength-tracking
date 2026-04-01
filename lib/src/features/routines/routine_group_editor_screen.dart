import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class RoutineGroupEditorScreen extends ConsumerStatefulWidget {
  const RoutineGroupEditorScreen({super.key, this.groupId});

  final String? groupId;

  @override
  ConsumerState<RoutineGroupEditorScreen> createState() =>
      _RoutineGroupEditorScreenState();
}

class _RoutineGroupEditorScreenState
    extends ConsumerState<RoutineGroupEditorScreen> {
  final _nameController = TextEditingController();
  final _scrollController = ScrollController();
  List<String> _routineIds = [];
  bool _makeActive = false;
  bool _initialized = false;

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty && _routineIds.length >= 2;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _nameController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _ensureInitialized() {
    if (_initialized) {
      return;
    }

    final state = ref.read(appStateControllerProvider);
    final groupId = widget.groupId;
    if (groupId != null) {
      final group = state.routineGroupById(groupId);
      if (group != null) {
        _nameController.text = group.name;
        _routineIds = [...group.routineIds];
        _makeActive = state.activeRoutineGroupId == group.id;
      }
    } else {
      _makeActive = state.activeRoutineGroupId == null;
    }

    _initialized = true;
  }

  @override
  Widget build(BuildContext context) {
    _ensureInitialized();

    final state = ref.watch(appStateControllerProvider);
    final availableRoutineIds =
        ref
            .read(routineGroupControllerProvider)
            .availableRoutineIdsForGroup(widget.groupId)
          ..removeWhere(_routineIds.contains);
    final availableRoutines =
        availableRoutineIds.map(state.routineById).whereType<Routine>().toList()
          ..sort((a, b) => a.name.compareTo(b.name));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupId == null ? 'New Group' : 'Edit Group'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: _canSave ? () => _save(context) : null,
              child: const Text('Save'),
            ),
          ),
        ],
      ),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Group name',
              hintText: 'Push / Pull / Legs',
            ),
          ),
          const SizedBox(height: 16),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            value: _makeActive,
            onChanged: (value) => setState(() => _makeActive = value),
            title: const Text('Use as active rotation'),
            subtitle: const Text(
              'The active group drives the dashboard recommendation.',
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Ordered routines',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            'These run in sequence. You can reorder them and skip one from the dashboard when needed.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: context.appColors.subtleText),
          ),
          const SizedBox(height: 16),
          if (_routineIds.isEmpty)
            EmptyStateCard(
              title: 'Add at least two routines',
              body: 'Choose the routines that belong to this split.',
              dashed: true,
              icon: Icons.playlist_add_check_rounded,
              action: FilledButton.icon(
                onPressed: availableRoutines.isEmpty
                    ? null
                    : () => _showRoutinePicker(context, availableRoutines),
                icon: const Icon(Icons.add_rounded),
                label: const Text('Add Routines'),
              ),
            )
          else
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              onReorder: (oldIndex, newIndex) {
                setState(() {
                  if (newIndex > oldIndex) {
                    newIndex--;
                  }
                  final item = _routineIds.removeAt(oldIndex);
                  _routineIds.insert(newIndex, item);
                });
              },
              children: [
                for (final entry in _routineIds.asMap().entries)
                  _RoutineGroupRoutineCard(
                    key: ValueKey(entry.value),
                    index: entry.key,
                    title: state.routineById(entry.value)?.name ?? 'Routine',
                    subtitle: state.routineById(entry.value)?.category ?? '',
                    onRemove: () {
                      setState(() {
                        _routineIds.removeAt(entry.key);
                      });
                    },
                  ),
              ],
            ),
          if (_routineIds.isNotEmpty) ...[
            const SizedBox(height: 12),
            DashedBorderCard(
              onTap: availableRoutines.isEmpty
                  ? null
                  : () => _showRoutinePicker(context, availableRoutines),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.add_circle_outline,
                      color: context.appColors.subtleText,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      availableRoutines.isEmpty
                          ? 'All routines are already assigned'
                          : 'Add more routines',
                      style: TextStyle(color: context.appColors.subtleText),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _canSave ? () => _save(context) : null,
            icon: const Icon(Icons.check_circle_outline),
            label: Text(
              widget.groupId == null ? 'Create Group' : 'Save Changes',
            ),
          ),
          if (widget.groupId != null) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _delete(context),
              style: OutlinedButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete Group'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _showRoutinePicker(
    BuildContext context,
    List<Routine> availableRoutines,
  ) async {
    final selectedId = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Add routine',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
              ...availableRoutines.map((routine) {
                return ListTile(
                  title: Text(routine.name),
                  subtitle: Text(
                    '${routine.exercises.length} exercises • ${routine.estimatedDurationMin} min',
                  ),
                  trailing: const Icon(Icons.add_circle_outline),
                  onTap: () => Navigator.pop(sheetContext, routine.id),
                );
              }),
            ],
          ),
        );
      },
    );

    if (selectedId == null) {
      return;
    }

    setState(() {
      _routineIds = [..._routineIds, selectedId];
    });
  }

  void _save(BuildContext context) {
    final controller = ref.read(routineGroupControllerProvider);
    if (widget.groupId == null) {
      controller.create(
        name: _nameController.text,
        routineIds: _routineIds,
        makeActive: _makeActive,
      );
    } else {
      controller.update(
        groupId: widget.groupId!,
        name: _nameController.text,
        routineIds: _routineIds,
        makeActive: _makeActive,
      );
    }

    context.pop();
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete group?'),
        content: const Text(
          'This removes the sequence, but keeps all routines and workout history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Theme.of(context).colorScheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted || widget.groupId == null) {
      return;
    }

    ref.read(routineGroupControllerProvider).delete(widget.groupId!);
    context.pop();
  }
}

class _RoutineGroupRoutineCard extends StatelessWidget {
  const _RoutineGroupRoutineCard({
    super.key,
    required this.index,
    required this.title,
    required this.subtitle,
    required this.onRemove,
  });

  final int index;
  final String title;
  final String subtitle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Text(
                '${index + 1}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.subtleText,
                      ),
                    ),
                ],
              ),
            ),
            IconButton(
              onPressed: onRemove,
              icon: Icon(
                Icons.delete_outline,
                color: context.appColors.subtleText,
              ),
            ),
            ReorderableDragStartListener(
              index: index,
              child: Icon(
                Icons.drag_handle,
                color: context.appColors.subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
