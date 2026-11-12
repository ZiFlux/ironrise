import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/calendar.dart';
import '../game/game_config.dart';
import '../game/league.dart';
import '../state/account_state.dart';
import '../state/duel_state.dart';
import '../state/server_game.dart';
import '../state/providers.dart';
import '../theme.dart';
import '../widgets/fit_screen.dart';
import '../widgets/motion.dart';

/// Рейтинг (экран 10): недельная лига. Пока с ботами, друзья и вуз — с сервером.
class RatingScreen extends ConsumerWidget {
  const RatingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final now = DateTime.now();

    if (ref.watch(accountProvider).signedIn) return const _ServerRating();

    final duels = ref.watch(duelProvider);
    final monday = mondayOf(now);
    final trainedDays = [
      for (var i = 0; i < 7; i++)
        DateTime(monday.year, monday.month, monday.day + i),
    ].where((d) => hero.activeDays.contains(dayKey(d))).length;
    final wins = duels.winsInWeek(now);
    final table = WeeklyLeague.standings(
      today: now,
      playerName: hero.nickname,
      playerPoints: WeeklyLeague.playerPoints(
        trainedDays: trainedDays,
        duelWins: wins,
      ),
    );
    return _LeagueView(
      table: table,
      trainedDays: trainedDays,
      wins: wins,
      footer: 'Бронзовая, серебряная и золотая лиги — после входа в аккаунт',
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
      appBar: AppBar(title: const Text('Рейтинг')),
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
                Card(
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
                          'Тренировка +${GameConfig.leagueWorkoutPoints} · '
                          'победа в дуэли +${GameConfig.leagueWinPoints}'
                          '${trainedDays == null ? '' : '. У тебя: $trainedDays трен., $wins побед'}'
                          '${tier == null ? '' : '\nПервые $promoteTop — в лигу выше, последние $demoteBottom и неделя без тренировок — ниже'}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                if (table.length <= _fitRows)
                  for (final (i, entry) in table.indexed)
                    FlexibleMin(
                      minHeight: MediaQuery.textScalerOf(context).scale(36),
                      child: FadeSlideIn(
                        index: i,
                        child: _Row(
                          place: i + 1,
                          entry: entry,
                          zone: _zoneOf(i + 1),
                        ),
                      ),
                    )
                else
                  Expanded(
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

class _Row extends StatelessWidget {
  const _Row({
    required this.place,
    required this.entry,
    this.zone = _Zone.none,
  });

  final int place;
  final LeagueEntry entry;
  final _Zone zone;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final me = entry.isPlayer;
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: me ? accent.withValues(alpha: 0.12) : AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: me ? accent.withValues(alpha: 0.5) : AppColors.hairline,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 28,
            child: Text(
              '$place',
              style: figureStyle(
                size: 15,
                color: place <= 3 ? accent : AppColors.textMuted,
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
                fontWeight: me ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (zone != _Zone.none) ...[
            Icon(
              zone == _Zone.up
                  ? LucideIcons.chevronsUp
                  : LucideIcons.chevronsDown,
              size: 16,
              color: zone == _Zone.up ? accent : AppColors.textMuted,
            ),
            const SizedBox(width: 8),
          ],
          Text('${entry.points}', style: figureStyle(size: 15)),
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
      appBar: AppBar(title: const Text('Рейтинг')),
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
