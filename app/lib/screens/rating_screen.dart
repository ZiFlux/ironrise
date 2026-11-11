import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/calendar.dart';
import '../game/game_config.dart';
import '../game/league.dart';
import '../state/duel_state.dart';
import '../state/providers.dart';
import '../theme.dart';

/// Рейтинг (экран 10): недельная лига. Пока с ботами, друзья и вуз — с сервером.
class RatingScreen extends ConsumerWidget {
  const RatingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hero = ref.watch(heroProvider);
    if (hero == null) return const SizedBox.shrink();
    final duels = ref.watch(duelProvider);
    final now = DateTime.now();
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
    final daysLeft = 7 - now.weekday;

    return Scaffold(
      appBar: AppBar(title: const Text('Рейтинг')),
      body: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                          const Text(
                            'Лига недели',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const Spacer(),
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
                        'победа в дуэли +${GameConfig.leagueWinPoints}. '
                        'У тебя: $trainedDays трен., $wins побед',
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
              for (final (i, entry) in table.indexed)
                Expanded(
                  child: _Row(place: i + 1, entry: entry),
                ),
              const SizedBox(height: 8),
              const Text(
                'Таблица друзей и «Мой вуз» появятся вместе с сервером',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.place, required this.entry});

  final int place;
  final LeagueEntry entry;

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
          Text('${entry.points}', style: figureStyle(size: 15)),
        ],
      ),
    );
  }
}
