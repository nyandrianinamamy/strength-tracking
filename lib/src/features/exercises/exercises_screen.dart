import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_controller.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class ExercisesScreen extends ConsumerStatefulWidget {
  const ExercisesScreen({super.key});

  @override
  ConsumerState<ExercisesScreen> createState() => _ExercisesScreenState();
}

class _ExercisesScreenState extends ConsumerState<ExercisesScreen> {
  String _query = '';
  String _muscle = 'All';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final muscles = [
      l10n.all,
      ...{
        for (final exercise in state.exercises.where((item) => !item.archived))
          ...exercise.primaryMuscles,
      },
    ]..sort();

    final controller = ref.read(exerciseControllerProvider);
    final exercises = controller.search(_query).where((exercise) {
      if (_muscle == l10n.all) {
        return true;
      }
      return exercise.primaryMuscles.contains(_muscle);
    }).toList();

    final grouped = <String, List<dynamic>>{};
    for (final exercise in exercises) {
      final key = exercise.primaryMuscles.firstOrNull ?? 'Other';
      grouped.putIfAbsent(key, () => []).add(exercise);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.exercises,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => context.push('/exercise/new'),
              icon: const Icon(Icons.add_rounded),
              label: Text(l10n.newExercise),
            ),
          ],
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: InputDecoration(
            prefixIcon: const Icon(Icons.search_rounded),
            hintText: l10n.searchExercises,
            filled: true,
            fillColor: const Color(0xFFF1F5F9),
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
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        const SizedBox(height: 14),
        CategoryChips(
          options: muscles,
          selected: _muscle,
          onSelected: (v) => setState(() => _muscle = v),
        ),
        const SizedBox(height: 24),
        if (grouped.isEmpty)
          EmptyStateCard(
            title: l10n.noExercisesFound,
            body: l10n.adjustFilter,
          )
        else
          ...grouped.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: PageSection(
                title: entry.key,
                trailing: Text(
                  '${entry.value.length}',
                  style: const TextStyle(color: Colors.black54),
                ),
                child: Column(
                  children: entry.value.map((exercise) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.fitness_center,
                            color: AppTheme.slateInactive,
                          ),
                        ),
                        title: Text(
                          exercise.name as String,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(
                          '${(exercise.primaryMuscles as List<String>).join(', ')} • ${(exercise.equipment as List<String>).join(', ')}',
                        ),
                        trailing: PopupMenuButton<String>(
                          onSelected: (value) {
                            if (value == 'edit') {
                              context.push('/exercise/${exercise.id}/edit');
                            } else {
                              ref
                                  .read(exerciseControllerProvider)
                                  .archive(exercise.id as String);
                            }
                          },
                          itemBuilder: (context) => const [
                            PopupMenuItem(value: 'edit', child: Text('Edit')),
                            PopupMenuItem(
                              value: 'archive',
                              child: Text('Archive'),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            );
          }),
      ],
    );
  }
}
