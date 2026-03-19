import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
                  ? l10n.anonymousAccount
                  : user?.displayName ?? user?.email ?? l10n.linkedAccount,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              isAnonymous
                  ? l10n.linkToSync
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
                label: l10n.linkGoogle,
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
                label: l10n.linkApple,
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
                      l10n.switchAccount,
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
                label: l10n.signInGoogle,
                onTap: () => _signInAndReplace(context, ref, 'google'),
              ),
              const SizedBox(height: 12),
              _AuthButton(
                icon: Icons.apple,
                label: l10n.signInApple,
                onTap: () => _signInAndReplace(context, ref, 'apple'),
              ),
            ] else ...[
              Text(
                l10n.dataSynced,
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
              l10n.unitPreference,
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
            const SizedBox(height: 20),
            Text(
              l10n.language,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('Auto')),
                ButtonSegment(value: 'en', label: Text('EN')),
                ButtonSegment(value: 'fr', label: Text('FR')),
              ],
              selected: {ref.watch(appStateControllerProvider).preferredLanguage},
              onSelectionChanged: (values) {
                ref.read(appStateControllerProvider.notifier).updateState(
                  (s) => s.copyWith(preferredLanguage: values.first),
                );
              },
            ),
            const SizedBox(height: 20),
            Text(
              'Theme',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: '', label: Text('Auto')),
                ButtonSegment(value: 'light', label: Icon(Icons.light_mode, size: 18)),
                ButtonSegment(value: 'dark', label: Icon(Icons.dark_mode, size: 18)),
              ],
              selected: {ref.watch(appStateControllerProvider).preferredTheme},
              onSelectionChanged: (values) {
                ref.read(appStateControllerProvider.notifier).updateState(
                  (s) => s.copyWith(preferredTheme: values.first),
                );
              },
            ),
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            Text(
              l10n.data,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            _AuthButton(
              icon: Icons.download_rounded,
              label: l10n.loadSampleData,
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
                  SnackBar(content: Text(l10n.sampleDataLoaded)),
                );
              },
            ),
            const SizedBox(height: 12),
            _AuthButton(
              icon: Icons.delete_outline_rounded,
              label: l10n.clearData,
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: Text(l10n.clearDataTitle),
                    content: Text(l10n.clearDataConfirm),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                          ref.read(appStateControllerProvider.notifier).updateState(
                            (s) => s.copyWith(exercises: [], routines: []),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.dataCleared)),
                          );
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(l10n.clear),
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _AuthButton(
              icon: Icons.history_rounded,
              label: 'Clear Workout History',
              onTap: () {
                showDialog(
                  context: context,
                  builder: (dialogContext) => AlertDialog(
                    title: const Text('Clear Workout History?'),
                    content: const Text(
                      'This will delete all workout sessions and performance data. Your exercises and routines will be kept.',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(dialogContext),
                        child: Text(l10n.cancel),
                      ),
                      TextButton(
                        onPressed: () {
                          Navigator.pop(dialogContext);
                          Navigator.pop(context);
                          ref.read(appStateControllerProvider.notifier).updateState(
                            (s) => s.copyWith(sessions: []),
                          );
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Workout history cleared')),
                          );
                        },
                        style: TextButton.styleFrom(foregroundColor: Colors.red),
                        child: Text(l10n.clear),
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
                label: l10n.forceUpdateApp,
                onTap: () async {
                  Navigator.pop(context);
                  await forceUpdateApp();
                },
              ),
            ],
            const SizedBox(height: 24),
            FutureBuilder<PackageInfo>(
              future: PackageInfo.fromPlatform(),
              builder: (context, snapshot) {
                final version = snapshot.data;
                if (version == null) return const SizedBox.shrink();
                return Center(
                  child: Text(
                    'v${version.version}+${version.buildNumber}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.slateInactive,
                      fontSize: 11,
                    ),
                  ),
                );
              },
            ),
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
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.switchAccountTitle),
        content: Text(l10n.switchAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: Text(l10n.switchButton),
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
          SnackBar(content: Text(l10n.signedInRestored)),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10n.signInFailed}: $e')),
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
