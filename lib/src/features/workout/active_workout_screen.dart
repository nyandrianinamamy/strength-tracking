import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:strength_training_tracker/l10n/app_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/data/models/completed_set.dart';
import 'package:strength_training_tracker/src/core/theme/app_theme.dart';
import 'package:strength_training_tracker/src/core/utils/formatters.dart';
import 'package:strength_training_tracker/src/data/models/app_state.dart';
import 'package:strength_training_tracker/src/data/models/routine.dart';
import 'package:strength_training_tracker/src/data/models/workout_session.dart';
import 'package:strength_training_tracker/src/features/workout/workout_controller.dart';
import 'package:flutter_body_heatmap/flutter_body_heatmap.dart';
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_service.dart';
import 'package:strength_training_tracker/src/l10n/exercise_translations.dart';
import 'package:strength_training_tracker/src/shared/widgets/common_widgets.dart';

class ActiveWorkoutScreen extends ConsumerStatefulWidget {
  const ActiveWorkoutScreen({super.key});

  @override
  ConsumerState<ActiveWorkoutScreen> createState() =>
      _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends ConsumerState<ActiveWorkoutScreen>
    with SingleTickerProviderStateMixin {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  final _setNoteController = TextEditingController();
  late final Timer _ticker;
  late final PageController _pageController;
  String? _lastExerciseId;
  int _currentPage = 0;

  // Rest timer beep tracking — tracks set count to know when a new set was logged
  int _lastBeepedSetCount = -1;

  // Timed exercise countdown state
  DateTime? _timedExerciseStart;
  int _timedExerciseDuration = 0;
  bool _timedExerciseRunning = false;
  bool _timedExerciseBeeped = false;

  // Auto-switch countdown when all sets completed
  int? _switchCountdown; // null = not counting, 5..0 = counting down
  int? _switchTargetPage;

  // Swipe hint arrows
  late final AnimationController _arrowAnimController;
  late final Animation<double> _arrowOpacity;
  bool _arrowsVisible = false;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) {
        // Rest timer beep — check if rest just finished
        if (_remainingRest == 0 && _lastBeepedSetCount != _currentSetCount) {
          // A set was logged and rest has now elapsed
          if (_currentSetCount > 0) {
            _playRestTimerBeep();
          }
          _lastBeepedSetCount = _currentSetCount;
        }
        // Auto-switch countdown
        if (_switchCountdown != null) {
          _switchCountdown = _switchCountdown! - 1;
          if (_switchCountdown! <= 0) {
            final target = _switchTargetPage;
            _switchCountdown = null;
            _switchTargetPage = null;
            if (target != null && _pageController.hasClients) {
              _currentPage = target;
              _pageController.animateToPage(
                target,
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            }
          }
        }
        // Timed exercise auto-log when countdown reaches zero
        if (_timedExerciseRunning && _timedCountdownRemaining <= 0 && !_timedExerciseBeeped) {
          _timedExerciseBeeped = true;
          _playRestTimerBeep();
          _autoLogTimedSet();
        }
        setState(() {});
      }
    });

    final state = ref.read(appStateControllerProvider);
    final session = state.activeSession;
    _currentPage = session?.currentExerciseIndex ?? 0;
    _pageController = PageController(
      initialPage: _currentPage,
    );

    _arrowAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _arrowOpacity = CurvedAnimation(
      parent: _arrowAnimController,
      curve: Curves.easeOut,
    );
  }

  @override
  void dispose() {
    _ticker.cancel();
    _weightController.dispose();
    _repsController.dispose();
    _setNoteController.dispose();
    _pageController.dispose();
    _arrowAnimController.dispose();
    super.dispose();
  }

  // Timed exercise helpers
  int get _timedCountdownRemaining {
    if (_timedExerciseStart == null || !_timedExerciseRunning) {
      return _timedExerciseDuration;
    }
    final elapsed = DateTime.now().difference(_timedExerciseStart!).inSeconds;
    return (_timedExerciseDuration - elapsed).clamp(0, 9999);
  }

  void _startTimedExercise(int durationSeconds) {
    setState(() {
      _timedExerciseDuration = durationSeconds;
      _timedExerciseStart = DateTime.now();
      _timedExerciseRunning = true;
      _timedExerciseBeeped = false;
    });
  }

  void _pauseTimedExercise() {
    setState(() {
      _timedExerciseDuration = _timedCountdownRemaining;
      _timedExerciseStart = null;
      _timedExerciseRunning = false;
    });
  }

  void _resetTimedExercise(int durationSeconds) {
    setState(() {
      _timedExerciseDuration = durationSeconds;
      _timedExerciseStart = null;
      _timedExerciseRunning = false;
      _timedExerciseBeeped = false;
    });
  }

  void _autoLogTimedSet() {
    final state = ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return;

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) return;

    final prescription = routine.exercises[_currentPage];
    ref.read(workoutControllerProvider).logTimedSet(
      durationSeconds: prescription.targetDurationSeconds,
      note: _setNoteController.text.trim(),
    );
    _setNoteController.clear();
    _resetTimedExercise(prescription.targetDurationSeconds);
    _resetRestTimer(prescription.restSeconds);
  }

  void _showArrows() {
    if (_arrowsVisible) return;
    _arrowsVisible = true;
    _arrowAnimController.forward(from: 0);
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _arrowAnimController.reverse().then((_) {
          if (mounted) _arrowsVisible = false;
        });
      }
    });
  }

  void _playRestTimerBeep() async {
    for (int i = 0; i < 3; i++) {
      SystemSound.play(SystemSoundType.click);
      if (i < 2) await Future.delayed(const Duration(milliseconds: 200));
    }
  }

  void _resetRestTimer(int restSeconds) {
    setState(() {});
    // Auto-advance page if the exercise index changed after logging a set
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final session = ref.read(appStateControllerProvider).activeSession;
      if (session != null &&
          _pageController.hasClients &&
          session.currentExerciseIndex != _currentPage) {
        // Start a 5-second countdown before switching
        setState(() {
          _switchCountdown = 5;
          _switchTargetPage = session.currentExerciseIndex;
        });
      }
    });
  }

  int get _remainingRest {
    // Compute from persisted data so it survives app switches
    final state = ref.read(appStateControllerProvider);
    final session = state.activeSession;
    if (session == null) return 0;

    if (session.completedSets.isEmpty) return 0;

    // Use the most recent set across ALL exercises for a shared rest timer
    final allSets = [...session.completedSets]
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));
    final lastSet = allSets.first;

    // Find the rest seconds from the exercise that the last set belongs to
    final routine = state.routineById(session.routineId);
    if (routine == null) return 0;

    final prescription = routine.exercises
        .where((e) => e.exerciseId == lastSet.exerciseId)
        .firstOrNull;
    final restSeconds = prescription?.restSeconds ?? 90;

    final elapsed = DateTime.now().difference(lastSet.completedAt).inSeconds;
    return (restSeconds - elapsed).clamp(0, 999);
  }

  int get _currentSetCount {
    final session = ref.read(appStateControllerProvider).activeSession;
    return session?.completedSets.length ?? 0;
  }

  void _showCommentDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text(l10n.setComment),
          content: TextField(
            controller: _setNoteController,
            autofocus: true,
            maxLines: 3,
            decoration: InputDecoration(
              hintText: l10n.setCommentHint,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l10n.done),
            ),
          ],
        );
      },
    );
  }

  void _showFinishConfirmation(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(workoutControllerProvider);
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
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
                const Icon(
                  Icons.flag_rounded,
                  size: 48,
                  color: AppTheme.primary,
                ),
                const SizedBox(height: 16),
                Text(
                  l10n.finishWorkout,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.sessionSaved,
                  textAlign: TextAlign.center,
                  style: Theme.of(sheetContext)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(color: AppTheme.slateInactive),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    final completed = controller.completeSession();
                    if (completed != null) {
                      context.go('/workout/${completed.id}/summary');
                    }
                  },
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(l10n.finishSave),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: Text(l10n.keepTraining),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    controller.discardDraft();
                    context.go('/');
                  },
                  child: Text(
                    l10n.discardSession,
                    style: TextStyle(
                      color: Colors.red.shade400,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSwapPicker(
    BuildContext context,
    AppState state,
    Routine routine,
    int pageIndex,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final prescription = routine.exercises[pageIndex];
    final currentExercise = state.exerciseById(prescription.exerciseId);
    final currentMuscles = currentExercise?.primaryMuscles ?? [];

    final alternatives = state.exercises.where((e) {
      if (e.archived || e.id == currentExercise?.id) return false;
      return e.primaryMuscles.any((m) => currentMuscles.contains(m));
    }).toList();

    final searchController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (ctx, setSheetState) {
            final query = searchController.text.toLowerCase();
            final filtered = query.isEmpty
                ? alternatives
                : alternatives.where((e) {
                    final name = ExerciseTranslations.displayName(context, e).toLowerCase();
                    final muscles = e.primaryMuscles.join(' ').toLowerCase();
                    return name.contains(query) || muscles.contains(query);
                  }).toList();

            return DraggableScrollableSheet(
              initialChildSize: 0.6,
              minChildSize: 0.4,
              maxChildSize: 0.9,
              expand: false,
              builder: (_, scrollController) {
                return SafeArea(
                  child: Column(
                    children: [
                      const SizedBox(height: 12),
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppTheme.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          l10n.swapExercise,
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                      ),
                      if (currentMuscles.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            currentMuscles.join(', '),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppTheme.slateInactive,
                            ),
                          ),
                        ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: TextField(
                          controller: searchController,
                          decoration: InputDecoration(
                            hintText: l10n.searchExercisesEllipsis,
                            prefixIcon: const Icon(Icons.search, size: 20),
                            isDense: true,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onChanged: (_) => setSheetState(() {}),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: filtered.isEmpty
                            ? Center(
                                child: Text(
                                  'No matching exercises',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: AppTheme.slateInactive,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                controller: scrollController,
                                itemCount: filtered.length,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                itemBuilder: (_, index) {
                                  final exercise = filtered[index];
                                  return ListTile(
                                    contentPadding: EdgeInsets.zero,
                                    title: Text(
                                      ExerciseTranslations.displayName(context, exercise),
                                      style: const TextStyle(fontWeight: FontWeight.w600),
                                    ),
                                    subtitle: Text(
                                      exercise.primaryMuscles.join(', '),
                                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.slateInactive,
                                      ),
                                    ),
                                    trailing: const Icon(
                                      Icons.swap_horiz_rounded,
                                      color: AppTheme.primary,
                                      size: 20,
                                    ),
                                    onTap: () {
                                      final controller = ref.read(workoutControllerProvider);
                                      controller.swapExercise(pageIndex, exercise.id);
                                      Navigator.pop(sheetContext);
                                    },
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(appStateControllerProvider);
    final session = state.activeSession;
    final controller = ref.read(workoutControllerProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(l10n.activeWorkout)),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: EmptyStateCard(
                title: l10n.noActiveSession,
                body: l10n.startFromDashboard,
              ),
            ),
          ),
        ),
      );
    }

    final routine = state.routineById(session.routineId);
    if (routine == null || routine.exercises.isEmpty) {
      return const SizedBox.shrink();
    }

    final exerciseCount = routine.exercises.length;
    final currentPrescription = routine.exercises[_currentPage.clamp(0, exerciseCount - 1)];
    final currentExercise = state.exerciseById(currentPrescription.exerciseId);
    final currentExerciseSets = session.completedSets
        .where((s) => s.exerciseId == currentPrescription.exerciseId)
        .length;
    final sessionElapsed = DateTime.now().difference(session.startedAt);
    final elapsedMinutes = sessionElapsed.inMinutes;
    final elapsedSeconds = sessionElapsed.inSeconds % 60;
    final timerText =
        '${elapsedMinutes.toString().padLeft(2, '0')}:${elapsedSeconds.toString().padLeft(2, '0')}';

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: Scaffold(
      appBar: AppBar(
        centerTitle: true,
        leading: IconButton(
          tooltip: l10n.backToDashboard,
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentExercise != null
                  ? ExerciseTranslations.displayName(context, currentExercise)
                  : 'Exercise',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                'SET ${currentExerciseSets + 1} OF ${currentPrescription.targetSets}',
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 0.5,
                      fontSize: 10,
                    ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded),
            tooltip: l10n.swapExercise,
            onPressed: () => _showSwapPicker(context, state, routine, _currentPage),
          ),
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '${_currentPage + 1}/$exerciseCount',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: GestureDetector(
          onTap: () => _showFinishConfirmation(context),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFE53E3E),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFE53E3E).withValues(alpha: 0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stop_rounded, color: Colors.white, size: 22),
                const SizedBox(width: 8),
                Text(
                  timerText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(width: 12),
                Container(
                  width: 1,
                  height: 24,
                  color: Colors.white.withValues(alpha: 0.3),
                ),
                const SizedBox(width: 12),
                Text(
                  l10n.finish,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: (notification) {
          if (notification is ScrollStartNotification) {
            _showArrows();
          }
          return false;
        },
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              itemCount: exerciseCount,
              onPageChanged: (index) {
                setState(() => _currentPage = index);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (mounted) controller.goToExercise(index);
                });
              },
              itemBuilder: (context, pageIndex) {
                return _ExercisePage(
                  key: ValueKey(pageIndex),
                  pageIndex: pageIndex,
                  routine: routine,
                  session: session,
                  state: state,
                  controller: controller,
                  weightController: _weightController,
                  repsController: _repsController,
                  setNoteController: _setNoteController,
                  lastExerciseId: _lastExerciseId,
                  onExerciseIdChanged: (id) => _lastExerciseId = id,
                  remainingRest: _remainingRest,
                  onLogSet: _resetRestTimer,
                  onShowComment: () => _showCommentDialog(context),
                  preferredUnit: state.preferredUnit,
                  timedCountdownRemaining: _timedCountdownRemaining,
                  timedExerciseRunning: _timedExerciseRunning,
                  onStartTimed: _startTimedExercise,
                  onPauseTimed: _pauseTimedExercise,
                  onResetTimed: _resetTimedExercise,
                );
              },
            ),
            // Left arrow
            Positioned(
              left: 4,
              top: 0,
              bottom: 0,
              child: FadeTransition(
                opacity: _arrowOpacity,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_left_rounded,
                      size: 22,
                      color: _currentPage > 0
                          ? AppTheme.ink.withValues(alpha: 0.5)
                          : AppTheme.slateInactive.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
            // Right arrow
            Positioned(
              right: 4,
              top: 0,
              bottom: 0,
              child: FadeTransition(
                opacity: _arrowOpacity,
                child: Center(
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.05),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 22,
                      color: _currentPage < exerciseCount - 1
                          ? AppTheme.ink.withValues(alpha: 0.5)
                          : AppTheme.slateInactive.withValues(alpha: 0.25),
                    ),
                  ),
                ),
              ),
            ),
            // Auto-switch countdown overlay
            if (_switchCountdown != null)
              Positioned.fill(
                child: Container(
                  color: Colors.black.withValues(alpha: 0.5),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 24),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 20,
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.swap_horiz_rounded,
                              size: 36, color: AppTheme.primary),
                          const SizedBox(height: 12),
                          Text(
                            l10n.nextExerciseIn,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '$_switchCountdown',
                            style: Theme.of(context)
                                .textTheme
                                .displaySmall
                                ?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  color: AppTheme.primary,
                                ),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton(
                            onPressed: () {
                              setState(() {
                                _switchCountdown = null;
                                _switchTargetPage = null;
                              });
                            },
                            child: Text(l10n.stayHere),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ),
    );
  }
}

class _ExercisePage extends StatelessWidget {
  const _ExercisePage({
    super.key,
    required this.pageIndex,
    required this.routine,
    required this.session,
    required this.state,
    required this.controller,
    required this.weightController,
    required this.repsController,
    required this.setNoteController,
    required this.lastExerciseId,
    required this.onExerciseIdChanged,
    required this.remainingRest,
    required this.onLogSet,
    required this.onShowComment,
    required this.preferredUnit,
    required this.timedCountdownRemaining,
    required this.timedExerciseRunning,
    required this.onStartTimed,
    required this.onPauseTimed,
    required this.onResetTimed,
  });

  final int pageIndex;
  final Routine routine;
  final WorkoutSession session;
  final AppState state;
  final WorkoutController controller;
  final TextEditingController weightController;
  final TextEditingController repsController;
  final TextEditingController setNoteController;
  final String? lastExerciseId;
  final ValueChanged<String> onExerciseIdChanged;
  final int remainingRest;
  final ValueChanged<int> onLogSet;
  final VoidCallback onShowComment;
  final String preferredUnit;
  final int timedCountdownRemaining;
  final bool timedExerciseRunning;
  final ValueChanged<int> onStartTimed;
  final VoidCallback onPauseTimed;
  final ValueChanged<int> onResetTimed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final prescription = routine.exercises[pageIndex];
    final exercise = state.exerciseById(prescription.exerciseId);
    final currentSets = session.completedSets
        .where((set) => set.exerciseId == prescription.exerciseId)
        .toList();
    final previousPerformance = state.completedSessions
        .where((item) => item.id != session.id)
        .expand((item) => item.completedSets)
        .where((set) => set.exerciseId == prescription.exerciseId)
        .toList()
      ..sort((a, b) => b.completedAt.compareTo(a.completedAt));

    // Pre-fill weight/reps when switching to this exercise (deferred to avoid
    // modifying controllers during build)
    if (lastExerciseId != prescription.exerciseId) {
      onExerciseIdChanged(prescription.exerciseId);
      if (exercise?.exerciseType != 'timed') {
        final lastSet = currentSets.isNotEmpty
            ? currentSets.last
            : previousPerformance.isNotEmpty
                ? previousPerformance.first
                : null;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          weightController.text = lastSet != null
              ? AppFormatters.decimal(
                  AppFormatters.convertWeight(lastSet.weightKg, preferredUnit))
              : prescription.recommendedWeightKg > 0
              ? AppFormatters.decimal(AppFormatters.convertWeight(
                  prescription.recommendedWeightKg, preferredUnit))
              : '';
          repsController.text =
              lastSet?.reps.toString() ?? '${prescription.targetReps}';
          setNoteController.clear();
        });
      } else {
        // Reset timed exercise countdown for the new exercise
        WidgetsBinding.instance.addPostFrameCallback((_) {
          onResetTimed(prescription.targetDurationSeconds);
        });
      }
    }

    final highestPrevWeight = previousPerformance.isEmpty
        ? 0.0
        : previousPerformance
            .map((s) => s.weightKg)
            .reduce((a, b) => a > b ? a : b);

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
      children: [
        // Muscle heatmap — fatigue colors with active muscles highlighted
        if (exercise != null && exercise.primaryMuscles.isNotEmpty) ...[
          _ActiveMuscleHeatmap(exercise: exercise, state: state),
          const SizedBox(height: 8),
        ],

        if (exercise?.exerciseType == 'timed') ...[
          // Timed exercise: countdown timer + start/pause/reset
          const SizedBox(height: 8),
          Center(
            child: Text(
              l10n.countdown,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '${(timedCountdownRemaining ~/ 60).toString().padLeft(2, '0')}:${(timedCountdownRemaining % 60).toString().padLeft(2, '0')}',
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: timedExerciseRunning ? AppTheme.primary : AppTheme.ink,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!timedExerciseRunning) ...[
                FilledButton.icon(
                  onPressed: () => onStartTimed(
                    timedCountdownRemaining > 0
                        ? timedCountdownRemaining
                        : prescription.targetDurationSeconds,
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(timedCountdownRemaining < prescription.targetDurationSeconds && timedCountdownRemaining > 0 ? l10n.resume : l10n.start),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
                ),
                if (timedCountdownRemaining < prescription.targetDurationSeconds) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => onResetTimed(prescription.targetDurationSeconds),
                    icon: const Icon(Icons.refresh_rounded),
                    label: Text(l10n.reset),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 48),
                    ),
                  ),
                ],
              ] else ...[
                FilledButton.icon(
                  onPressed: onPauseTimed,
                  icon: const Icon(Icons.pause_rounded),
                  label: Text(l10n.pause),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                    backgroundColor: Colors.orange.shade600,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 20),
          // Manual log: type duration + LOG button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      l10n.manualMin,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slateInactive,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: weightController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        hintText: '0',
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                    onPressed: () {
                      final minutes = int.tryParse(weightController.text);
                      if (minutes == null || minutes <= 0) return;
                      controller.logTimedSet(
                        durationSeconds: minutes * 60,
                        note: setNoteController.text.trim(),
                      );
                      setNoteController.clear();
                      weightController.clear();
                      onLogSet(prescription.restSeconds);
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(l10n.log),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
        ] else ...[
          // Strength exercise: rest timer + weight/reps/log
          // Rest timer
          Center(
            child:
                DigitalTimer(remaining: Duration(seconds: remainingRest)),
          ),
          const SizedBox(height: 24),

          // 3-column input grid: weight, reps, log button
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      l10n.weightUnit(preferredUnit.toUpperCase()),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slateInactive,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: weightController,
                      textAlign: TextAlign.center,
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      l10n.reps,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slateInactive,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                    ),
                    const SizedBox(height: 6),
                    TextField(
                      controller: repsController,
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                      decoration: const InputDecoration(
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 56,
                  child: FilledButton.icon(
                  onPressed: () {
                    final rawWeight = double.tryParse(
                      weightController.text.replaceAll(',', '.'),
                    );
                    final weight = rawWeight == null ? null : AppFormatters.convertToKg(rawWeight, preferredUnit);
                    final reps = int.tryParse(repsController.text);
                    if (weight == null || reps == null || reps <= 0) return;

                    controller.logSet(
                      weightKg: weight,
                      reps: reps,
                      note: setNoteController.text.trim(),
                    );
                    setNoteController.clear();
                    onLogSet(prescription.restSeconds);
                  },
                  icon: const Icon(Icons.check_circle_outline_rounded),
                  label: const Text('LOG'),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ], // end else (strength)

        // Add comment button
        GestureDetector(
          onTap: onShowComment,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.chat_bubble_outline,
                  size: 16,
                  color: setNoteController.text.trim().isNotEmpty
                      ? AppTheme.primary
                      : AppTheme.slateInactive,
                ),
                const SizedBox(width: 8),
                Text(
                  setNoteController.text.trim().isNotEmpty
                      ? l10n.commentAdded
                      : l10n.addComment,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: setNoteController.text.trim().isNotEmpty
                            ? AppTheme.primary
                            : AppTheme.slateInactive,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Current session sets
        PageSection(
          title: l10n.currentSessionSets,
          child: currentSets.isEmpty
              ? EmptyStateCard(
                  title: l10n.nothingLoggedYet,
                  body: l10n.setsWillAppear,
                )
              : Column(
                  children: currentSets.map((set) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        onTap: () => _showEditSetDialog(
                          context,
                          controller,
                          set,
                          exercise?.exerciseType == 'timed',
                          preferredUnit,
                        ),
                        onLongPress: () {
                          showModalBottomSheet(
                            context: context,
                            shape: const RoundedRectangleBorder(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
                            ),
                            builder: (sheetContext) => SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 40, height: 4,
                                    decoration: BoxDecoration(
                                      color: AppTheme.border,
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  ListTile(
                                    leading: const Icon(Icons.edit_outlined),
                                    title: Text(l10n.editSet),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      _showEditSetDialog(
                                        context, controller, set,
                                        exercise?.exerciseType == 'timed',
                                        preferredUnit,
                                      );
                                    },
                                  ),
                                  ListTile(
                                    leading: Icon(Icons.delete_outline, color: Colors.red.shade400),
                                    title: Text(l10n.deleteSet, style: TextStyle(color: Colors.red.shade400)),
                                    onTap: () {
                                      Navigator.pop(sheetContext);
                                      controller.deleteSet(set.exerciseId, set.setNumber);
                                    },
                                  ),
                                  const SizedBox(height: 8),
                                ],
                              ),
                            ),
                          );
                        },
                        title: Text(
                          set.durationSeconds > 0
                              ? 'Set ${set.setNumber}: ${(set.durationSeconds / 60).round()} min'
                              : 'Set ${set.setNumber}: ${AppFormatters.weight(set.weightKg, preferredUnit)} x ${set.reps}',
                          style:
                              const TextStyle(fontWeight: FontWeight.w800),
                        ),
                        subtitle: Text(AppFormatters.time(set.completedAt)),
                        trailing: Icon(Icons.more_vert, size: 18, color: AppTheme.slateInactive),
                      ),
                    );
                  }).toList(),
                ),
        ),
        const SizedBox(height: 24),

        // Previous performance with PB badges
        PageSection(
          title: l10n.previousPerformance,
          child: previousPerformance.isEmpty
              ? EmptyStateCard(
                  title: l10n.noHistoryYet,
                  body: l10n.historyWillAppear,
                )
              : Column(
                  children: previousPerformance.take(4).map((set) {
                    final isPb = set.weightKg == highestPrevWeight &&
                        highestPrevWeight > 0;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(
                              set.durationSeconds > 0
                                  ? '${set.durationSeconds}s'
                                  : '${AppFormatters.weight(set.weightKg, preferredUnit)} x ${set.reps}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800),
                            ),
                            if (isPb) ...[
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.primary
                                      .withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(999),
                                ),
                                child: Text(
                                  'PB',
                                  style: Theme.of(context)
                                      .textTheme
                                      .labelSmall
                                      ?.copyWith(
                                        color: AppTheme.primary,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          AppFormatters.weekdayMonthDay(set.completedAt),
                        ),
                      ),
                    );
                  }).toList(),
                ),
        ),
      ],
      ),
    );
  }

  void _showEditSetDialog(
    BuildContext context,
    WorkoutController controller,
    CompletedSet set,
    bool isTimed,
    String preferredUnit,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final weightCtrl = TextEditingController(
      text: isTimed
          ? '${(set.durationSeconds / 60).round()}'
          : AppFormatters.decimal(
              AppFormatters.convertWeight(set.weightKg, preferredUnit)),
    );
    final repsCtrl = TextEditingController(text: '${set.reps}');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: Text('${l10n.editSet} ${set.setNumber}'),
          content: isTimed
              ? TextField(
                  controller: weightCtrl,
                  autofocus: true,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Duration (min)'),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: weightCtrl,
                      autofocus: true,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Weight ($preferredUnit)',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: repsCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Reps'),
                    ),
                  ],
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(l10n.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (isTimed) {
                  final minutes = int.tryParse(weightCtrl.text);
                  if (minutes == null || minutes <= 0) return;
                  controller.updateSet(
                    set.exerciseId,
                    set.setNumber,
                    durationSeconds: minutes * 60,
                  );
                } else {
                  final rawWeight = double.tryParse(
                    weightCtrl.text.replaceAll(',', '.'),
                  );
                  final weight = rawWeight == null
                      ? null
                      : AppFormatters.convertToKg(rawWeight, preferredUnit);
                  final reps = int.tryParse(repsCtrl.text);
                  if (weight == null || reps == null || reps <= 0) return;
                  controller.updateSet(
                    set.exerciseId,
                    set.setNumber,
                    weightKg: weight,
                    reps: reps,
                  );
                }
                Navigator.pop(dialogContext);
              },
              child: Text(l10n.save),
            ),
          ],
        );
      },
    );
  }
}

