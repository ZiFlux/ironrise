import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens/home_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/placeholder_screen.dart';
import 'screens/profile_screen.dart';
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
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/workout',
              builder: (_, _) => const PlaceholderScreen(
                title: 'Тренировка',
                icon: Icons.fitness_center,
                text: 'Здесь будет запись подходов, таймер отдыха и пульс с часов.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/duels',
              builder: (_, _) => const PlaceholderScreen(
                title: 'Дуэли',
                icon: Icons.sports_martial_arts,
                text: 'Вызывай друзей на дуэль. Исход решает сила героя.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: '/rating',
              builder: (_, _) => const PlaceholderScreen(
                title: 'Рейтинг',
                icon: Icons.emoji_events_outlined,
                text: 'Таблица среди друзей появится вместе с дуэлями.',
              ),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ]),
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
        onDestinationSelected: (i) => shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Герой'),
          NavigationDestination(icon: Icon(Icons.fitness_center), label: 'Тренировка'),
          NavigationDestination(icon: Icon(Icons.sports_martial_arts), label: 'Дуэли'),
          NavigationDestination(icon: Icon(Icons.emoji_events_outlined), selectedIcon: Icon(Icons.emoji_events), label: 'Рейтинг'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'Профиль'),
        ],
      ),
    );
  }
}
