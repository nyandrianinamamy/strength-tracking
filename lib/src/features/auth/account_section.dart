import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';

class AccountSection extends ConsumerWidget {
  const AccountSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authService = ref.read(authServiceProvider);
    final user = authService.currentUser;
    final isAnonymous = authService.isAnonymous;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            CircleAvatar(
              radius: 32,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.1),
              child: Icon(
                isAnonymous ? Icons.person_outline : Icons.person,
                size: 32,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              isAnonymous
                  ? 'Anonymous Account'
                  : user?.displayName ?? user?.email ?? 'Linked Account',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              isAnonymous
                  ? 'Link an account to sync across devices'
                  : user?.email ?? '',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: AppTheme.slateInactive),
            ),
            const SizedBox(height: 24),
            if (isAnonymous) ...[
              _AuthButton(
                icon: Icons.g_mobiledata,
                label: 'Link Google Account',
                onTap: () async {
                  try {
                    await authService.linkWithGoogle();
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
              ),
              const SizedBox(height: 12),
              _AuthButton(
                icon: Icons.apple,
                label: 'Link Apple Account',
                onTap: () async {
                  try {
                    await authService.linkWithApple();
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Failed: $e')),
                      );
                    }
                  }
                },
              ),
            ] else ...[
              Text(
                'Your data is synced across all your devices.',
                textAlign: TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: AppTheme.slateInactive),
              ),
            ],
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Unit Preference',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: Text('KG')),
                ButtonSegment(value: 'lbs', label: Text('LBS')),
              ],
              selected: {ref.watch(appStateControllerProvider).preferredUnit},
              onSelectionChanged: (values) {
                ref.read(appStateControllerProvider.notifier).updateState(
                  (s) => s.copyWith(preferredUnit: values.first),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              'Data',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _AuthButton(
              icon: Icons.download_rounded,
              label: 'Load Sample Exercises & Routines',
              onTap: () {
                final sample = DemoSeedData.initialState();
                ref.read(appStateControllerProvider.notifier).updateState(
                  (s) => s.copyWith(
                    exercises: [...s.exercises, ...sample.exercises],
                    routines: [...s.routines, ...sample.routines],
                  ),
                );
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Sample exercises & routines loaded')),
                );
              },
            ),
            const SizedBox(height: 12),
            _AuthButton(
              icon: Icons.delete_outline_rounded,
              label: 'Clear Exercises & Routines',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Clear Exercises & Routines?'),
                    content: const Text('This will delete all exercises and routines. Your workout history will be kept.'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: const Text('Cancel'),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                          ref.read(appStateControllerProvider.notifier).updateState(
                            (s) => s.copyWith(exercises: [], routines: []),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Exercises & routines cleared')),
                          );
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: const Text('Clear'),
                      ),
                    ],
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthButton extends StatelessWidget {
  const _AuthButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton.icon(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}
