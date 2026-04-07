import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
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
  final Set<String> _secondaryMuscles = {};
  final Set<String> _equipment = {};
  String _exerciseType = 'strength';
  String? _photoBase64;
  bool _photoCleared = false;
  bool _initialized = false;

  static const _muscleOptions = [
    'Chest',
    'Upper Back',
    'Trapezius',
    'Deltoids',
    'Biceps',
    'Triceps',
    'Forearm',
    'Abs',
    'Obliques',
    'Lower Back',
    'Quadriceps',
    'Hamstrings',
    'Glutes',
    'Calves',
    'Adductors',
    'Tibialis',
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
      _secondaryMuscles.addAll(exercise.secondaryMuscles);
      _equipment.addAll(exercise.equipment);
      _exerciseType = exercise.exerciseType;
      _photoBase64 = exercise.photoBase64;
      _initialized = true;
    }
  }

  Future<void> _pickPhoto() async {
    final picker = ImagePicker();
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(AppLocalizations.of(context)!.takePhoto),
              onTap: () => Navigator.pop(context, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(AppLocalizations.of(context)!.chooseFromGallery),
              onTap: () => Navigator.pop(context, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    final image = await picker.pickImage(
      source: source,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 70,
    );
    if (image == null) return;

    final bytes = await image.readAsBytes();
    setState(() {
      _photoBase64 = base64Encode(bytes);
      _photoCleared = false;
    });
  }

  void _removePhoto() {
    setState(() {
      _photoBase64 = null;
      _photoCleared = true;
    });
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
        _secondaryMuscles.addAll(exercise.secondaryMuscles);
        _equipment.addAll(exercise.equipment);
        _exerciseType = exercise.exerciseType;
        _photoBase64 = exercise.photoBase64;
      }
      _initialized = true;
    }

    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.exerciseId == null ? l10n.newExerciseTitle : l10n.editExercise,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton(
              onPressed: (_muscles.isEmpty && _exerciseType == 'strength') ? null : () => _save(context),
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
              labelText: l10n.exerciseName,
              hintText: l10n.exerciseNameHint,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            l10n.machinePhoto,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: _pickPhoto,
            child: _photoBase64 != null
                ? Builder(
                    builder: (context) {
                      try {
                        final bytes = base64Decode(_photoBase64!);
                        return Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(16),
                              child: Image.memory(
                                bytes,
                                width: double.infinity,
                                height: 200,
                                fit: BoxFit.cover,
                              ),
                            ),
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _PhotoActionButton(
                              icon: Icons.camera_alt,
                              onTap: _pickPhoto,
                            ),
                            const SizedBox(width: 8),
                            _PhotoActionButton(
                              icon: Icons.close,
                              onTap: _removePhoto,
                            ),
                          ],
                        ),
                      ),
                          ],
                        );
                      } on FormatException {
                        _removePhoto();
                        return const SizedBox.shrink();
                      }
                    },
                  )
                : Container(
                    width: double.infinity,
                    height: 140,
                    decoration: BoxDecoration(
                      color: context.appColors.surfaceMuted,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: context.appColors.border,
                        style: BorderStyle.solid,
                      ),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_rounded, size: 36, color: context.appColors.subtleText),
                        const SizedBox(height: 8),
                        Text(
                          l10n.addMachinePhoto,
                          style: TextStyle(color: context.appColors.subtleText, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: [
              ButtonSegment(value: 'strength', label: Text(l10n.strength), icon: const Icon(Icons.fitness_center)),
              ButtonSegment(value: 'timed', label: Text(l10n.timedType), icon: const Icon(Icons.timer)),
            ],
            selected: {_exerciseType},
            onSelectionChanged: (values) {
              setState(() => _exerciseType = values.first);
            },
          ),
          const SizedBox(height: 24),
          Text(
            l10n.primaryMuscles,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _muscleOptions.map((muscle) {
              final selected = _muscles.contains(muscle);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _muscles.remove(muscle);
                  } else {
                    _muscles.add(muscle);
                  }
                }),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: selected
                        ? Theme.of(context).colorScheme.primary
                        : context.appColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    muscle,
                    style: TextStyle(
                      color: selected ? Theme.of(context).colorScheme.onPrimary : context.appColors.ink,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.secondaryMuscles,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.secondaryMusclesHint,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.appColors.subtleText),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _muscleOptions.map((muscle) {
              final selected = _secondaryMuscles.contains(muscle);
              final isPrimary = _muscles.contains(muscle);
              return GestureDetector(
                onTap: isPrimary ? null : () {
                  setState(() {
                    if (selected) {
                      _secondaryMuscles.remove(muscle);
                    } else {
                      _secondaryMuscles.add(muscle);
                    }
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPrimary
                        ? Theme.of(context).disabledColor
                        : selected
                            ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.15)
                            : context.appColors.surfaceMuted,
                    borderRadius: BorderRadius.circular(999),
                    border: selected ? Border.all(color: Theme.of(context).colorScheme.primary, width: 1.5) : null,
                  ),
                  child: Text(
                    muscle,
                    style: TextStyle(
                      color: isPrimary
                          ? Theme.of(context).disabledColor
                          : selected
                              ? Theme.of(context).colorScheme.primary
                              : context.appColors.ink,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          Text(
            l10n.equipment,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 3.5,
            ),
            itemCount: _equipmentOptions.length,
            itemBuilder: (context, index) {
              final item = _equipmentOptions[index];
              final selected = _equipment.contains(item);
              return GestureDetector(
                onTap: () => setState(() {
                  if (selected) {
                    _equipment.remove(item);
                  } else {
                    _equipment.add(item);
                  }
                }),
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color:
                          selected ? Theme.of(context).colorScheme.primary : context.appColors.border,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        selected
                            ? Icons.check_box
                            : Icons.check_box_outline_blank,
                        size: 20,
                        color: selected
                            ? Theme.of(context).colorScheme.primary
                            : context.appColors.subtleText,
                      ),
                      const SizedBox(width: 8),
                      Text(item, style: const TextStyle(fontSize: 13)),
                    ],
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          TextField(
            controller: _instructionsController,
            minLines: 6,
            maxLines: null,
            decoration: InputDecoration(
              labelText: l10n.instructionsFormTips,
              hintText: l10n.instructionsHint,
            ),
          ),
        ],
      ),
    );
  }

  void _save(BuildContext context) {
    final name = _nameController.text.trim();
    if (name.isEmpty || (_muscles.isEmpty && _exerciseType == 'strength')) {
      return;
    }

    final controller = ref.read(exerciseControllerProvider);
    if (widget.exerciseId == null) {
      controller.create(
        name: name,
        primaryMuscles: _muscles.toList(),
        secondaryMuscles: _secondaryMuscles.toList(),
        equipment: _equipment.toList(),
        instructions: _instructionsController.text,
        exerciseType: _exerciseType,
        photoBase64: _photoBase64,
      );
    } else {
      controller.update(
        exerciseId: widget.exerciseId!,
        name: name,
        primaryMuscles: _muscles.toList(),
        secondaryMuscles: _secondaryMuscles.toList(),
        equipment: _equipment.toList(),
        instructions: _instructionsController.text,
        exerciseType: _exerciseType,
        photoBase64: _photoBase64,
        clearPhoto: _photoCleared,
      );
    }

    context.pop();
  }
}

class _PhotoActionButton extends StatelessWidget {
  const _PhotoActionButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      onPressed: onTap,
      icon: Icon(icon, color: Colors.white, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: Colors.black54,
        minimumSize: const Size(40, 40),
      ),
      constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    );
  }
}
