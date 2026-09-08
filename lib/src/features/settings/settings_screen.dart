import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/external_url_opener.dart';
import 'package:strength_training_tracker/src/core/legal_links.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/features/auth/account_session_controller.dart';
import 'package:strength_training_tracker/src/data/repository/account_app_state_repository.dart';
import 'package:strength_training_tracker/src/features/settings/account_deletion_service.dart';
import 'package:strength_training_tracker/src/features/settings/library_cleanup.dart';
import 'package:strength_training_tracker/src/features/training_engine/healthkit_data_source.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;

  @override
  void initState() {
    super.initState();
    final state = ref.read(appStateControllerProvider);
    _nameController = TextEditingController(text: state.userName);
    _ageController = TextEditingController(
      text: state.age != null ? '${state.age}' : '',
    );
    _weightController = TextEditingController(
      text: state.weight != null ? '${state.weight}' : '',
    );
    _syncHealthKitStatus();
  }

  /// Sync the toggle with actual HealthKit authorization status on iOS.
  Future<void> _syncHealthKitStatus() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final state = ref.read(appStateControllerProvider);
    if (!state.healthKitEnabled) return;
    // If user had previously enabled it, verify we still have access
    final authorized = await const HealthKitDataSource().requestAuthorization();
    if (!authorized && mounted) {
      ref
          .read(appStateControllerProvider.notifier)
          .updateState((s) => s.copyWith(healthKitEnabled: false));
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    ref
        .read(appStateControllerProvider.notifier)
        .updateState((state) => state.copyWith(userName: value));
  }

  void _onAgeChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      ref
          .read(appStateControllerProvider.notifier)
          .updateState((s) => s.copyWith(clearAge: true));
      return;
    }
    final parsed = int.tryParse(trimmed);
    if (parsed != null && parsed > 0) {
      ref
          .read(appStateControllerProvider.notifier)
          .updateState((s) => s.copyWith(age: parsed));
    }
  }

  void _onWeightChanged(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      ref
          .read(appStateControllerProvider.notifier)
          .updateState((s) => s.copyWith(clearWeight: true));
      return;
    }
    final parsed = double.tryParse(trimmed);
    if (parsed != null && parsed > 0) {
      ref
          .read(appStateControllerProvider.notifier)
          .updateState((s) => s.copyWith(weight: parsed));
    }
  }

  Future<({String email, String password})?> _promptEmailCredentials() async {
    final l10n = AppLocalizations.of(context)!;
    var email = '';
    var password = '';
    // The fields own their controllers until the closing route unmounts.
    return showDialog<({String email, String password})>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signInWithEmail),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              onChanged: (value) => email = value,
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
              decoration: InputDecoration(labelText: l10n.email),
            ),
            const SizedBox(height: 12),
            TextField(
              onChanged: (value) => password = value,
              obscureText: true,
              autofillHints: const [AutofillHints.password],
              decoration: InputDecoration(labelText: l10n.password),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (email.trim().isEmpty || password.isEmpty) return;
              Navigator.pop(dialogContext, (
                email: email.trim(),
                password: password,
              ));
            },
            child: Text(l10n.switchButton),
          ),
        ],
      ),
    );
  }

  Future<void> _signInAndReplace(
    String provider, {
    String? email,
    String? password,
  }) async {
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
            style: TextButton.styleFrom(
              foregroundColor: context.appColors.warning,
            ),
            child: Text(l10n.switchButton),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final auth = ref.read(authServiceProvider);
      await ref
          .read(accountSessionControllerProvider)
          .signIn(
            () => switch (provider) {
              'apple' => auth.signInWithApple(),
              'email' => auth.signInWithEmailAndPassword(
                email: email!,
                password: password!,
              ),
              _ => auth.signInWithGoogle(),
            },
          );
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.signedInRestored)));
      }
    } on AuthOperationCancelled {
      // Nothing changed when provider selection was cancelled.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.signInFailed}: $error')));
      }
    }
  }

  Future<void> _signInWithEmailAndReplace() async {
    final credentials = await _promptEmailCredentials();
    if (credentials == null || !mounted) return;
    await _signInAndReplace(
      'email',
      email: credentials.email,
      password: credentials.password,
    );
  }

  Future<void> _signOutAndReset() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.signOutTitle),
        content: Text(l10n.signOutConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.signOut),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(accountSessionControllerProvider).signOut();

      // Navigate directly to onboarding rather than relying on the
      // router redirect (which keys off userName.isEmpty and could
      // false-trigger if a user simply clears their display name).
      if (mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      if (mounted) {
        final l10nInner = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${l10nInner.signInFailed}: $e')),
        );
      }
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.deleteAccountTitle),
        content: Text(l10n.deleteAccountConfirm),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final app = ref.read(appStateControllerProvider.notifier);
    final transition = ref.read(accountTransitionInProgressProvider.notifier);
    final accountSession = ref.read(accountSessionControllerProvider);
    transition.state = true;
    try {
      final auth = ref.read(authServiceProvider);
      final userId = auth.currentUser?.uid;
      final repository = app.repository;
      if (userId == null ||
          repository is! AccountAppStateRepository ||
          repository.accountId != userId ||
          repository.remote == null) {
        throw StateError('No connected account to delete');
      }
      await app.pauseSync();
      final cloud = repository.remote!;
      String? appleAuthorizationCode;
      final deletion = AccountDeletionService(
        reauthenticate: () async {
          switch (auth.currentProviderId) {
            case 'password':
              final password = await _promptDeletionPassword();
              if (password == null) throw const AccountDeletionCancelled();
              await auth.reauthenticateWithEmailPassword(password);
            case 'google.com':
              await auth.reauthenticateWithGoogle();
            case 'apple.com':
              appleAuthorizationCode = await auth.reauthenticateWithApple();
          }
          if (auth.currentUser?.uid != userId) {
            throw StateError('Account ownership changed');
          }
          return cloud.load();
        },
        deleteUserData: cloud.deleteUserData,
        deleteCurrentUser: auth.deleteCurrentUser,
        restoreUserData: cloud.save,
        clearLocalState: () => accountSession.accountDeleted(userId),
        finalizeProviderDeletion: () async {
          if (appleAuthorizationCode != null) {
            await auth.revokeAppleToken(appleAuthorizationCode!);
          }
        },
      );
      final result = await deletion.deleteAccount();
      if (mounted) {
        context.go('/onboarding');
        if (result.providerCleanupError != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.accountDeletedProviderCleanupFailed)),
          );
        }
      }
    } on AccountDeletionCancelled {
      // No destructive operation has happened.
    } on AuthOperationCancelled {
      // No destructive operation has happened.
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedError('$error'))));
      }
    } finally {
      app.resumeSync();
      transition.state = false;
    }
  }

  Future<String?> _promptDeletionPassword() async {
    final l10n = AppLocalizations.of(context)!;
    var password = '';
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.reauthenticateToDelete),
        content: TextField(
          onChanged: (value) => password = value,
          obscureText: true,
          decoration: InputDecoration(labelText: l10n.password),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () {
              if (password.isNotEmpty) {
                Navigator.pop(dialogContext, password);
              }
            },
            child: Text(l10n.deleteAccount),
          ),
        ],
      ),
    );
  }

  Future<void> _resolveStorageConflict(bool keepDevice) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          keepDevice ? l10n.storageKeepDevice : l10n.storageUseAccount,
        ),
        content: Text(l10n.storageConflictRecovery),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final transition = ref.read(accountTransitionInProgressProvider.notifier);
    transition.state = true;
    try {
      await ref
          .read(appStateControllerProvider.notifier)
          .resolveConflict(keepDevice: keepDevice);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedError('$error'))));
      }
    } finally {
      transition.state = false;
    }
  }

  Future<void> _restoreStorageRecovery() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.storageRecoveryCopy),
        content: Text(l10n.storageConflictRecovery),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(l10n.cancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(l10n.save),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    final transition = ref.read(accountTransitionInProgressProvider.notifier);
    transition.state = true;
    try {
      await ref.read(appStateControllerProvider.notifier).restoreRecoveryCopy();
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedError('$error'))));
      }
    } finally {
      transition.state = false;
    }
  }

  Future<void> _openLegalLink(Uri url) async {
    try {
      await const ExternalUrlOpener().open(url);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.failedError('$e'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final authService = ref.read(authServiceProvider);
    final connectedUser = authService.currentUser;
    final user = connectedUser?.uid == ref.watch(boundAccountIdProvider)
        ? connectedUser
        : null;
    final saveStatus = ref.watch(appSaveStatusProvider);
    final storageLabel = switch (saveStatus) {
      AppSaveStatus.saved => l10n.storageSaved,
      AppSaveStatus.saving => l10n.storageSaving,
      AppSaveStatus.local => l10n.storageLocal,
      AppSaveStatus.pending => l10n.storagePending,
      AppSaveStatus.syncFailed => l10n.storageSyncFailed,
      AppSaveStatus.localFailed => l10n.storageLocalFailed,
      AppSaveStatus.conflict => l10n.storageConflict,
      AppSaveStatus.capacityExceeded => l10n.storageCapacityExceeded,
    };

    // Resync text controllers when state changes externally
    // (e.g., sign-in replaces state with cloud data).
    // Compare parsed values (not strings) for numeric fields to avoid
    // overwriting mid-edit — e.g. user types "7" → state becomes 7.0 →
    // "7" != "7.0" would cause a spurious overwrite.
    ref.listen(appStateControllerProvider, (_, next) {
      if (_nameController.text != next.userName) {
        _nameController.text = next.userName;
      }
      if (int.tryParse(_ageController.text.trim()) != next.age) {
        _ageController.text = next.age != null ? '${next.age}' : '';
      }
      if (double.tryParse(_weightController.text.trim()) != next.weight) {
        _weightController.text = next.weight != null ? '${next.weight}' : '';
      }
    });

    return AbsorbPointer(
      absorbing: ref.watch(accountTransitionInProgressProvider),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.settings)),
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              PageSection(
                title: l10n.storageStatusTitle,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      storageLabel,
                      key: const ValueKey('storage-save-status'),
                    ),
                    if (saveStatus == AppSaveStatus.pending ||
                        saveStatus == AppSaveStatus.syncFailed ||
                        saveStatus == AppSaveStatus.localFailed ||
                        saveStatus == AppSaveStatus.capacityExceeded)
                      TextButton(
                        onPressed: () => ref
                            .read(appStateControllerProvider.notifier)
                            .retrySave(),
                        child: Text(l10n.storageRetry),
                      ),
                    if (saveStatus == AppSaveStatus.conflict) ...[
                      TextButton(
                        onPressed: () => _resolveStorageConflict(true),
                        child: Text(l10n.storageKeepDevice),
                      ),
                      TextButton(
                        onPressed: () => _resolveStorageConflict(false),
                        child: Text(l10n.storageUseAccount),
                      ),
                    ],
                    if (ref.read(appStateControllerProvider.notifier).repository
                        case AccountAppStateRepository(hasRecoveryCopy: true))
                      TextButton(
                        onPressed: _restoreStorageRecovery,
                        child: Text(l10n.storageRecoveryCopy),
                      ),
                  ],
                ),
              ),
              // ---------------------------------------------------------------
              // Profile section
              // ---------------------------------------------------------------
              const SizedBox(height: 24),
              PageSection(
                title: l10n.profile,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Name
                    TextField(
                      controller: _nameController,
                      decoration: InputDecoration(labelText: l10n.yourName),
                      onChanged: _onNameChanged,
                    ),
                    const SizedBox(height: 16),

                    // Sex
                    Text(
                      l10n.sex,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(
                          value: 'male',
                          label: Text(l10n.male),
                          icon: const Icon(Icons.male, size: 18),
                        ),
                        ButtonSegment(
                          value: 'female',
                          label: Text(l10n.female),
                          icon: const Icon(Icons.female, size: 18),
                        ),
                      ],
                      selected: {state.sex},
                      onSelectionChanged: (values) {
                        ref
                            .read(appStateControllerProvider.notifier)
                            .updateState((s) => s.copyWith(sex: values.first));
                      },
                    ),
                    const SizedBox(height: 16),

                    // Age
                    TextField(
                      controller: _ageController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(
                        labelText: l10n.age,
                        suffixText: l10n.years,
                      ),
                      onChanged: _onAgeChanged,
                    ),
                    const SizedBox(height: 16),

                    // Weight
                    TextField(
                      controller: _weightController,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InputDecoration(
                        labelText: l10n.weight,
                        suffixText: state.preferredUnit.toUpperCase(),
                      ),
                      onChanged: _onWeightChanged,
                    ),
                    const SizedBox(height: 16),

                    // Fitness Goal
                    Text(
                      l10n.fitnessGoal,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children:
                          [
                            ('strength', l10n.goalStrength),
                            ('hypertrophy', l10n.goalHypertrophy),
                            ('endurance', l10n.goalEndurance),
                            ('weight_loss', l10n.goalWeightLoss),
                            ('general_fitness', l10n.goalGeneralFitness),
                          ].map((entry) {
                            final value = entry.$1;
                            final label = entry.$2;
                            final isSelected = state.fitnessGoal == value;
                            return ChoiceChip(
                              label: Text(label),
                              selected: isSelected,
                              onSelected: (selected) {
                                ref
                                    .read(appStateControllerProvider.notifier)
                                    .updateState(
                                      (s) => s.copyWith(
                                        fitnessGoal: isSelected ? '' : value,
                                      ),
                                    );
                              },
                            );
                          }).toList(),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // Preferences section
              // ---------------------------------------------------------------
              PageSection(
                title: l10n.preferences,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Unit
                    Text(
                      l10n.unitPreference,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'kg', label: Text('KG')),
                        ButtonSegment(value: 'lbs', label: Text('LBS')),
                      ],
                      selected: {state.preferredUnit},
                      onSelectionChanged: (values) {
                        ref
                            .read(appStateControllerProvider.notifier)
                            .updateState(
                              (s) => s.copyWith(preferredUnit: values.first),
                            );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Weekly training target
                    Text(
                      l10n.weeklyTrainingTarget,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.weeklyTrainingTargetDetail,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.subtleText,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: List.generate(6, (index) {
                        final days = index + 1;
                        return ChoiceChip(
                          label: Text(l10n.daysPerWeek(days)),
                          selected: state.weeklyTrainingTargetDays == days,
                          onSelected: (selected) {
                            if (!selected) return;
                            ref
                                .read(appStateControllerProvider.notifier)
                                .updateState(
                                  (s) => s.copyWith(
                                    weeklyTrainingTargetDays: days,
                                  ),
                                );
                          },
                        );
                      }),
                    ),
                    const SizedBox(height: 20),

                    // Language
                    Text(
                      l10n.language,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: '', label: Text(l10n.autoLabel)),
                        const ButtonSegment(value: 'en', label: Text('EN')),
                        const ButtonSegment(value: 'fr', label: Text('FR')),
                      ],
                      selected: {state.preferredLanguage},
                      onSelectionChanged: (values) {
                        ref
                            .read(appStateControllerProvider.notifier)
                            .updateState(
                              (s) =>
                                  s.copyWith(preferredLanguage: values.first),
                            );
                      },
                    ),
                    const SizedBox(height: 20),

                    // Theme
                    Text(
                      l10n.themeLabel,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        ButtonSegment(value: '', label: Text(l10n.autoLabel)),
                        const ButtonSegment(
                          value: 'light',
                          label: Icon(Icons.light_mode, size: 18),
                        ),
                        const ButtonSegment(
                          value: 'dark',
                          label: Icon(Icons.dark_mode, size: 18),
                        ),
                      ],
                      selected: {state.preferredTheme},
                      onSelectionChanged: (values) {
                        ref
                            .read(appStateControllerProvider.notifier)
                            .updateState(
                              (s) => s.copyWith(preferredTheme: values.first),
                            );
                      },
                    ),
                  ],
                ),
              ),

              // ---------------------------------------------------------------
              // Integrations section (iOS only)
              // ---------------------------------------------------------------
              if (defaultTargetPlatform == TargetPlatform.iOS) ...[
                const SizedBox(height: 32),
                PageSection(
                  title: l10n.integrations,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.appleHealth,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(l10n.sleepAndHrv),
                        subtitle: Text(
                          l10n.sleepHrvDescription,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: context.appColors.subtleText),
                        ),
                        value: state.healthKitEnabled,
                        onChanged: (enabled) async {
                          if (enabled) {
                            final authorized = await const HealthKitDataSource()
                                .requestAuthorization();
                            if (!mounted) return;
                            ref
                                .read(appStateControllerProvider.notifier)
                                .updateState(
                                  (s) =>
                                      s.copyWith(healthKitEnabled: authorized),
                                );
                          } else {
                            ref
                                .read(appStateControllerProvider.notifier)
                                .updateState(
                                  (s) => s.copyWith(healthKitEnabled: false),
                                );
                          }
                        },
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // Account section
              // ---------------------------------------------------------------
              PageSection(
                title: l10n.account,
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 32,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.1),
                      child: Icon(
                        user == null ? Icons.person_outline : Icons.person,
                        size: 32,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      user?.displayName ?? user?.email ?? l10n.linkedAccount,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      user?.email ?? l10n.inviteOnlyMessage,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.subtleText,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      storageLabel,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: context.appColors.subtleText,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.logout_rounded,
                      label: l10n.signOut,
                      onTap: _signOutAndReset,
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.delete_forever_rounded,
                      label: l10n.deleteAccount,
                      onTap: _deleteAccount,
                    ),
                    const SizedBox(height: 20),
                    Row(
                      children: [
                        const Expanded(child: Divider()),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          child: Text(
                            l10n.switchAccount,
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(color: context.appColors.subtleText),
                          ),
                        ),
                        const Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.switchWarning,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.warning,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.email_outlined,
                      label: l10n.signInWithEmail,
                      onTap: _signInWithEmailAndReplace,
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.apple,
                      label: l10n.signInApple,
                      onTap: () => _signInAndReplace('apple'),
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.g_mobiledata,
                      label: l10n.signInGoogle,
                      onTap: () => _signInAndReplace('google'),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // Data section
              // ---------------------------------------------------------------
              PageSection(
                title: l10n.data,
                child: Column(
                  children: [
                    if (kDebugMode) ...[
                      _AuthButton(
                        icon: Icons.download_rounded,
                        label: l10n.loadSampleData,
                        onTap: () {
                          final sample = DemoSeedData.initialState();
                          ref
                              .read(appStateControllerProvider.notifier)
                              .updateState(
                                (s) => s.copyWith(
                                  exercises: [
                                    ...s.exercises,
                                    ...sample.exercises,
                                  ],
                                  routines: [...s.routines, ...sample.routines],
                                  routineGroups: [
                                    ...s.routineGroups,
                                    ...sample.routineGroups,
                                  ],
                                  activeRoutineGroupId:
                                      s.activeRoutineGroupId ??
                                      sample.activeRoutineGroupId,
                                ),
                              );
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(l10n.sampleDataLoaded)),
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
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
                                  ref
                                      .read(appStateControllerProvider.notifier)
                                      .updateState(
                                        clearLibraryPreservingHistory,
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text(l10n.dataCleared)),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
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
                      label: l10n.clearWorkoutHistory,
                      onTap: () {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: Text(l10n.clearWorkoutHistoryConfirm),
                            content: Text(l10n.clearWorkoutHistoryMessage),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(dialogContext),
                                child: Text(l10n.cancel),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(dialogContext);
                                  ref
                                      .read(appStateControllerProvider.notifier)
                                      .updateState(
                                        (s) => s.copyWith(
                                          sessions: [],
                                          routineGroups: s.routineGroups
                                              .map(
                                                (group) => group.copyWith(
                                                  pendingRoutineIds:
                                                      group.routineIds,
                                                ),
                                              )
                                              .toList(),
                                        ),
                                      );
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(l10n.workoutHistoryCleared),
                                    ),
                                  );
                                },
                                style: TextButton.styleFrom(
                                  foregroundColor: Theme.of(
                                    context,
                                  ).colorScheme.error,
                                ),
                                child: Text(l10n.clear),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // Legal section
              // ---------------------------------------------------------------
              PageSection(
                title: l10n.legal,
                child: Column(
                  children: [
                    _AuthButton(
                      icon: Icons.privacy_tip_outlined,
                      label: l10n.privacyPolicy,
                      onTap: () => _openLegalLink(kotranaPrivacyPolicyUrl),
                    ),
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.article_outlined,
                      label: l10n.termsOfUse,
                      onTap: () => _openLegalLink(kotranaTermsUrl),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // ---------------------------------------------------------------
              // App version
              // ---------------------------------------------------------------
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snapshot) {
                  final version = snapshot.data;
                  if (version == null) return const SizedBox.shrink();
                  return Center(
                    child: Text(
                      'v${version.version}+${version.buildNumber}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: context.appColors.subtleText,
                        fontSize: 11,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
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
