import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:strength_training_tracker/src/features/dashboard/dashboard_screen.dart';
import 'package:strength_training_tracker/src/features/exercises/exercise_editor_screen.dart';
import 'package:strength_training_tracker/src/features/exercises/exercises_screen.dart';
import 'package:strength_training_tracker/src/features/progress/progress_screen.dart';
import 'package:strength_training_tracker/src/features/routines/routine_editor_screen.dart';
import 'package:strength_training_tracker/src/features/routines/routines_screen.dart';
import 'package:strength_training_tracker/src/features/workout/active_workout_screen.dart';
import 'package:strength_training_tracker/src/features/workout/workout_summary_screen.dart';
import 'package:strength_training_tracker/src/shared/widgets/app_shell_scaffold.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    routes: [
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
            builder: (context, state) => const DashboardScreen(),
          ),
          GoRoute(
            path: '/routines',
            builder: (context, state) => const RoutinesScreen(),
          ),
          GoRoute(
            path: '/exercises',
            builder: (context, state) => const ExercisesScreen(),
          ),
          GoRoute(
            path: '/progress',
            builder: (context, state) => const ProgressScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/routine/new',
        builder: (context, state) => const RoutineEditorScreen(),
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
