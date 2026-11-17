import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'screens/fight_screen.dart';
import 'screens/account_screen.dart';
import 'screens/cardio_screen.dart';
import 'screens/entry_test_screen.dart';
import 'screens/recovery_screen.dart';
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
import 'screens/start_look_screen.dart';
import 'widgets/consent_prompt.dart';
import 'screens/wardrobe_screen.dart';
import 'screens/workout_result_screen.dart';
import 'screens/workout_screen.dart';
import 'screens/training_stats_screen.dart';
import 'screens/aura_screen.dart';
import 'screens/feed_screen.dart';
import 'screens/season_screen.dart';
import 'screens/friend_profile_screen.dart';
import 'widgets/week_recap.dart';
import 'game/aura.dart';
import 'widgets/guide.dart';
import 'widgets/screen_hint.dart';
import 'state/providers.dart';
import 'theme.dart';
import 'state/account_state.dart';
import 'state/season_state.dart';
import 'state/server_game.dart';
import 'net/app_log.dart';
import 'widgets/status_toast.dart';
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
      GoRoute(path: '/entry-test', builder: (_, _) => const EntryTestScreen()),
      GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
      GoRoute(
        path: '/season',
        builder: (_, _) =>
            const ScreenHint(id: 'season', child: SeasonScreen()),
      ),
      GoRoute(
        path: '/friend/:id',
        builder: (_, state) =>
            FriendProfileScreen(userId: state.pathParameters['id']!),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => _Shell(shell: shell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => const ConsentPrompt(
                  child: TabGuide(
                    tab: 'home',
                    child: WeekRecapGate(child: HomeScreen()),
                  ),
                ),
                routes: [
                  GoRoute(
                    path: 'wardrobe',
                    builder: (_, _) => const WardrobeScreen(),
                  ),
                  GoRoute(
                    path: 'shop',
                    builder: (_, _) => const ScreenHint(
                      id: 'shop',
                      child: WardrobeScreen(shop: true),
                    ),
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
                builder: (_, _) =>
                    const TabGuide(tab: 'workout', child: WorkoutScreen()),
                routes: [
                  GoRoute(
                    path: 'result',
                    builder: (_, _) => const ScreenHint(
                      id: 'result',
                      child: WorkoutResultScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'exercises',
                    builder: (_, _) => const ExerciseLibraryScreen(),
                  ),
                  GoRoute(
                    path: 'stats',
                    builder: (_, _) => const TrainingStatsScreen(),
                  ),
                  GoRoute(
                    path: 'cardio',
                    builder: (_, _) => const CardioScreen(),
                  ),
                  GoRoute(
                    path: 'recovery',
                    builder: (_, _) => const RecoveryScreen(),
                  ),
                  GoRoute(
                    path: 'joint',
                    builder: (_, _) =>
                        const ScreenHint(id: 'joint', child: JointScreen()),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/duels',
                builder: (_, _) =>
                    const TabGuide(tab: 'duels', child: DuelsScreen()),
                routes: [
                  GoRoute(
                    path: 'battle',
                    builder: (_, _) => const ScreenHint(
                      id: 'battle',
                      child: DuelBattleScreen(),
                    ),
                  ),
                  GoRoute(
                    path: 'fight',
                    builder: (_, _) => const FightScreen(),
                  ),
                  GoRoute(
                    path: 'friends',
                    builder: (_, _) =>
                        const ScreenHint(id: 'friends', child: FriendsScreen()),
                  ),
                  GoRoute(
                    path: 'auras',
                    builder: (_, _) =>
                        const ScreenHint(id: 'auras', child: AuraScreen()),
                    routes: [
                      GoRoute(
                        path: ':kind',
                        builder: (_, state) => AuraTrainingScreen(
                          kind: AuraKind.values.byName(
                            state.pathParameters['kind']!,
                          ),
                        ),
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
                path: '/rating',
                builder: (_, _) =>
                    const TabGuide(tab: 'rating', child: RatingScreen()),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/profile',
                builder: (_, _) =>
                    const TabGuide(tab: 'profile', child: PlayerScreen()),
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
                    builder: (_, state) => AccountScreen(
                      login: state.uri.queryParameters['login'] == '1',
                    ),
                  ),
                  GoRoute(
                    path: 'devices',
                    builder: (_, _) => const DevicesScreen(),
                  ),
                  GoRoute(
                    path: 'friends',
                    builder: (_, _) =>
                        const ScreenHint(id: 'friends', child: FriendsScreen()),
                  ),
                  GoRoute(
                    path: 'health',
                    builder: (_, _) => const HealthScreen(),
                  ),
                  GoRoute(
                    path: 'start-look',
                    builder: (_, _) => const StartLookScreen(),
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

/// Вкладок в нижней панели: Герой, Тренировка, Дуэли, Рейтинг, Профиль.
const _tabCount = 5;

/// Иконки и подписи вкладок — для подсказки, куда ведёт натяжение.
const _tabs = [
  (LucideIcons.personStanding, 'Герой'),
  (LucideIcons.dumbbell, 'Тренировка'),
  (LucideIcons.swords, 'Дуэли'),
  (LucideIcons.trophy, 'Рейтинг'),
  (LucideIcons.circleUser, 'Профиль'),
];

/// Докуда натянуть вкладку, чтобы при отпускании перейти: доля ширины экрана.
const tabPullShare = 0.3;

/// «Натяжной» свайп (п. 77): вкладка тянется за пальцем, переход — только если
/// при отпускании натянули дальше [tabPullShare] ширины и вели вбок, а не вниз.
/// Скорость не важна: быстрый смах наискось вкладку не меняет.
bool tabPullCommits(Offset path, double width) =>
    path.dx.abs() >= width * tabPullShare && path.dx.abs() >= 2 * path.dy.abs();

class _Shell extends ConsumerStatefulWidget {
  const _Shell({required this.shell});

  final StatefulNavigationShell shell;

  @override
  ConsumerState<_Shell> createState() => _ShellState();
}

class _ShellState extends ConsumerState<_Shell> with TickerProviderStateMixin {
  int _visit = 0;

  /// Натяжение: откуда начали и насколько тянем сейчас (0 — покой).
  Offset? _pullFrom;
  Offset _pull = Offset.zero;

  /// Палец ушёл вниз/вверх сильнее, чем вбок, — это прокрутка, натяжение отменено.
  bool _pullCancelled = false;

  /// Возврат вкладки на место, если не дотянули.
  late final AnimationController _snap =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 220),
      )..addListener(
        () => setState(
          () => _pull = Offset(
            _snapFrom * (1 - Curves.easeOut.transform(_snap.value)),
            0,
          ),
        ),
      );
  double _snapFrom = 0;

  void _pullStart(DragStartDetails d) {
    _snap.stop();
    _pullFrom = d.globalPosition;
    _pullCancelled = false;
    setState(() => _pull = Offset.zero);
  }

  void _pullUpdate(DragUpdateDetails d) {
    final from = _pullFrom;
    if (from == null || _pullCancelled) return;
    final path = d.globalPosition - from;
    if (path.dy.abs() > path.dx.abs()) {
      _pullCancelled = true;
      _release();
      return;
    }
    setState(() => _pull = path);
  }

  void _pullEnd(DragEndDetails _) {
    final shell = widget.shell;
    final width = MediaQuery.sizeOf(context).width;
    final next = shell.currentIndex + (_pull.dx < 0 ? 1 : -1);
    if (!_pullCancelled &&
        tabPullCommits(_pull, width) &&
        next >= 0 &&
        next < _tabCount) {
      setState(() => _pull = Offset.zero);
      shell.goBranch(next, initialLocation: true);
    } else {
      _release();
    }
    _pullFrom = null;
  }

  /// Пружиной на место.
  void _release() {
    _snapFrom = _pull.dx;
    _snap.forward(from: 0);
  }

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
    _snap.dispose();
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

  /// «Потяни вниз»: синхронизация с сервером, свежие данные вкладок и журнал.
  Future<void> _refresh() async {
    final account = ref.read(accountProvider.notifier);
    if (!ref.read(accountProvider).signedIn) {
      showStatus(
        'Синхронизация — с аккаунтом. Войди в профиле',
        kind: StatusKind.info,
      );
      return;
    }
    await account.sync(reason: SyncReason.manual);
    // Шла фоновая синхронизация — sync() лишь поставил повтор; ждём, пока закончится.
    for (var i = 0; i < 75 && ref.read(accountProvider).syncing; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 200));
    }
    // То, что синхронизация сама не трогает: друзья, сезон.
    ref.invalidate(serverFriendsProvider);
    ref.invalidate(serverFriendsLeagueProvider);
    ref.invalidate(seasonProvider);
    await AppLog.upload(ref.read(apiProvider));
    if (!mounted) return;
    final error = ref.read(accountProvider).error;
    if (error == null) {
      showStatus('Синхронизировано', kind: StatusKind.success);
    } else {
      showStatusError(
        error,
        network: error.contains('недоступен') || error.contains('не отвечает'),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shell = widget.shell;
    final signedIn = ref.watch(accountProvider.select((a) => a.signedIn));
    // Новый заход на вкладку — блоки на ней появятся заново (FadeSlideIn).
    return Scaffold(
      // Свайп вбок — соседняя вкладка. Горизонтальные списки внутри экранов
      // перехватывают жест сами, поэтому мешать не будут.
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragStart: _pullStart,
        onHorizontalDragUpdate: _pullUpdate,
        onHorizontalDragEnd: _pullEnd,
        onHorizontalDragCancel: _release,
        child: _PullFrame(
          pull: _pull.dx,
          current: shell.currentIndex,
          // Свайп сверху вниз на любой вкладке — синхронизация (вертикальная прокрутка
          // любого уровня вложенности, когда она упёрлась в верх).
          child: RefreshIndicator(
            onRefresh: _refresh,
            notificationPredicate: (n) => n.metrics.axis == Axis.vertical,
            child: FadeTransition(
              opacity: _fade,
              child: ScaleTransition(
                scale: _scale,
                child: TabVisit(visit: _visit, child: shell),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: (i) =>
            // Вкладка всегда открывается с главного экрана, а не с последнего вложенного.
            shell.goBranch(i, initialLocation: true),
        destinations: [
          const NavigationDestination(
            icon: Icon(LucideIcons.personStanding),
            label: 'Герой',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.dumbbell),
            label: 'Тренировка',
          ),
          // Без аккаунта — с замком: дуэли и рейтинг после регистрации.
          NavigationDestination(
            icon: _Locked(locked: !signedIn, icon: LucideIcons.swords),
            label: 'Дуэли',
          ),
          NavigationDestination(
            icon: _Locked(locked: !signedIn, icon: LucideIcons.trophy),
            label: 'Рейтинг',
          ),
          const NavigationDestination(
            icon: Icon(LucideIcons.circleUser),
            label: 'Профиль',
          ),
        ],
      ),
    );
  }
}

/// Значок вкладки с маленьким замком: раздел откроется после регистрации.
class _Locked extends StatelessWidget {
  const _Locked({required this.locked, required this.icon});

  final bool locked;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Badge(
    isLabelVisible: locked,
    backgroundColor: Colors.transparent,
    offset: const Offset(6, -4),
    label: const Icon(LucideIcons.lock, size: 11, color: Colors.white70),
    child: Icon(icon),
  );
}

/// Вкладка, натянутая пальцем: сдвигается вслед (с сопротивлением), а сбоку
/// проявляется соседняя вкладка — значок и подпись. Натянули до точки перехода —
/// значок загорается: отпусти, и откроется она.
class _PullFrame extends StatelessWidget {
  const _PullFrame({
    required this.pull,
    required this.current,
    required this.child,
  });

  final double pull;
  final int current;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final target = current + (pull < 0 ? 1 : -1);
    final exists = pull != 0 && target >= 0 && target < _tabCount;
    // У крайних вкладок тянется туго — некуда.
    final shift = exists ? pull * 0.45 : pull * 0.12;
    final progress = (pull.abs() / (width * tabPullShare)).clamp(0.0, 1.0);
    final ready = exists && progress >= 1;
    final accent = Theme.of(context).colorScheme.primary;
    return Stack(
      children: [
        Positioned.fill(
          child: Transform.translate(offset: Offset(shift, 0), child: child),
        ),
        if (exists)
          Positioned(
            top: 0,
            bottom: 0,
            left: pull > 0 ? 8 : null,
            right: pull < 0 ? 8 : null,
            child: IgnorePointer(
              child: Center(
                child: Opacity(
                  opacity: progress,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: ready ? accent : AppColors.raised,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _tabs[target].$1,
                          size: 22,
                          color: ready
                              ? AppColors.onAccent
                              : AppColors.textSecondary,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _tabs[target].$2,
                          style: TextStyle(
                            fontSize: 11,
                            color: ready
                                ? AppColors.onAccent
                                : AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
