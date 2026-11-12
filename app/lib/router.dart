import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'screens/account_screen.dart';
import 'screens/cardio_screen.dart';
import 'screens/devices_screen.dart';
import 'screens/duel_battle_screen.dart';
import 'screens/duels_screen.dart';
import 'screens/exercise_library_screen.dart';
import 'screens/friends_screen.dart';
import 'screens/health_screen.dart';
import 'screens/heart_rate_screen.dart';
import 'screens/joint_screen.dart';
import 'screens/premium_screen.dart';
import 'screens/home_screen.dart';
import 'screens/notifications_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/player_screen.dart';
import 'screens/privacy_screen.dart';
import 'screens/rating_screen.dart';
import 'screens/schedule_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/tip_screen.dart';
import 'screens/wardrobe_screen.dart';
import 'screens/workout_result_screen.dart';
import 'screens/workout_screen.dart';
import 'state/providers.dart';
import 'widgets/motion.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final hasHero = ref.read(heroProvider) != null;
      final onOnboarding = state.matchedLocation == '/onboarding';
      // Политику можно открыть до создания героя — из онбординга.
      if (state.matchedLocation == '/privacy') return null;
      if (!hasHero && !onOnboarding) return '/onboarding';
      if (hasHero && onOnboarding) return '/';
      return null;
    },
    routes: [
      GoRoute(path: '/onboarding', builder: (_, _) => const OnboardingScreen()),
      GoRoute(path: '/privacy', builder: (_, _) => const PrivacyScreen()),
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
                  GoRoute(
                    path: 'shop',
                    builder: (_, _) => const WardrobeScreen(shop: true),
                    routes: [
                      GoRoute(
                        path: 'premium',
                        builder: (_, _) => const PremiumScreen(),
                      ),
                    ],
                  ),
                  GoRoute(path: 'tip', builder: (_, _) => const TipScreen()),
                  GoRoute(
                    path: 'notifications',
                    builder: (_, _) => const NotificationsScreen(),
                    routes: [
                      GoRoute(
                        path: 'settings',
                        builder: (_, _) => const NotificationSettingsScreen(),
                      ),
                    ],
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
                  GoRoute(
                    path: 'joint',
                    builder: (_, _) => const JointScreen(),
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
                builder: (_, _) => const PlayerScreen(),
                routes: [
                  GoRoute(
                    path: 'settings',
                    builder: (_, _) => const SettingsScreen(),
                    routes: [
                      GoRoute(
                        path: 'schedule',
                        builder: (_, _) => const ScheduleScreen(),
                      ),
                    ],
                  ),
                  GoRoute(
                    path: 'heart-rate',
                    builder: (_, _) => const HeartRateScreen(),
                  ),
                  GoRoute(
                    path: 'account',
                    builder: (_, _) => const AccountScreen(),
                  ),
                  GoRoute(
                    path: 'devices',
                    builder: (_, _) => const DevicesScreen(),
                  ),
                  GoRoute(
                    path: 'friends',
                    builder: (_, _) => const FriendsScreen(),
                  ),
                  GoRoute(
                    path: 'health',
                    builder: (_, _) => const HealthScreen(),
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

class _Shell extends StatefulWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  State<_Shell> createState() => _ShellState();
}

class _ShellState extends State<_Shell> with SingleTickerProviderStateMixin {
  int _visit = 0;

  // Переключение вкладок «fade through» (Material): новая вкладка проявляется
  // и чуть подрастает. Вкладки не пересоздаются — их состояние сохраняется.
  late final AnimationController _switch = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 260),
    value: 1,
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _switch,
    curve: Curves.easeOutCubic,
  );
  late final Animation<double> _scale = Tween(
    begin: 0.96,
    end: 1.0,
  ).animate(_fade);

  @override
  void dispose() {
    _switch.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Shell old) {
    super.didUpdateWidget(old);
    // Новая вкладка: плавный переход и повтор появления блоков на ней.
    if (widget.shell.currentIndex != old.shell.currentIndex) {
      _switch.forward(from: 0);
      _visit++;
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    // Новый заход на вкладку — блоки на ней появятся заново (FadeSlideIn).
    return Scaffold(
      body: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(
          scale: _scale,
          child: TabVisit(visit: _visit, child: shell),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
        destinations: const [
          NavigationDestination(
            icon: Icon(LucideIcons.personStanding),
            label: 'Герой',
          ),
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
            icon: Icon(LucideIcons.circleUser),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}
