import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
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
    final state = ref.watch(appStateControllerProvider);
    final muscles = [
      'All',
      ...{
        for (final exercise in state.exercises.where((item) => !item.archived))
          ...exercise.primaryMuscles,
      },
    ]..sort();

    final controller = ref.read(exerciseControllerProvider);
    final exercises = controller.search(_query).where((exercise) {
      if (_muscle == 'All') {
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
                'Exercises',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            FilledButton.icon(
              onPressed: () => context.push('/exercise/new'),
              icon: const Icon(Icons.add_rounded),
              label: const Text('New Exercise'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Keep your exercise library clean, searchable, and ready for routine building.',
          style: Theme.of(
            context,
          ).textTheme.bodyLarge?.copyWith(color: Colors.black54),
        ),
        const SizedBox(height: 18),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search_rounded),
            hintText: 'Search exercises or muscles',
          ),
          onChanged: (value) => setState(() => _query = value.trim()),
        ),
        const SizedBox(height: 14),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: muscles.map((muscle) {
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(muscle),
                  selected: _muscle == muscle,
                  onSelected: (_) => setState(() => _muscle = muscle),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 24),
        if (grouped.isEmpty)
          const EmptyStateCard(
            title: 'No exercises found',
            body: 'Adjust the filter or create a custom movement.',
          )
        else
          ...grouped.entries.map((entry) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: PageSection(
                title: entry.key,
                child: Column(
                  children: entry.value.map((exercise) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 8,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: const Color(
                            0xFF257BF4,
                          ).withValues(alpha: 0.12),
                          child: const Icon(
                            Icons.fitness_center_rounded,
                            color: Color(0xFF257BF4),
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
