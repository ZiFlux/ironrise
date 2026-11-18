import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../avatar/avatar_view.dart';
import '../game/duel.dart';
import '../game/game_config.dart';
import '../net/api_client.dart';
import '../state/fight_state.dart';
import '../state/account_state.dart';
import '../state/aura_state.dart';
import '../state/season_state.dart';
import '../state/duel_state.dart';
import '../state/providers.dart';
import '../state/server_game.dart';
import '../theme.dart';
import '../widgets/aura_flame.dart';
import '../widgets/sign_in_gate.dart';
import '../widgets/fit_screen.dart';
import '../widgets/motion.dart';
import '../widgets/status_toast.dart';
import '../widgets/guide.dart';
import '../widgets/info_bubble.dart';
import '../widgets/fighter_compare.dart';

/// Дуэли (экран 9). С аккаунтом — боты дня и друзья через сервер,
/// без аккаунта — локальные боты.
class DuelsScreen extends ConsumerStatefulWidget {
  const DuelsScreen({super.key});

  @override
  ConsumerState<DuelsScreen> createState() => _DuelsScreenState();
}

class _DuelsScreenState extends ConsumerState<DuelsScreen> {
  bool _friendsTab = false;

  @override
  void initState() {
    super.initState();
    // Начатый бой (ушли с экрана, закрыли приложение) — показать «Продолжить».
    Future.microtask(() {
      if (!mounted || !ref.read(accountProvider).signedIn) return;
      if (ref.read(fightProvider) == null) {
        ref.read(fightProvider.notifier).resume();
      }
    });
  }

  /// Бой по раундам (docs/COMBAT.md): начать и открыть экран боя. Есть
  /// незаконченный — продолжить его.
  Future<void> _openFight(Future<FightView> Function() start) async {
    final fights = ref.read(fightProvider.notifier);
    try {
      await start();
      if (mounted) context.go('/duels/fight');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.status == 409 && e.message.startsWith('Finish the current fight')) {
        if (await fights.resume() != null && mounted) {
          showStatus('Сначала доиграй начатый бой');
          context.go('/duels/fight');
        }
        return;
      }
      showStatusError(e.message, network: e.isNetwork);
    }
  }

  @override
  Widget build(BuildContext context) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final me = playerFighter(hero);

    if (!ref.watch(accountProvider).signedIn) {
      return const SignInGate(
        title: 'Дуэли',
        icon: LucideIcons.swords,
        text:
            'Бои с ботами и друзьями, монеты за победы и очки в лигу. '
            'Результаты считает сервер — нужен аккаунт.',
      );
    }

    final friends = ref.watch(serverFriendsProvider);
    final incoming = friends.value?.incoming.length ?? 0;
    return _Page(
      actions: [
        GuideTarget(
          id: 'duels.friends',
          child: IconButton(
            tooltip: 'Друзья',
            onPressed: () => context.push('/duels/friends'),
            icon: Badge(
              isLabelVisible: incoming > 0,
              label: Text('$incoming'),
              child: const Icon(LucideIcons.userPlus, size: 20),
            ),
          ),
        ),
        const SizedBox(width: 8),
      ],
      header: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (ref.watch(fightProvider) case final f? when !f.finished)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: _ResumeFight(
                rival: f.defender.name,
                round: f.round,
                rounds: f.rules.rounds,
                onTap: () => context.go('/duels/fight'),
              ),
            ),
          // Сезон и аура — на виду: прогресс батлпаса и способность для боя.
          const _Perks(),
          const SizedBox(height: 4),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Лестница')),
              ButtonSegment(value: true, label: Text('Друзья')),
            ],
            selected: {_friendsTab},
            showSelectedIcon: false,
            onSelectionChanged: (s) => setState(() => _friendsTab = s.first),
          ),
        ],
      ),
      body: _friendsTab
          ? friends.when(
              data: (d) => d.friends.isEmpty
                  ? _Empty(onFind: () => context.push('/duels/friends'))
                  : _FighterList(
                      me: me,
                      fighters: d.friends,
                      results: d.results,
                      counter: 'осталось боёв: ${d.fightsLeft}',
                      footer: 'С каждым другом — один бой в день. Друг может быть не в сети',
                      scrollable: true,
                      onFight: (f) => _openFight(
                        () => ref.read(fightProvider.notifier).startFriend(f),
                      ),
                    ),
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  _Retry(onRetry: () => ref.invalidate(serverFriendsProvider)),
            )
          : ref
                .watch(serverBotsProvider)
                .when(
                  data: (d) => _FighterList(
                    me: me,
                    fighters: d.bots,
                    results: d.results,
                    repeatable: true,
                    ladder: d.ladder,
                    nextFightAt: d.nextFightAt,
                    counter: _botsCounter(d.fights.values),
                    footer: d.ladder == null ? _botsFooter : _ladderFooter,
                    onFight: (bot) => _openFight(
                      () => ref.read(fightProvider.notifier).startBot(bot),
                    ),
                  ),
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      _Retry(onRetry: () => ref.invalidate(serverBotsProvider)),
                ),
    );
  }
}

