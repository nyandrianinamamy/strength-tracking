import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_controller.dart';
import 'package:strength_training_tracker/src/l10n/exercise_translations.dart';

// ---------------------------------------------------------------------------
// Public entry-point
// ---------------------------------------------------------------------------

Future<Exercise?> showExercisePickerSheet(
  BuildContext context, {
  bool isSwap = false,
  Set<String> excludeIds = const {},
}) {
  return showModalBottomSheet<Exercise>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      expand: false,
      builder: (sheetContext, scrollController) => _ExercisePickerBody(
        isSwap: isSwap,
        excludeIds: excludeIds,
        scrollController: scrollController,
        // We need the original context so Navigator.pop works on the right
        // route — pass the host context explicitly.
        hostContext: context,
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Body widget
// ---------------------------------------------------------------------------

class _ExercisePickerBody extends ConsumerStatefulWidget {
  const _ExercisePickerBody({
    required this.isSwap,
    required this.excludeIds,
    required this.scrollController,
    required this.hostContext,
  });

  final bool isSwap;
  final Set<String> excludeIds;
  final ScrollController scrollController;
  final BuildContext hostContext;

  @override
  ConsumerState<_ExercisePickerBody> createState() =>
      _ExercisePickerBodyState();
}

class _ExercisePickerBodyState extends ConsumerState<_ExercisePickerBody> {
  final _searchController = TextEditingController();
  Timer? _debounce;
  String _query = '';
  bool _showQuickCreate = false;

  @override
  void dispose() {
    _searchController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) {
        setState(() {
          _query = value.trim();
          _showQuickCreate = false;
        });
      }
    });
  }

  bool _hasExactMatch(List<Exercise> results) {
    final q = _query.toLowerCase();
    return results.any((e) => e.name.toLowerCase() == q);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(exerciseControllerProvider);
    final exercises = controller.search(_query);
    final showCreateRow = _query.isNotEmpty && !_hasExactMatch(exercises);

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        children: [
          // Drag handle
          const SizedBox(height: 8),
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.appColors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                widget.isSwap
                    ? l10n.swapExercisePickerTitle
                    : l10n.exercisePickerTitle,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Search bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              controller: _searchController,
              autofocus: false,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: l10n.searchExercisesEllipsis,
                filled: true,
                fillColor: context.appColors.surfaceMuted,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onSearchChanged,
            ),
          ),
          const SizedBox(height: 8),

          // List
          Expanded(
            child: ListView.builder(
              controller: widget.scrollController,
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
              itemCount: exercises.length + (showCreateRow ? 1 : 0),
              itemBuilder: (context, index) {
                // "Create [query]" row at the top
                if (showCreateRow && index == 0) {
                  if (_showQuickCreate) {
                    return _QuickCreateForm(
                      initialName: _query,
                      onCreated: (exercise) {
                        Navigator.of(widget.hostContext).pop(exercise);
                      },
                    );
                  }
                  return _CreateRow(
                    query: _query,
                    onTap: () => setState(() => _showQuickCreate = true),
                  );
                }

                final exerciseIndex = showCreateRow ? index - 1 : index;
                final exercise = exercises[exerciseIndex];
                final isExcluded = widget.excludeIds.contains(exercise.id);

                return _ExerciseRow(
                  exercise: exercise,
                  isExcluded: isExcluded,
                  onTap: isExcluded
                      ? null
                      : () => Navigator.of(widget.hostContext).pop(exercise),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Create row
// ---------------------------------------------------------------------------

class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.query, required this.onTap});

  final String query;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: CircleAvatar(
        backgroundColor:
            Theme.of(context).colorScheme.primary.withValues(alpha: 0.12),
        child: Icon(
          Icons.add_rounded,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      title: Text(
        l10n.createExerciseName(query),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise row
// ---------------------------------------------------------------------------

class _ExerciseRow extends StatelessWidget {
  const _ExerciseRow({
    required this.exercise,
    required this.isExcluded,
    required this.onTap,
  });

  final Exercise exercise;
  final bool isExcluded;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
      leading: _ExerciseThumbnail(exercise: exercise),
      title: Text(
        ExerciseTranslations.displayName(context, exercise),
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: isExcluded ? context.appColors.subtleText : null,
        ),
      ),
      subtitle: exercise.primaryMuscles.isNotEmpty
          ? Text(
              exercise.primaryMuscles.join(', '),
              style: TextStyle(
                color: isExcluded ? context.appColors.subtleText : null,
              ),
            )
          : null,
      trailing: isExcluded
          ? Text(
              l10n.added,
              style: TextStyle(
                color: context.appColors.subtleText,
                fontWeight: FontWeight.w600,
                fontSize: 12,
              ),
            )
          : null,
      onTap: onTap,
    );
  }
}

// ---------------------------------------------------------------------------
// Exercise thumbnail (circular avatar)
// ---------------------------------------------------------------------------

// Maps primary muscle name to [icon, color] for fallback display.
const _muscleIconMap = <String, ({IconData icon, Color color})>{
  'Chest': (icon: Icons.fitness_center, color: Color(0xFFEF5350)),
  'Back': (icon: Icons.accessibility_new, color: Color(0xFF42A5F5)),
  'Shoulders': (icon: Icons.sports_handball, color: Color(0xFFAB47BC)),
  'Biceps': (icon: Icons.fitness_center, color: Color(0xFF26A69A)),
  'Triceps': (icon: Icons.fitness_center, color: Color(0xFF66BB6A)),
  'Quads': (icon: Icons.directions_run, color: Color(0xFFFFA726)),
  'Hamstrings': (icon: Icons.directions_run, color: Color(0xFFFF7043)),
  'Glutes': (icon: Icons.airline_seat_recline_normal, color: Color(0xFFEC407A)),
  'Calves': (icon: Icons.directions_walk, color: Color(0xFF8D6E63)),
  'Abs': (icon: Icons.crop_square, color: Color(0xFF29B6F6)),
};

const _defaultThumbnail = (
  icon: Icons.fitness_center,
  color: Color(0xFF90A4AE),
);

class _ExerciseThumbnail extends StatelessWidget {
  const _ExerciseThumbnail({required this.exercise});

  final Exercise exercise;

  @override
  Widget build(BuildContext context) {
    final photoBase64 = exercise.photoBase64;
    if (photoBase64 != null && photoBase64.isNotEmpty) {
      try {
        final bytes = base64Decode(photoBase64);
        return CircleAvatar(
          radius: 22,
          backgroundImage: MemoryImage(bytes),
        );
      } on FormatException {
        // fall through to icon fallback
      }
    }

    final muscle = exercise.primaryMuscles.firstOrNull ?? '';
    final style = _muscleIconMap[muscle] ?? _defaultThumbnail;

    return CircleAvatar(
      radius: 22,
      backgroundColor: style.color.withValues(alpha: 0.15),
      child: Icon(style.icon, color: style.color, size: 20),
    );
  }
}

// ---------------------------------------------------------------------------
// Quick-create inline form
// ---------------------------------------------------------------------------

class _QuickCreateForm extends ConsumerStatefulWidget {
  const _QuickCreateForm({
    required this.initialName,
    required this.onCreated,
  });

  final String initialName;
  final void Function(Exercise exercise) onCreated;

  @override
  ConsumerState<_QuickCreateForm> createState() => _QuickCreateFormState();
}

class _QuickCreateFormState extends ConsumerState<_QuickCreateForm> {
  late final TextEditingController _nameController;
  String? _selectedMuscle;
  bool _isCreating = false;

  static const _muscles = [
    'Chest',
    'Back',
    'Shoulders',
    'Biceps',
    'Triceps',
    'Quads',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Abs',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  void _handleCreate() {
    if (_isCreating) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _isCreating = true);

    final exercise = ref.read(exerciseControllerProvider).create(
          name: name,
          primaryMuscles: _selectedMuscle != null ? [_selectedMuscle!] : [],
          equipment: [],
          instructions: '',
        );

    widget.onCreated(exercise);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final canCreate = _nameController.text.trim().isNotEmpty;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Container(
        decoration: BoxDecoration(
          color: context.appColors.surfaceMuted,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: context.appColors.border),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.quickCreateTitle,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 12),

            // Name field
            TextField(
              controller: _nameController,
              decoration: InputDecoration(
                labelText: l10n.exerciseName,
                filled: true,
                fillColor: Theme.of(context).cardColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 12),

            // Muscle group chips
            Text(
              l10n.selectPrimaryMuscle,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: context.appColors.subtleText,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _muscles.map((muscle) {
                final isSelected = _selectedMuscle == muscle;
                return GestureDetector(
                  onTap: () => setState(() {
                    _selectedMuscle = isSelected ? null : muscle;
                  }),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).cardColor,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : context.appColors.border,
                      ),
                    ),
                    child: Text(
                      muscle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: isSelected
                                ? Theme.of(context).colorScheme.onPrimary
                                : Theme.of(context).colorScheme.onSurface,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Create button
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canCreate && !_isCreating ? _handleCreate : null,
                child: Text(l10n.createAndAdd),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
