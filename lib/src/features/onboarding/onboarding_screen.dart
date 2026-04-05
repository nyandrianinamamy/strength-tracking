import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/core/theme/app_colors.dart';
import 'package:strength_training_tracker/src/data/repository/app_state_repository.dart';
import 'package:strength_training_tracker/src/data/seed/demo_seed_data.dart';
import 'package:strength_training_tracker/src/features/auth/auth_service.dart';

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _pageController = PageController();
  final _nameController = TextEditingController();
  final _ageController = TextEditingController();
  final _weightController = TextEditingController();
  String _selectedUnit = 'kg';
  String _selectedSex = 'male';
  String _selectedGoal = '';
  bool _isSigningIn = false;

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    _ageController.dispose();
    _weightController.dispose();
    super.dispose();
  }

  void _goToNextPage() {
    _pageController.animateToPage(
      1,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  void _goToUnitsPage() {
    _pageController.animateToPage(
      2,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _signInWith(String provider) async {
    setState(() => _isSigningIn = true);
    try {
      final authService = ref.read(authServiceProvider);
      if (provider == 'google') {
        await authService.signInWithGoogle();
      } else {
        await authService.signInWithApple();
      }

      // Load data from the signed-in user's Firestore
      final repository = FirestoreAppStateRepository(auth: authService.firebaseAuth);
      final cloudState = await repository.load();

      // Update the app state with the cloud data
      ref.read(appStateControllerProvider.notifier).replaceState(cloudState);

      if (mounted) context.go('/');
    } catch (e) {
      if (mounted) {
        setState(() => _isSigningIn = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${AppLocalizations.of(context)!.signInFailed}: $e')),
        );
      }
    }
  }

  void _startTraining() {
    final age = int.tryParse(_ageController.text.trim());
    final weight = double.tryParse(_weightController.text.trim());
    ref.read(appStateControllerProvider.notifier).updateState(
      (s) => s.copyWith(
        userName: _nameController.text.trim(),
        preferredUnit: _selectedUnit,
        sex: _selectedSex,
        age: age,
        weight: weight,
        fitnessGoal: _selectedGoal,
      ),
    );
    context.go('/');
  }

  void _loadDemoData() {
    final demoState = DemoSeedData.initialState();
    ref.read(appStateControllerProvider.notifier).replaceState(demoState);
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: PageView(
          controller: _pageController,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            _buildWelcomePage(context),
            _buildAboutYouPage(context),
            _buildUnitsPage(context),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              child: Icon(
                Icons.fitness_center_rounded,
                size: 64,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.letsGetStarted,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.whatShouldWeCallYou,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.appColors.subtleText,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _nameController,
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge,
              decoration: InputDecoration(
                hintText: l10n.yourName,
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed:
                    _nameController.text.trim().isEmpty ? null : _goToNextPage,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.next),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _loadDemoData,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.play_circle_outline),
                label: Text(l10n.tryWithDemoData),
              ),
            ),
            const SizedBox(height: 40),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    l10n.orSignIn,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: context.appColors.subtleText,
                    ),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _isSigningIn ? null : () => _signInWith('google'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const Icon(Icons.g_mobiledata),
                label: Text(l10n.continueWithGoogle),
              ),
            ),
            if (_isSigningIn) ...[
              const SizedBox(height: 16),
              const CircularProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAboutYouPage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.aboutYou,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.optional,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.appColors.subtleText,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              l10n.sex,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
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
              selected: {_selectedSex},
              onSelectionChanged: (values) =>
                  setState(() => _selectedSex = values.first),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: l10n.age,
                suffixText: l10n.years,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _weightController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                labelText: l10n.weight,
                suffixText: _selectedUnit.toUpperCase(),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.fitnessGoal,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ('strength', l10n.goalStrength),
                ('hypertrophy', l10n.goalHypertrophy),
                ('endurance', l10n.goalEndurance),
                ('weight_loss', l10n.goalWeightLoss),
                ('general_fitness', l10n.goalGeneralFitness),
              ].map((entry) {
                final (value, label) = entry;
                return ChoiceChip(
                  label: Text(label),
                  selected: _selectedGoal == value,
                  onSelected: (selected) => setState(
                    () => _selectedGoal = selected ? value : '',
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _goToUnitsPage,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.next),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUnitsPage(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              l10n.chooseYourUnit,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.changeAnytime,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: context.appColors.subtleText,
              ),
            ),
            const SizedBox(height: 32),
            Row(
              children: [
                Expanded(
                  child: _UnitCard(
                    unit: 'kg',
                    label: 'KG',
                    subtitle: l10n.kilograms,
                    selected: _selectedUnit == 'kg',
                    onTap: () => setState(() => _selectedUnit = 'kg'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _UnitCard(
                    unit: 'lbs',
                    label: 'LBS',
                    subtitle: l10n.pounds,
                    selected: _selectedUnit == 'lbs',
                    onTap: () => setState(() => _selectedUnit = 'lbs'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _startTraining,
                style: FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(l10n.startTraining),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UnitCard extends StatelessWidget {
  const _UnitCard({
    required this.unit,
    required this.label,
    required this.subtitle,
    required this.selected,
    required this.onTap,
  });

  final String unit;
  final String label;
  final String subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(vertical: 24),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected
                ? Theme.of(context).colorScheme.primary
                : context.appColors.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              label,
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              subtitle,
              style: theme.textTheme.bodySmall?.copyWith(
                color: selected
                    ? Theme.of(context).colorScheme.onPrimary.withValues(alpha: 0.7)
                    : context.appColors.subtleText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