/// «боёв сегодня: 5».
String _botsCounter(Iterable<int> fights) =>
    'боёв сегодня: ${fights.fold(0, (a, b) => a + b)}';

/// Коротко: правила лестницы — в облаке строки ступени.
const _ladderFooter = '3 победы — босс, босс — ступень выше';

final _botsFooter =
    'С ботом — раз в ${GameConfig.duelCooldown.inHours} ч, повтор за сутки — ½ монет. Новые — каждый день';

/// Две плашки над списком: сезон (уровень и прогресс) и аура (какая выбрана).
class _Perks extends ConsumerWidget {
  const _Perks();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final season = ref.watch(seasonProvider).value;
    final auras = ref.watch(auraProvider).value;
    final aura = auras?.equipped;
    final auraLevel = aura == null
        ? 0
        : auras!.auras.firstWhere((a) => a.kind == aura).level;
    return SizedBox(
      height: MediaQuery.textScalerOf(context).scale(48),
      child: Row(
        children: [
          Expanded(
            child: _PerkCard(
              color: const Color(0xFFD9B25A),
              icon: LucideIcons.sparkles,
              title: season == null
                  ? 'Сезон'
                  : 'Сезон ${season.number} · ур. ${season.level}',
              subtitle: season == null
                  ? 'Батлпас: награды за бои'
                  : season.level >= season.maxLevel
                  ? 'Все уровни взяты'
                  : '${season.pointsIntoLevel}/${season.levelPoints} до ур. ${season.level + 1}',
              progress: season == null
                  ? null
                  : season.level >= season.maxLevel
                  ? 1
                  : season.pointsIntoLevel / season.levelPoints,
              onTap: () => context.push('/season'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _PerkCard(
              color: aura?.color ?? const Color(0xFFFF5A1F),
              icon: auraIcon(aura),
              title: aura == null ? 'Ауры' : 'Аура: ${aura.label}',
              subtitle: aura == null
                  ? 'Способность в бою — открой'
                  : 'ур. $auraLevel · ${auras!.sessionsThisWeek}/${auras.perWeek} трен. за неделю',
              onTap: () => context.push('/duels/auras'),
            ),
          ),
        ],
      ),
    );
  }
}

class _PerkCard extends StatelessWidget {
  const _PerkCard({
    required this.color,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.progress,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String subtitle;
  final double? progress;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    // Нейтральная поверхность: цвет несёт только иконка (сезон — награды, аура — её цвет).
    color: AppColors.surface,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        child: Row(
          children: [
            Icon(icon, size: 20, color: color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  if (progress case final p?) ...[
                    const SizedBox(height: 1),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        value: p.clamp(0, 1),
                        minHeight: 3,
                        color: color,
                        backgroundColor: AppColors.raised,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Page extends StatelessWidget {
  const _Page({required this.body, this.header, this.actions});

  final Widget body;
  final Widget? header;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Дуэли'), actions: actions),
    body: SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null) ...[header!, const SizedBox(height: 4)],
            GuideTarget(
              id: 'duels.list',
              child: Expanded(child: body),
            ),
          ],
        ),
      ),
    ),
  );
}

class _Retry extends StatelessWidget {
  const _Retry({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Нет связи с сервером',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Повторить')),
      ],
    ),
  );
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onFind});

  final VoidCallback onFind;

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(LucideIcons.users, size: 40, color: AppColors.textMuted),
        const SizedBox(height: 12),
        const Text(
          'Пока нет друзей',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        const SizedBox(height: 4),
        const Text(
          'Найди друга по нику и вызови на дуэль',
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: onFind,
          style: FilledButton.styleFrom(minimumSize: const Size(200, 48)),
          icon: const Icon(LucideIcons.userPlus, size: 18),
          label: const Text('Найти друзей'),
        ),
      ],
    ),
  );
}

