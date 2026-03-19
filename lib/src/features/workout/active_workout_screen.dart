import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
import 'package:strength_training_tracker/src/data/models/exercise.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_card.dart';
import 'package:strength_training_tracker/src/features/dashboard/muscle_heatmap_service.dart';
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
    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Set Comment'),
          content: TextField(
            controller: _setNoteController,
            autofocus: true,
            maxLines: 3,
            decoration: const InputDecoration(
              hintText: 'Optional cue or RPE note for this set',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _showFinishConfirmation(BuildContext context) {
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
                  'Finish Workout?',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your session will be saved and you can review your summary.',
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
                  label: const Text('Finish & Save'),
                ),
                const SizedBox(height: 12),
                OutlinedButton(
                  onPressed: () => Navigator.of(sheetContext).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(52),
                  ),
                  child: const Text('Keep Training'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(sheetContext).pop();
                    controller.discardDraft();
                    context.go('/');
                  },
                  child: Text(
                    'Discard Session',
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appStateControllerProvider);
    final session = state.activeSession;
    final controller = ref.read(workoutControllerProvider);

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Active Workout')),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: const Padding(
              padding: EdgeInsets.all(20),
              child: EmptyStateCard(
                title: 'No active session',
                body:
                    'Start a routine from the dashboard or library to begin logging sets.',
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
          tooltip: 'Back to dashboard',
          onPressed: () => context.go('/'),
          icon: const Icon(Icons.close_rounded),
        ),
        title: Text(
          routine.name,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w800),
        ),
        actions: [
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
                const Text(
                  'FINISH',
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
                            'Next exercise in',
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
                            child: const Text('Stay Here'),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        // Exercise name + set badge
        Center(
          child: Text(
            exercise?.name ?? 'Exercise',
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'SET ${currentSets.length + 1} OF ${prescription.targetSets}',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.0,
                  ),
            ),
          ),
        ),

        // Exercise indicator dots
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(routine.exercises.length, (i) {
            return Container(
              width: i == pageIndex ? 8 : 6,
              height: i == pageIndex ? 8 : 6,
              margin: const EdgeInsets.symmetric(horizontal: 3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i == pageIndex
                    ? AppTheme.primary
                    : AppTheme.slateInactive.withValues(alpha: 0.3),
              ),
            );
          }),
        ),
        const SizedBox(height: 12),

        // Mini muscle heatmap for active exercise
        if (exercise != null && exercise.primaryMuscles.isNotEmpty)
          _MiniMuscleHeatmap(
            exercise: exercise,
            state: state,
          ),

        const SizedBox(height: 12),

        if (exercise?.exerciseType == 'timed') ...[
          // Timed exercise: countdown timer + start/pause/reset
          const SizedBox(height: 8),
          Center(
            child: Text(
              'COUNTDOWN',
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
                  label: Text(timedCountdownRemaining < prescription.targetDurationSeconds && timedCountdownRemaining > 0 ? 'Resume' : 'Start'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(120, 48),
                  ),
                ),
                if (timedCountdownRemaining < prescription.targetDurationSeconds) ...[
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => onResetTimed(prescription.targetDurationSeconds),
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Reset'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(100, 48),
                    ),
                  ),
                ],
              ] else ...[
                FilledButton.icon(
                  onPressed: onPauseTimed,
                  icon: const Icon(Icons.pause_rounded),
                  label: const Text('Pause'),
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
                      'MANUAL (MIN)',
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
                    label: const Text('LOG'),
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
                      'WEIGHT (${preferredUnit.toUpperCase()})',
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
                      'REPS',
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
                      ? 'COMMENT ADDED'
                      : 'ADD COMMENT',
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
          title: 'Current Session Sets',
          child: currentSets.isEmpty
              ? const EmptyStateCard(
                  title: 'Nothing logged yet',
                  body:
                      'Your sets for the current exercise will appear here.',
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
                                    title: const Text('Edit Set'),
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
                                    title: Text('Delete Set', style: TextStyle(color: Colors.red.shade400)),
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
          title: 'Previous Performance',
          child: previousPerformance.isEmpty
              ? const EmptyStateCard(
                  title: 'No history for this movement yet',
                  body:
                      'Once you repeat the exercise, prior sets will show here.',
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
    );
  }

  void _showEditSetDialog(
    BuildContext context,
    WorkoutController controller,
    CompletedSet set,
    bool isTimed,
    String preferredUnit,
  ) {
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
          title: Text('Edit Set ${set.setNumber}'),
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
              child: const Text('Cancel'),
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
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }
}

class _MiniMuscleHeatmap extends StatelessWidget {
  const _MiniMuscleHeatmap({
    required this.exercise,
    required this.state,
  });

  final Exercise exercise;
  final AppState state;

  @override
  Widget build(BuildContext context) {
    final fatigue = MuscleHeatmapService().computeFatigue(state);

    // Determine which muscles this exercise targets (mapped to heatmap names)
    final targetMuscles = <String>{};
    for (final muscle in exercise.primaryMuscles) {
      final mapped = MuscleHeatmapService.muscleMapping[muscle] ?? [muscle];
      targetMuscles.addAll(mapped);
    }

    // Determine which sides to show
    final hasFront = targetMuscles.any(
        (m) => MuscleHeatmapService.frontMuscles.contains(m));
    final hasBack = targetMuscles.any(
        (m) => MuscleHeatmapService.backMuscles.contains(m));

    // If exercise muscles don't map to any known heatmap muscle, skip
    if (!hasFront && !hasBack) return const SizedBox.shrink();

    final showBoth = hasFront && hasBack;

    return SizedBox(
      height: 160,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (hasFront)
            AspectRatio(
              aspectRatio: 0.42,
              child: CustomPaint(
                painter: BodyHeatmapPainter(fatigue: fatigue, isFront: true),
                size: Size.infinite,
              ),
            ),
          if (showBoth) const SizedBox(width: 16),
          if (hasBack)
            AspectRatio(
              aspectRatio: 0.42,
              child: CustomPaint(
                painter: BodyHeatmapPainter(fatigue: fatigue, isFront: false),
                size: Size.infinite,
              ),
            ),
        ],
      ),
    );
  }
}