class _ActiveMuscleHeatmap extends StatefulWidget {
  const _ActiveMuscleHeatmap({
    required this.exercise,
    required this.state,
  });

  final Exercise exercise;
  final AppState state;

  @override
  State<_ActiveMuscleHeatmap> createState() => _ActiveMuscleHeatmapState();
}

class _ActiveMuscleHeatmapState extends State<_ActiveMuscleHeatmap>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final exercise = widget.exercise;
    final state = widget.state;
    final fatigue = MuscleHeatmapService().computeFatigue(state);

    // Build the set of active Muscle enums for this exercise
    final activeMuscles = <Muscle>{};
    for (final name in exercise.primaryMuscles) {
      final mapped = MuscleHeatmapService.muscleMapping[name] ?? [];
      activeMuscles.addAll(mapped);
    }
    final secondaryMuscles = <Muscle>{};
    for (final name in exercise.secondaryMuscles) {
      final mapped = MuscleHeatmapService.muscleMapping[name] ?? [];
      secondaryMuscles.addAll(mapped);
    }

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, _) {
        final pulse = _pulseAnimation.value;

        // Override active muscles with pulsing primary blue
        final highlightedData = Map<Muscle, MuscleData>.from(fatigue);
        for (final muscle in activeMuscles) {
          highlightedData[muscle] = MuscleData(
            intensity: 1.0,
            color: AppTheme.primary.withValues(alpha: pulse),
          );
        }
        for (final muscle in secondaryMuscles) {
          if (!activeMuscles.contains(muscle)) {
            highlightedData[muscle] = MuscleData(
              intensity: 0.7,
              color: AppTheme.primary.withValues(alpha: pulse * 0.5),
            );
          }
        }

        const colors = [
          Color(0xFFE2E8F0),
          Color(0xFF93C5FD),
          Color(0xFF4ADE80),
          Color(0xFFFBBF24),
          Color(0xFFF97316),
          Color(0xFFEF4444),
        ];

        Widget buildBody(BodySide side) {
          return AspectRatio(
            aspectRatio: 0.42,
            child: BodyHeatmap(
              side: side,
              gender: state.bodyGender == 'female'
                  ? BodyGender.female
                  : BodyGender.male,
              data: highlightedData,
              colors: colors,
              bodyColor: const Color(0xFFE2E8F0),
              showBorder: false,
            ),
          );
        }

        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.40,
          child: Stack(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildBody(BodySide.front),
                  const SizedBox(width: 12),
                  buildBody(BodySide.back),
                ],
              ),
              Positioned(
                top: 0,
                right: 0,
                child: GestureDetector(
                  onTap: () => _showHeatmapLegend(context),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.8),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.info_outline_rounded,
                      size: 16,
                      color: AppTheme.slateInactive,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showHeatmapLegend(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                l10n.muscleHeatmap,
                style: Theme.of(sheetContext)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              _legendRow(
                color: AppTheme.primary,
                label: l10n.activeMuscles,
                description: l10n.activeMusclesDesc,
              ),
              const SizedBox(height: 12),
              _legendRow(
                color: AppTheme.primary.withValues(alpha: 0.4),
                label: l10n.secondaryMusclesLabel,
                description: l10n.secondaryMusclesDesc,
              ),
              const SizedBox(height: 16),
              Container(
                height: 12,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  gradient: LinearGradient(
                    colors: [
                      Colors.grey.shade300,
                      Colors.blue.shade300,
                      Colors.green.shade400,
                      Colors.yellow.shade600,
                      Colors.orange.shade600,
                      Colors.red.shade500,
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(l10n.recovered,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.slateInactive)),
                  Text(l10n.fatigued,
                      style: TextStyle(
                          fontSize: 11, color: AppTheme.slateInactive)),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                l10n.fatigueDecayNote,
                style: Theme.of(sheetContext).textTheme.bodySmall?.copyWith(
                      color: AppTheme.slateInactive,
                    ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _legendRow({
    required Color color,
    required String label,
    required String description,
  }) {
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 13)),
              Text(description,
                  style: TextStyle(
                      fontSize: 11, color: AppTheme.slateInactive)),
            ],
          ),
        ),
      ],
    );
  }
}