/// Сила игрока и соперники. Ботов всегда 4 — они делят экран без прокрутки;
/// друзей может быть много, тогда список прокручивается внутри.
class _FighterList extends StatelessWidget {
  const _FighterList({
    required this.me,
    required this.fighters,
    required this.results,
    required this.counter,
    required this.footer,
    required this.onFight,
    this.scrollable = false,
    this.repeatable = false,
    this.nextFightAt = const {},
    this.ladder,
  });

  /// Лестница ботов: ступень, босс и побеждённые (п. 88).
  final BotLadder? ladder;

  final Fighter me;
  final List<Fighter> fighters;
  final Map<String, bool> results;

  /// С ботами можно драться снова после перезарядки; с друзьями — раз в день.
  final bool repeatable;
  final Map<String, DateTime> nextFightAt;
  final String counter;
  final String footer;
  final void Function(Fighter) onFight;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    Widget card(Fighter f, int i) => FadeSlideIn(
      index: i,
      child: Pressable(
        child: _FighterCard(
          fighter: f,
          me: me,
          // С друзьями — раз в день (не repeatable): у них есть профиль.
          friend: !repeatable,
          myPower: me.power,
          result: results[f.id],
          repeatable: repeatable,
          nextFightAt: nextFightAt[f.id],
          onFight: () => onFight(f),
          beaten: ladder?.beaten.contains(f.id) ?? false,
          boss: ladder != null && f.id == ladder!.bossId,
          locked:
              ladder != null && f.id == ladder!.bossId && !ladder!.bossUnlocked,
          compact: fighters.length > 4,
          winsLeft: ladder == null
              ? 0
              : (ladder!.winsToBoss - ladder!.wins).clamp(0, 9),
        ),
      ),
    );
    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Лестница: одна строка — ступень слева, сила справа (была строка силы
        // со счётчиком боёв и строка ступени — две строки шапки на одно и то же).
        if (ladder case final l?)
          _LadderLine(ladder: l, power: me.power)
        else
          // Друзья: сила и счётчик боёв одной строкой.
          Row(
            children: [
              Flexible(
                child: Tappable(
                  radius: 8,
                  onTap: (c) => showInfoBubble(
                    c,
                    title: 'Твоя сила ${me.power}',
                    text:
                        'В бою здоровье равно силе. Сила растёт только от тренировок: '
                        '10 за уровень части тела и 2 за день серии (до 30).',
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(LucideIcons.zap, size: 16, color: accent),
                      const SizedBox(width: 6),
                      Text(
                        '${me.power}',
                        style: figureStyle(size: 16, color: accent),
                      ),
                      const SizedBox(width: 6),
                      const Flexible(
                        child: Text(
                          'твоя сила',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Tappable(
                  radius: 8,
                  onTap: (c) => showInfoBubble(
                    c,
                    title: 'Бои на сегодня',
                    text:
                        '${repeatable ? 'С каждым ботом можно драться снова после перезарядки, повторный бой — половина монет.' : 'С каждым другом — один бой в день.'} '
                        'Счётчик обнулится в полночь — ${_untilMidnight()}.',
                  ),
                  child: Text(
                    counter,
                    textAlign: TextAlign.end,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        const SizedBox(height: 8),
        if (scrollable)
          Expanded(
            child: ListView.separated(
              itemCount: fighters.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              // Крупный системный шрифт — карточка выше, иначе текст не влезет.
              itemBuilder: (_, i) => SizedBox(
                height: MediaQuery.textScalerOf(context).scale(72),
                child: card(fighters[i], i),
              ),
            ),
          )
        else
          for (final (i, f) in fighters.indexed)
            FlexibleMin(
              // Лестница — 5 соперников (4 бота и босс): карточки ниже, чтобы влезли.
              minHeight: MediaQuery.textScalerOf(context)
                  .scale(fighters.length > 4 ? 44 : 66),
              child: Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: card(f, i),
              ),
            ),
        const SizedBox(height: 4),
        Text(
          footer,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
        ),
      ],
    );
    // Боты (их 4) делят экран; не влезают — прокрутка. Друзья прокручиваются списком.
    return scrollable ? list : FitScreen(child: list);
  }
}

/// «через 3 ч 12 мин» до полуночи.
String _untilMidnight() {
  final now = DateTime.now();
  final left = DateTime(now.year, now.month, now.day + 1).difference(now);
  final h = left.inHours;
  final m = left.inMinutes % 60;
  return h > 0 ? 'через $h ч $m мин' : 'через $m мин';
}

class _FighterCard extends StatelessWidget {
  const _FighterCard({
    required this.fighter,
    required this.me,
    this.friend = false,
    required this.myPower,
    required this.result,
    required this.onFight,
    this.repeatable = false,
    this.nextFightAt,
    this.beaten = false,
    this.boss = false,
    this.locked = false,
    this.winsLeft = 0,
    this.compact = false,
  });

  /// Узкая карточка: соперников больше четырёх.
  final bool compact;

  /// Лестница: уже побеждён (повтор — 30 % монет), босс ступени, босс ещё закрыт.
  final bool beaten;
  final bool boss;
  final bool locked;
  final int winsLeft;

  final Fighter fighter;
  final Fighter me;
  final bool friend;
  final int myPower;
  final bool? result;
  final VoidCallback onFight;
  final bool repeatable;

  /// Перезарядка: снова можно драться с этого времени.
  final DateTime? nextFightAt;

  /// «через 3 ч 12 мин».
  static String _wait(DateTime at) {
    final left = at.difference(DateTime.now());
    final h = left.inHours;
    final m = left.inMinutes % 60 + 1;
    return h > 0 ? 'через $h ч $m мин' : 'через $m мин';
  }

  String get _strength {
    final ratio = fighter.power / myPower;
    if (ratio < 0.93) return 'слабее';
    if (ratio > 1.07) return 'сильнее';
    return 'на равных';
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 12, 6),
        // Карточки делят экран: соперник растёт вместе с карточкой, а не тонет в ней.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: Tappable(
                semantics: '${fighter.name}, сила ${fighter.power}, сравнить',
                onTap: (_) => showFighterCompare(
                  context,
                  me: me,
                  rival: fighter,
                  friendId: friend ? fighter.id : null,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Пять соперников (лестница) — узкая колонка без пропорции:
                    // иначе высота аватара (2 × ширина) раздувает список.
                    if (compact)
                      SizedBox(
                        width: 40,
                        child: AvatarView(
                          levels: fighter.levels,
                          look: fighter.lookOrStarter,
                        ),
                      )
                    else
                      ConstrainedBox(
                        constraints: const BoxConstraints(
                          minWidth: 48,
                          maxWidth: 88,
                        ),
                        child: AspectRatio(
                          aspectRatio: 0.5,
                          child: AvatarView(
                            levels: fighter.levels,
                            look: fighter.lookOrStarter,
                          ),
                        ),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (boss) ...[
                                Icon(
                                  LucideIcons.crown,
                                  size: 15,
                                  color: Theme.of(context).colorScheme.primary,
                                ),
                                const SizedBox(width: 4),
                              ],
                              Flexible(
                                child: Text(
                                  fighter.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 15,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              if (beaten) ...[
                                const SizedBox(width: 4),
                                const Icon(
                                  LucideIcons.check,
                                  size: 14,
                                  color: AppColors.textMuted,
                                ),
                              ],
                              if (fighter.aura case final aura?) ...[
                                const SizedBox(width: 6),
                                Tooltip(
                                  message:
                                      'Аура: ${aura.label}, ур. ${fighter.auraLevel}',
                                  child: Icon(
                                    auraIcon(aura),
                                    size: 14,
                                    color: aura.color,
                                  ),
                                ),
                                Text(
                                  '${fighter.auraLevel}',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: aura.color,
                                  ),
                                ),
                              ],
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'сила ${fighter.power} · $_strength',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // Пять соперников — пять кнопок: залитые акцентом кричали бы все разом,
            // поэтому «В бой» — мягкая заливка акцентом: видно, что это кнопка.
            if (locked)
              Center(
                child: Tappable(
                  radius: 8,
                  onTap: (c) => showInfoBubble(
                    c,
                    title: 'Босс ступени',
                    text:
                        'Откроется после ещё ${_wins(winsLeft)} на этой ступени. '
                        'Победа над боссом открывает следующую ступень.',
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(
                      LucideIcons.lock,
                      size: 20,
                      color: AppColors.textMuted,
                    ),
                  ),
                ),
              )
            else if (result == null)
              Center(
                child: _FightButton(label: 'В бой', onTap: onFight),
              )
            else if (repeatable && nextFightAt == null)
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _FightButton(label: 'Ещё бой', onTap: onFight),
                    const SizedBox(height: 1),
                    Text(
                      beaten ? '30 % монет' : '½ монет',
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              )
            else
              Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Tappable(
                      radius: 8,
                      onTap: (c) => showInfoBubble(
                        c,
                        title: result! ? 'Победа' : 'Поражение',
                        text: result!
                            ? 'Победа приносит монеты и +${GameConfig.leagueWinPoints} '
                                  'очков в лигу недели.${repeatable ? ' Повторный бой с тем же ботом — половина монет.' : ''}'
                            : 'Поражение ничего не отнимает. Сила растёт только от '
                                  'тренировок — подтяни отстающую часть тела и возвращайся.',
                      ),
                      child: _ResultTag(
                        result! ? 'Победа' : 'Поражение',
                        result!,
                      ),
                    ),
                    if (repeatable && nextFightAt != null)
                      Text(
                        _wait(nextFightAt!),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FightButton extends StatelessWidget {
  const _FightButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        minimumSize: const Size(96, 44),
        foregroundColor: accent,
        backgroundColor: accent.withValues(alpha: 0.14),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        // Шрифт — из темы (Inter): свой TextStyle без семейства уводил бы в Roboto.
        textStyle: Theme.of(context).textTheme.labelLarge
            ?.copyWith(fontSize: 15, fontWeight: FontWeight.w500),
      ),
      icon: const Icon(LucideIcons.swords, size: 16),
      label: Text(label),
    );
  }
}

class _ResultTag extends StatelessWidget {
  const _ResultTag(this.text, this.won);

  final String text;
  final bool won;

  @override
  Widget build(BuildContext context) {
    final color = won
        ? Theme.of(context).colorScheme.primary
        : AppColors.textMuted;
    return Text(
      text,
      style: TextStyle(fontSize: 14, color: color, fontWeight: FontWeight.w500),
    );
  }
}

/// «1 бота», «2 ботов».
/// «1 победа», «2 победы», «5 побед».
String _winsNom(int n) {
  final m10 = n % 10, m100 = n % 100;
  if (m10 == 1 && m100 != 11) return '$n победа';
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return '$n победы';
  return '$n побед';
}

/// «после ещё 1 победы», «2 побед» — родительный падеж.
String _wins(int n) {
  final m10 = n % 10, m100 = n % 100;
  return m10 == 1 && m100 != 11 ? '$n победы' : '$n побед';
}

/// «3 ботов» (побей … ботов) — винительный для одушевлённых.
String _bots(int n) {
  final m10 = n % 10, m100 = n % 100;
  return m10 == 1 && m100 != 11 ? '$n бота' : '$n ботов';
}

/// Строка лестницы над соперниками: ступень, название и сколько до босса.
class _LadderLine extends StatelessWidget {
  const _LadderLine({required this.ladder, required this.power});

  final BotLadder ladder;

  /// Своя сила — справа: с ней сравниваются соперники ниже.
  final int power;

  @override
  Widget build(BuildContext context) {
    final left = (ladder.winsToBoss - ladder.wins).clamp(0, 9);
    final progress = ladder.bossUnlocked
        ? 'босс открыт'
        : 'до босса — ${_winsNom(left)}';
    final next = ladder.nextName == null ? '' : ' — «${ladder.nextName}»';
    return Tappable(
      radius: 8,
      semantics: 'Лестница ботов',
      onTap: (c) => showInfoBubble(
        c,
        title: 'Ступень ${ladder.tier + 1} из ${ladder.tiers}: ${ladder.name}',
        text:
            'Сначала у всех слабые соперники, выше — всё сильнее. Побей '
            '${_bots(ladder.winsToBoss)} ступени — откроется босс, победа над ним '
            'ведёт выше$next. Первая победа над ботом — полная награда, '
            'повторные — 30 %. Сила растёт только от тренировок.',
      ),
      child: Row(
        children: [
          Icon(
            LucideIcons.chartNoAxesColumnIncreasing,
            size: 15,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ladder.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  'Ступень ${ladder.tier + 1} из ${ladder.tiers} · $progress',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    LucideIcons.zap,
                    size: 14,
                    color: Theme.of(context).colorScheme.secondary,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$power',
                    style: figureStyle(
                      size: 16,
                      color: Theme.of(context).colorScheme.secondary,
                    ),
                  ),
                ],
              ),
              const Text(
                'твоя сила',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Плашка начатого боя: продолжить с того раунда, где остановились.
class _ResumeFight extends StatelessWidget {
  const _ResumeFight({
    required this.rival,
    required this.round,
    required this.rounds,
    required this.onTap,
  });

  final String rival;
  final int round;
  final int rounds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Card(
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
          child: Row(
            children: [
              Icon(LucideIcons.swords, size: 18, color: accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Бой с $rival не закончен · раунд ${round + 1} из $rounds',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              TextButton(onPressed: onTap, child: const Text('Продолжить')),
            ],
          ),
        ),
      ),
    );
  }
}
