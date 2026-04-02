import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/core/app_state_controller.dart';
import 'package:strength_training_tracker/src/features/dashboard/dashboard_screen.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_editor_screen.dart';
import 'package:strength_training_tracker/src/features/exercises/exercises_screen.dart';
import 'package:strength_training_tracker/src/features/onboarding/onboarding_screen.dart';
import 'package:strength_training_tracker/src/features/progress/progress_screen.dart';
import 'package:strength_training_tracker/src/features/training_engine/training_engine_debug_screen.dart';
import 'package:strength_training_tracker/src/features/routines/routine_editor_screen.dart';
import 'package:strength_training_tracker/src/features/routines/routine_group_editor_screen.dart';
import 'package:strength_training_tracker/src/features/routines/routine_groups_screen.dart';
import 'package:strength_training_tracker/src/features/routines/routines_screen.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';
import 'package:strength_training_tracker/src/features/workout/workout_summary_screen.dart';
import 'package:strength_training_tracker/src/shared/widgets/app_shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    redirect: (context, state) {
      final appState = ref.read(appStateControllerProvider);
      final isOnboarding = state.uri.toString() == '/onboarding';
      final needsOnboarding = appState.userName.isEmpty;

      if (needsOnboarding && !isOnboarding) return '/onboarding';
      if (!needsOnboarding && isOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) {
          return AppShellScaffold(
            currentLocation: state.uri.toString(),
            child: child,
          );
        },
        routes: [
          GoRoute(
            path: '/',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: DashboardScreen()),
          ),
          GoRoute(
            path: '/routines',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: RoutinesScreen()),
          ),
          GoRoute(
            path: '/exercises',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ExercisesScreen()),
          ),
          GoRoute(
            path: '/progress',
            pageBuilder: (context, state) =>
                const NoTransitionPage(child: ProgressScreen()),
          ),
          GoRoute(
            path: '/debug/training-engine',
            builder: (context, state) => const TrainingEngineDebugScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/routine/new',
        builder: (context, state) => const RoutineEditorScreen(),
      ),
      GoRoute(
        path: '/routine-groups',
        builder: (context, state) => const RoutineGroupsScreen(),
      ),
      GoRoute(
        path: '/routine-groups/new',
        builder: (context, state) => const RoutineGroupEditorScreen(),
      ),
      GoRoute(
        path: '/routine-groups/:groupId/edit',
        builder: (context, state) =>
            RoutineGroupEditorScreen(groupId: state.pathParameters['groupId']),
      ),
      GoRoute(
        path: '/routine/:routineId/edit',
        builder: (context, state) =>
            RoutineEditorScreen(routineId: state.pathParameters['routineId']),
      ),
      GoRoute(
        path: '/exercise/new',
        builder: (context, state) => const ExerciseEditorScreen(),
      ),
      GoRoute(
        path: '/exercise/:exerciseId/edit',
        builder: (context, state) => ExerciseEditorScreen(
          exerciseId: state.pathParameters['exerciseId'],
        ),
      ),
      GoRoute(
        path: '/workout/active',
        builder: (context, state) => const ActiveWorkoutScreen(),
      ),
      GoRoute(
        path: '/workout/:sessionId/summary',
        builder: (context, state) =>
            WorkoutSummaryScreen(sessionId: state.pathParameters['sessionId']!),
      ),
    ],
  );
});
