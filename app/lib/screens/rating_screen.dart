import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_config.dart';
import '../game/league.dart';
import '../state/account_state.dart';
import '../state/server_game.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/fit_screen.dart';
import '../widgets/sign_in_gate.dart';
import '../widgets/motion.dart';
import '../widgets/guide.dart';
import '../widgets/info_bubble.dart';
import '../widgets/status_toast.dart';
import '../net/api_client.dart';

/// Рейтинг (экран 10): недельная лига. Пока с ботами, друзья и вуз — с сервером.
class RatingScreen extends ConsumerWidget {
  const RatingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    if (ref.watch(accountProvider).signedIn) return const _ServerRating();
    return const SignInGate(
      title: 'Рейтинг',
      icon: LucideIcons.trophy,
      text:
          'Лиги с живыми игроками: бронза, серебро и золото, повышение и '
          'понижение каждую неделю. Прогресс хранится на сервере — нужен аккаунт.',
    );
  }
}

class _LeagueView extends StatelessWidget {
  const _LeagueView({
    required this.table,
    this.trainedDays,
    this.wins,
    this.header,
    this.title = 'Лига недели',
    this.footer = 'Рейтинг «Мой вуз» появится позже',
    this.tier,
    this.promoteTop = 0,
    this.minDaysToPromote = 1,
    this.demoteBottom = 0,
    this.lastWeek,
  });

  final List<LeagueEntry> table;

  /// null — не показываем строку «У тебя» (лига друзей).
  final int? trainedDays;
  final int? wins;
  final Widget? header;
  final String title;
  final String footer;

  /// null — лига без уровней (друзья, без аккаунта).
  final LeagueTier? tier;
  final int promoteTop;

  /// Сколько тренировочных дней нужно для повышения (с платиновой — 3, п. 108).
  final int minDaysToPromote;
  final int demoteBottom;
  final LeagueWeekResult? lastWeek;

  _Zone _zoneOf(int place) {
    if (tier == null) return _Zone.none;
    if (place <= promoteTop && tier != LeagueTier.values.last) return _Zone.up;
    if (place > table.length - demoteBottom &&
        tier != LeagueTier.values.first) {
      return _Zone.down;
    }
    return _Zone.none;
  }

