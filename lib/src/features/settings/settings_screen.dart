import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/external_url_opener.dart';
import 'package:strength_training_tracker/src/core/legal_links.dart';
import 'package:strength_training_tracker/src/core/utils/force_update.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';
import 'package:strength_training_tracker/src/features/auth/invite_access.dart';
import 'package:strength_training_tracker/src/features/settings/account_deletion_service.dart';
import 'package:strength_training_tracker/src/features/training_engine/healthkit_data_source.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  late TextEditingController _nameController;
  late TextEditingController _ageController;
  late TextEditingController _weightController;

  Timer? _nameDebounce;

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
    _nameDebounce?.cancel();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _onNameChanged(String value) {
    _nameDebounce?.cancel();
    _nameDebounce = Timer(const Duration(milliseconds: 500), () {
      ref
          .read(appStateControllerProvider.notifier)
          .updateState((s) => s.copyWith(userName: value));
    });
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
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    try {
      return showDialog<({String email, String password})>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.signInWithEmail),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                decoration: InputDecoration(labelText: l10n.email),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: passwordController,
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
                final email = emailController.text.trim();
                final password = passwordController.text;
                if (email.isEmpty || password.isEmpty) return;
                Navigator.pop(dialogContext, (
                  email: email,
                  password: password,
                ));
              },
              child: Text(l10n.switchButton),
            ),
          ],
        ),
      );
    } finally {
      emailController.dispose();
      passwordController.dispose();
    }
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

    var replacementSignedIn = false;
    try {
      final authService = ref.read(authServiceProvider);
      if (provider == 'apple') {
        await authService.signInWithApple();
        replacementSignedIn = true;
      } else if (provider == 'email') {
        await authService.signInWithEmailAndPassword(
          email: email!,
          password: password!,
        );
        replacementSignedIn = true;
      } else {
        await authService.signInWithGoogle();
        replacementSignedIn = true;
      }

      await InviteAccessService().requireAllowed(authService.currentUser);

      final repository = FirestoreAppStateRepository(
        auth: authService.firebaseAuth,
      );
      final cloudState = await repository.load();

      ref.read(appStateControllerProvider.notifier).replaceState(cloudState);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.signedInRestored)));
      }
    } catch (e) {
      final authService = ref.read(authServiceProvider);
      if (replacementSignedIn && authService.currentUser != null) {
        await authService.signOut();
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l10n.signInFailed}: $e')));
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
      // Clear in-memory state first (no Firestore write) so there is
      // never a moment where a valid auth session coexists with stale
      // profile data that could be accidentally persisted.
      ref.read(appStateControllerProvider.notifier).clearLocal();

      final authService = ref.read(authServiceProvider);
      await authService.signOut();

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

    try {
      final authService = ref.read(authServiceProvider);
      final providers =
          authService.currentUser?.providerData
              .map((provider) => provider.providerId)
              .toList() ??
          const [];
      final isAppleUser = providers.contains('apple.com');

      String? appleAuthorizationCode;
      if (!kIsWeb && isAppleUser) {
        final appleCredential = await SignInWithApple.getAppleIDCredential(
          scopes: [AppleIDAuthorizationScopes.email],
        );
        appleAuthorizationCode = appleCredential.authorizationCode;
      }

      final deletionService = AccountDeletionService(
        deleteUserData: ref.read(appStateRepositoryProvider).deleteUserData,
        deleteCurrentUser: authService.deleteCurrentUser,
        clearLocalState: ref
            .read(appStateControllerProvider.notifier)
            .clearLocal,
        revokeAppleToken: authService.revokeAppleToken,
      );

      await deletionService.deleteAccount(
        appleAuthorizationCode: appleAuthorizationCode,
      );

      if (mounted) {
        context.go('/onboarding');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.failedError('$e'))));
      }
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
    final user = authService.currentUser;

    // Resync text controllers when state changes externally
    // (e.g., sign-in replaces state with cloud data).
    // Compare parsed values (not strings) for numeric fields to avoid
    // overwriting mid-edit — e.g. user types "7" → state becomes 7.0 →
    // "7" != "7.0" would cause a spurious overwrite.
    ref.listen(appStateControllerProvider, (_, next) {
      if (_nameController.text != next.userName) {
        _nameDebounce?.cancel();
        _nameController.text = next.userName;
      }
      if (int.tryParse(_ageController.text.trim()) != next.age) {
        _ageController.text = next.age != null ? '${next.age}' : '';
      }
      if (double.tryParse(_weightController.text.trim()) != next.weight) {
        _weightController.text = next.weight != null ? '${next.weight}' : '';
      }
    });

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settings)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                            (s) => s.copyWith(preferredLanguage: values.first),
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
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: context.appColors.subtleText,
                        ),
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
                                (s) => s.copyWith(healthKitEnabled: authorized),
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
                    l10n.dataSynced,
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
                                      (s) => s.copyWith(
                                        exercises: [],
                                        routines: [],
                                        routineGroups: [],
                                        sessions: [],
                                        clearActiveRoutineGroupId: true,
                                      ),
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
                  if (kIsWeb) ...[
                    const SizedBox(height: 12),
                    _AuthButton(
                      icon: Icons.refresh_rounded,
                      label: l10n.forceUpdateApp,
                      onTap: () async {
                        await forceUpdateApp();
                      },
                    ),
                  ],
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
