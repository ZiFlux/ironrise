import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'screens/account_screen.dart';
import 'screens/cardio_screen.dart';
import 'screens/duel_battle_screen.dart';
import 'screens/duels_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/heart_rate_screen.dart';
import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/wardrobe_screen.dart';
import 'screens/workout_result_screen.dart';
import 'screens/workout_screen.dart';
import 'state/providers.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final hasHero = ref.read(heroProvider) != null;
      final onOnboarding = state.matchedLocation == '/onboarding';
      if (!hasHero && !onOnboarding) return '/onboarding';
      if (hasHero && onOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const HomeScreen(),
                routes: [
                  GoRoute(
                    path: 'wardrobe',
                    builder: (_, _) => const WardrobeScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/workout',
                builder: (_, _) => const WorkoutScreen(),
                routes: [
                  GoRoute(
                    path: 'result',
                    builder: (_, _) => const WorkoutResultScreen(),
                  ),
                  GoRoute(
                    path: 'exercises',
                    builder: (_, _) => const ExerciseLibraryScreen(),
                  ),
                  GoRoute(
                    path: 'cardio',
                    builder: (_, _) => const CardioScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/duels',
                builder: (_, _) => const DuelsScreen(),
                routes: [
                  GoRoute(
                    path: 'battle',
                    builder: (_, _) => const DuelBattleScreen(),
                  ),
                  GoRoute(
                    path: 'friends',
                    builder: (_, _) => const FriendsScreen(),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/rating', builder: (_, _) => const RatingScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) => const ProfileScreen(),
                routes: [
                  GoRoute(
                    path: 'heart-rate',
                    builder: (_, _) => const HeartRateScreen(),
                  ),
                  GoRoute(
                    path: 'account',
                    builder: (_, _) => const AccountScreen(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

class _Shell extends StatelessWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(LucideIcons.user), label: 'Герой'),
          NavigationDestination(
            icon: Icon(LucideIcons.dumbbell),
            label: 'Тренировка',
          ),
          NavigationDestination(icon: Icon(LucideIcons.swords), label: 'Дуэли'),
          NavigationDestination(
            icon: Icon(LucideIcons.trophy),
            label: 'Рейтинг',
          ),
          NavigationDestination(
            icon: Icon(LucideIcons.slidersHorizontal),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