  /// Больше строк, чем помещается на экран, — список прокручивается внутри.
  static const _fitRows = 8;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final daysLeft = 7 - now.weekday;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Рейтинг'),
        actions: [
          IconButton(
            tooltip: 'Сезон и батлпас',
            onPressed: () => context.push('/season'),
            icon: const Icon(LucideIcons.sparkles, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: _fitOrList(
          table.length <= _fitRows,
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (header != null) ...[header!, const SizedBox(height: 8)],
                if (lastWeek case final week?) ...[
                  _LastWeekBanner(result: week),
                  const SizedBox(height: 8),
                ],
                GuideTarget(
                  id: 'rating.league',
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              if (tier != null) ...[
                                Icon(
                                  LucideIcons.medal,
                                  size: 18,
                                  color: tier!.color,
                                ),
                                const SizedBox(width: 8),
                              ],
                              Expanded(
                                // Нажатие на лигу — все лиги этой недели (п. 108).
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: tier == null
                                      ? null
                                      : () => showLeaguesSheet(context, tier!),
                                  child: Row(
                                    children: [
                                      Flexible(
                                        child: Text(
                                          tier?.title ?? title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      if (tier != null)
                                        const Icon(
                                          LucideIcons.chevronRight,
                                          size: 16,
                                          color: AppColors.textMuted,
                                        ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                daysLeft == 0
                                    ? 'последний день'
                                    : 'ещё $daysLeft дн.',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            // Правила подъёма и вылета — в листе лиг по нажатию на название.
                            'Тренировка +${GameConfig.leagueWorkoutPoints} · '
                            'победа +${GameConfig.leagueWinPoints}'
                            '${trainedDays == null ? '' : ' · у тебя $trainedDays трен., $wins побед'}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Таблица — одна карточка со строками, а не стопка отдельных карточек.
                if (table.length <= _fitRows)
                  Flexible(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final (i, entry) in table.indexed)
                            Flexible(
                              child: ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: MediaQuery.textScalerOf(context)
                                      .scale(36),
                                  maxHeight: MediaQuery.textScalerOf(context)
                                      .scale(56),
                                ),
                                child: FadeSlideIn(
                                  index: i,
                                  child: _Row(
                                    place: i + 1,
                                    entry: entry,
                                    zone: _zoneOf(i + 1),
                                    first: i == 0,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: Card(
                      clipBehavior: Clip.antiAlias,
                      child: ListView.builder(
                        itemCount: table.length,
                        itemBuilder: (_, i) => SizedBox(
                          height: MediaQuery.textScalerOf(context).scale(48),
                          child: FadeSlideIn(
                            index: i,
                            child: _Row(
                              place: i + 1,
                              entry: table[i],
                              zone: _zoneOf(i + 1),
                              first: i == 0,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  footer,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

enum _Zone { none, up, down }

/// Нажатие на строку лиги (п. 127): друг — профиль, ты — твой профиль, бот и
/// незнакомый игрок — облако с очками (незнакомого можно позвать в друзья).
void _openEntry(BuildContext anchor, int place, LeagueEntry e, _Zone zone) {
  if (e.friendId case final id?) {
    anchor.push('/friend/$id');
    return;
  }
  final zoneLine = switch (zone) {
    _Zone.up => '\nСейчас в зоне повышения.',
    _Zone.down => '\nСейчас в зоне вылета.',
    _Zone.none => '',
  };
  final points =
      '${e.points} очков: тренировка +${GameConfig.leagueWorkoutPoints}, '
      'победа в дуэли +${GameConfig.leagueWinPoints}.$zoneLine';
  if (e.isPlayer) {
    showInfoBubble(
      anchor,
      title: '$place место — это ты',
      text: points,
      actionLabel: 'Мой профиль',
      onAction: () => anchor.go('/profile'),
    );
  } else if (e.isBot) {
    showInfoBubble(
      anchor,
      title: '${e.name} · бот лиги',
      text:
          'Боты держат лигу живой, пока игроков мало: их очки подстраиваются '
          'под активность лиги. $points',
    );
  } else {
    showInfoBubble(
      anchor,
      title: '$place место · ${e.name}',
      text: '$points\nПрофиль видно друзьям.',
      actionLabel: 'Добавить в друзья',
      onAction: () async {
        try {
          await ProviderScope.containerOf(anchor, listen: false)
              .read(apiProvider)
              .post('/v1/friends/requests', {'nickname': e.name});
          showStatus('Заявка отправлена', kind: StatusKind.success);
        } on ApiException catch (err) {
          showStatusError(err.message, network: err.isNetwork);
        }
      },
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.place,
    required this.entry,
    this.zone = _Zone.none,
    this.first = false,
  });

  /// Первая строка — без разделителя сверху.
  final bool first;

  final int place;
  final LeagueEntry entry;
  final _Zone zone;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final me = entry.isPlayer;
    return Tappable(
      radius: 0,
      semantics: '$place место, ${entry.name}, ${entry.points} очков',
      onTap: (c) => _openEntry(c, place, entry, zone),
      child: _content(accent, me),
    );
  }

  Widget _content(Color accent, bool me) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        // Своя строка — ступень поверхности, а не лаймовая заливка.
        color: me ? AppColors.raised : null,
        border: first
            ? null
            : const Border(top: BorderSide(color: AppColors.hairline)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$place',
              style: figureStyle(
                size: 15,
                color: place <= 3 ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          Expanded(
            child: Text(
              me ? '${entry.name} (ты)' : entry.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 15,
                fontWeight: me ? FontWeight.w500 : FontWeight.w400,
              ),
            ),
          ),
          if (zone != _Zone.none) ...[
            Icon(
              zone == _Zone.up
                  ? LucideIcons.chevronsUp
                  : LucideIcons.chevronsDown,
              size: 16,
              // Подъём — хорошо (цвет успеха), вылет — приглушённо.
              color: zone == _Zone.up ? AppColors.success : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
          ],
          Text(
            '${entry.points}',
            style: figureStyle(
              size: 15,
              color: me ? accent : AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Рейтинг с аккаунтом: лига недели с ботами или таблица среди друзей.
class _ServerRating extends ConsumerStatefulWidget {
  const _ServerRating();

  @override
  ConsumerState<_ServerRating> createState() => _ServerRatingState();
}

class _ServerRatingState extends ConsumerState<_ServerRating> {
  bool _friends = false;

  @override
  Widget build(BuildContext context) {
    final header = SegmentedButton<bool>(
      segments: const [
        ButtonSegment(value: false, label: Text('Лига')),
        ButtonSegment(value: true, label: Text('Друзья')),
      ],
      selected: {_friends},
      showSelectedIcon: false,
      onSelectionChanged: (s) => setState(() => _friends = s.first),
    );
    Widget status(Widget child) => Scaffold(
      appBar: AppBar(
        title: const Text('Рейтинг'),
        actions: [
          IconButton(
            tooltip: 'Сезон и батлпас',
            onPressed: () => context.push('/season'),
            icon: const Icon(LucideIcons.sparkles, size: 20),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            Expanded(child: Center(child: child)),
          ],
        ),
      ),
    );
    Widget retry(VoidCallback onRetry) => TextButton(
      onPressed: onRetry,
      child: const Text('Нет связи с сервером. Повторить'),
    );

    if (_friends) {
      return ref
          .watch(serverFriendsLeagueProvider)
          .when(
            data: (entries) => entries.length <= 1
                ? status(
                    const Text(
                      'Добавь друзей во вкладке «Дуэли», и здесь появится ваша таблица',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  )
                : _LeagueView(
                    table: entries,
                    header: header,
                    title: 'Друзья за неделю',
                    footer:
                        'Очки за активность: кто чаще тренируется, тот выше',
                  ),
            loading: () => status(const CircularProgressIndicator()),
            error: (e, _) => status(
              retry(() => ref.invalidate(serverFriendsLeagueProvider)),
            ),
          );
    }
    return ref
        .watch(serverLeagueProvider)
        .when(
          data: (d) => _LeagueView(
            table: d.entries,
            trainedDays: d.trainedDays,
            wins: d.wins,
            header: header,
            tier: d.tier,
            promoteTop: d.promoteTop,
            minDaysToPromote: d.minDaysToPromote,
            demoteBottom: d.demoteBottom,
            lastWeek: d.lastWeek,
          ),
          loading: () => status(const CircularProgressIndicator()),
          error: (e, _) =>
              status(retry(() => ref.invalidate(serverLeagueProvider))),
        );
  }
}

/// Итог прошлой недели: «2 место — ты поднялся в Серебряную лигу».
class _LastWeekBanner extends StatelessWidget {
  const _LastWeekBanner({required this.result});

  final LeagueWeekResult result;

  String get _text {
    final after = LeagueTier.of(result.tierAfter).title.toLowerCase();
    return switch (result.outcome) {
      'up' when result.tierAfter > result.tierBefore =>
        'Прошлая неделя: ${result.rank} место — ты поднялся: $after',
      'down' when result.tierAfter < result.tierBefore =>
        'Прошлая неделя: ${result.rank} место — лига ниже: $after',
      _ => 'Прошлая неделя: ${result.rank} место, лига та же',
    };
  }

  @override
  Widget build(BuildContext context) {
    final tier = LeagueTier.of(result.tierAfter);
    return Tappable(
      radius: 12,
      onTap: (c) => showInfoBubble(
        c,
        title: 'Итог прошлой недели',
        text:
            '${result.rank} место в лиге «${LeagueTier.of(result.tierBefore).title}». '
            'Теперь: «${tier.title}». Новая неделя началась с нуля — очки копятся '
            'с понедельника до воскресенья.',
      ),
      child: _banner(tier),
    );
  }

  Widget _banner(LeagueTier tier) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.hairline),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.medal, size: 16, color: tier.color),
          const SizedBox(width: 8),
          Expanded(child: Text(_text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

/// Таблица до 8 строк — на один экран (прокрутка, только если не влезает);
/// длиннее — прокручивается сам список, шапка остаётся на месте.
Widget _fitOrList(bool fits, Widget child) =>
    fits ? FitScreen(child: child) : child;

/// Все лиги этой недели (п. 108): выбрать лигу и посмотреть её таблицу.
Future<void> showLeaguesSheet(BuildContext context, LeagueTier mine) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (_, scroll) => _LeaguesSheet(mine: mine, scroll: scroll),
      ),
    );

class _LeaguesSheet extends ConsumerStatefulWidget {
  const _LeaguesSheet({required this.mine, required this.scroll});

  final LeagueTier mine;
  final ScrollController scroll;

  @override
  ConsumerState<_LeaguesSheet> createState() => _LeaguesSheetState();
}

class _LeaguesSheetState extends ConsumerState<_LeaguesSheet> {
  late LeagueTier _tier = widget.mine;

  /// Как выйти выше из этой лиги — как на сервере (server/src/game/league.ts).
  static String _rule(LeagueTier t) {
    if (t == LeagueTier.values.last)
      return 'Вершина: не опускайся в последние 2 места';
    final top = t.index >= 2 ? 'первое место' : 'первые 2 места';
    final days = t.index >= 3 ? ' и 3 тренировочных дня' : '';
    return 'Вверх: $top$days';
  }

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(serverLeagueTierProvider(_tier.index));
    return ListView(
      controller: widget.scroll,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      children: [
        const Text(
          'Лиги недели',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 4),
        const Text(
          'От бронзовой к чемпионской. Неделя без тренировок или последние 2 места — '
          'на ступень ниже. Нажми на лигу, чтобы увидеть её таблицу.',
          style: TextStyle(fontSize: 13, color: AppColors.textMuted),
        ),
        const SizedBox(height: 12),
        // Лестница по возрастанию: номер ступени, медаль, правило выхода вверх.
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final t in LeagueTier.values)
                _LeagueStep(
                  tier: t,
                  mine: t == widget.mine,
                  selected: t == _tier,
                  rule: _rule(t),
                  first: t.index == 0,
                  onTap: () => setState(() => _tier = t),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(LucideIcons.medal, size: 18, color: _tier.color),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                _tier == widget.mine ? '${_tier.title} — твоя' : _tier.title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        table.when(
          data: (rows) => rows.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'В этой лиге пока никого',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              : Card(
                  clipBehavior: Clip.antiAlias,
                  child: Column(
                    children: [
                      for (final (i, e) in rows.indexed)
                        _Row(place: i + 1, entry: e, first: i == 0),
                    ],
                  ),
                ),
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          ),
          error: (_, _) => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: Text(
                'Не удалось загрузить — проверьте сеть',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Ступень лестницы лиг.
class _LeagueStep extends StatelessWidget {
  const _LeagueStep({
    required this.tier,
    required this.mine,
    required this.selected,
    required this.rule,
    required this.first,
    required this.onTap,
  });

  final LeagueTier tier;
  final bool mine;
  final bool selected;
  final String rule;
  final bool first;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.raised : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            border: first
                ? null
                : const Border(top: BorderSide(color: AppColors.hairline)),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 22,
                child: Text(
                  '${tier.index + 1}',
                  style: figureStyle(size: 14, color: AppColors.textMuted),
                ),
              ),
              Icon(LucideIcons.medal, size: 20, color: tier.color),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tier.title,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    Text(
                      rule,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              if (mine)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: tier.color.withValues(alpha: 0.18),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'твоя',
                    style: TextStyle(fontSize: 12, color: tier.color),
                  ),
                ),
              if (selected) ...[
                const SizedBox(width: 6),
                const Icon(
                  LucideIcons.chevronDown,
                  size: 16,
                  color: AppColors.textMuted,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
