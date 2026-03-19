import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/utils/force_update.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
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
      child: SingleChildScrollView(
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
              const SizedBox(height: 20),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Text(
                      'or switch to an existing account',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppTheme.slateInactive,
                      ),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'This will discard your current data and load the linked account\'s data.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Colors.orange.shade700,
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 12),
              _AuthButton(
                icon: Icons.g_mobiledata,
                label: 'Sign in with Google',
                onTap: () => _signInAndReplace(context, ref, 'google'),
              ),
              const SizedBox(height: 12),
              _AuthButton(
                icon: Icons.apple,
                label: 'Sign in with Apple',
                onTap: () => _signInAndReplace(context, ref, 'apple'),
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
            const SizedBox(height: 20),
            Text(
              'Body Type',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'male', label: Text('Male'), icon: Icon(Icons.male, size: 18)),
                ButtonSegment(value: 'female', label: Text('Female'), icon: Icon(Icons.female, size: 18)),
              ],
              selected: {ref.watch(appStateControllerProvider).bodyGender},
              onSelectionChanged: (values) {
                ref.read(appStateControllerProvider.notifier).updateState(
                  (s) => s.copyWith(bodyGender: values.first),
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
            if (kIsWeb) ...[
              const SizedBox(height: 12),
              _AuthButton(
                icon: Icons.refresh_rounded,
                label: 'Force Update App',
                onTap: () async {
                  Navigator.pop(context);
                  await forceUpdateApp();
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _signInAndReplace(
    BuildContext context,
    WidgetRef ref,
    String provider,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Switch Account?'),
        content: const Text(
          'Your current anonymous data will be discarded and replaced with the data from your linked account.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Switch'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final authService = ref.read(authServiceProvider);
      final user = provider == 'google'
          ? await authService.signInWithGoogle()
          : await authService.signInWithApple();

      // Load data from the signed-in account's Firestore
      final repository = FirestoreAppStateRepository(userId: user.uid);
      final cloudState = await repository.load();

      ref.read(appStateControllerProvider.notifier).replaceState(cloudState);

      if (context.mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Signed in and data restored')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sign in failed: $e')),
        );
      }
    }
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
