// lib/src/features/smart_planner/widgets/plan_preview.dart
import 'package:flutter/material.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:training_engine/training_engine.dart';

import 'session_card.dart';

const _blue600 = Color(0xFF2563EB);
const _slate900 = Color(0xFF0F172A);
const _slate500 = Color(0xFF64748B);
const _slate200 = Color(0xFFE2E8F0);

// ---------------------------------------------------------------------------
// Split type label helper
// ---------------------------------------------------------------------------

String _splitLabel(SplitType split, AppLocalizations l10n) {
  switch (split) {
    case SplitType.fullBody:
      return l10n.fullBody;
    case SplitType.upperLower:
      return l10n.upperLower;
    case SplitType.pushPullLegs:
      return l10n.pushPullLegs;
  }
}

// ---------------------------------------------------------------------------
// Public widget
// ---------------------------------------------------------------------------

/// Displays a generated [WeeklyPlan] as a scrollable list of [SessionCard]s
/// with Regenerate and Adopt Plan action buttons at the bottom.
class PlanPreview extends StatelessWidget {
  const PlanPreview({
    super.key,
    required this.plan,
    required this.editedKeys,
    required this.exerciseNameResolver,
    required this.onExerciseUpdated,
    required this.onExerciseRemoved,
    required this.onExerciseSwapRequested,
    required this.onRegenerate,
    required this.onAdopt,
  });

  final WeeklyPlan plan;

  /// Keys of exercises that have been manually edited (format: "sessionIdx:exerciseIdx").
  final Set<String> editedKeys;

  /// Resolves an exercise ID to a human-readable name.
  final String Function(String exerciseId) exerciseNameResolver;

  /// Called when sets or reps are changed in any session's exercise row.
  final void Function({
    required int sessionIndex,
    required int exerciseIndex,
    required int? sets,
    required int? reps,
  })
  onExerciseUpdated;

  /// Called when an exercise is removed in any session.
  final void Function({required int sessionIndex, required int exerciseIndex})
  onExerciseRemoved;

  /// Called when the user requests to swap an exercise in any session.
  final void Function({required int sessionIndex, required int exerciseIndex})
  onExerciseSwapRequested;

  /// Called when the user taps the Regenerate button.
  final VoidCallback onRegenerate;

  /// Called when the user taps the Adopt Plan button.
  final VoidCallback onAdopt;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final sessionCount = plan.sessions.length;

    return Column(
      children: [
        Expanded(
          child: ListView(
            children: [
              // ---------------------------------------------------------------
              // Header
              // ---------------------------------------------------------------
              Container(
                width: double.infinity,
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _splitLabel(plan.splitType, l10n),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _slate900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.sessionsPerWeek(sessionCount),
                      style: const TextStyle(fontSize: 14, color: _slate500),
                    ),
                    if (plan.engineContextApplied) ...[
                      const SizedBox(height: 6),
                      const Text(
                        'Adjusted using current fatigue and readiness',
                        style: TextStyle(
                          fontSize: 13,
                          color: _slate500,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const Divider(height: 1, color: _slate200),
              const SizedBox(height: 8),

              // ---------------------------------------------------------------
              // Session cards
              // ---------------------------------------------------------------
              for (int i = 0; i < plan.sessions.length; i++)
                SessionCard(
                  session: plan.sessions[i],
                  sessionIndex: i,
                  exerciseNameResolver: exerciseNameResolver,
                  editedKeys: editedKeys,
                  onExerciseUpdated: onExerciseUpdated,
                  onExerciseRemoved: (exerciseIndex) => onExerciseRemoved(
                    sessionIndex: i,
                    exerciseIndex: exerciseIndex,
                  ),
                  onExerciseSwapRequested: (exerciseIndex) =>
                      onExerciseSwapRequested(
                        sessionIndex: i,
                        exerciseIndex: exerciseIndex,
                      ),
                ),

              const SizedBox(height: 8),
            ],
          ),
        ),

        // ---------------------------------------------------------------
        // Action row — fixed at bottom with SafeArea
        // ---------------------------------------------------------------
        SafeArea(
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
            decoration: BoxDecoration(
              color: Colors.white,
              border: Border(top: BorderSide(color: _slate200)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onRegenerate,
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: Text(l10n.regenerate),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _slate900,
                      side: const BorderSide(color: _slate200, width: 1.5),
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: onAdopt,
                    icon: const Icon(Icons.check_circle_outline, size: 18),
                    label: Text(l10n.adoptPlan),
                    style: FilledButton.styleFrom(
                      backgroundColor: _blue600,
                      shape: const StadiumBorder(),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
