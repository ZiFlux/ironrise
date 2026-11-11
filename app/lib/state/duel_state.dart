import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_look.dart';
import '../game/calendar.dart';
import '../game/duel.dart';
import '../game/game_config.dart';
import 'hero.dart';
import 'providers.dart';

const _duelsKey = 'duels_v1';

/// Сколько дней хранить историю побед (для недельной лиги хватает двух недель).
const _historyDays = 14;

/// Дуэли: итоги за сегодня (id бота → победа; каждого бота — раз в день)
/// и число побед по дням для недельной лиги.
class DuelDay {
  const DuelDay({
    required this.day,
    required this.results,
    required this.winsByDay,
  });

  final String day;
  final Map<String, bool> results;
  final Map<String, int> winsByDay;

  /// Победы за неделю, в которую входит [today].
  int winsInWeek(DateTime today) {
    final monday = mondayOf(today);
    var sum = 0;
    for (var i = 0; i < 7; i++) {
      sum +=
          winsByDay[dayKey(
            DateTime(monday.year, monday.month, monday.day + i),
          )] ??
          0;
    }
    return sum;
  }
}

Fighter playerFighter(HeroProfile hero) => Fighter(
  id: 'me',
  name: hero.nickname,
  levels: hero.levels,
  streakDays: hero.currentStreak(DateTime.now()),
  isFemale: hero.look.sex == AvatarSex.female,
);

class DuelNotifier extends Notifier<DuelDay> {
  @override
  DuelDay build() {
    final raw = ref.read(prefsProvider).getString(_duelsKey);
    final today = dayKey(DateTime.now());
    if (raw != null) {
      try {
        final j = jsonDecode(raw) as Map<String, dynamic>;
        final wins = Map<String, int>.from(j['winsByDay'] ?? const {});
        final results = j['day'] == today
            ? Map<String, bool>.from(j['results'])
            : const <String, bool>{};
        return DuelDay(day: today, results: results, winsByDay: wins);
      } catch (_) {}
    }
    return DuelDay(day: today, results: const {}, winsByDay: const {});
  }

  /// Результаты за сегодня (сбрасываются после полуночи, даже если приложение открыто).
  Map<String, bool> get today =>
      state.day == dayKey(DateTime.now()) ? state.results : const {};

  /// Провести бой и сразу начислить награду, чтобы выход из анимации ничего не менял.
  Future<DuelResult?> fight(Fighter bot) async {
    final hero = ref.read(heroProvider);
    if (hero == null || today.containsKey(bot.id)) return null;

    final now = DateTime.now();
    final result = DuelSimulator.fight(
      playerFighter(hero),
      bot,
      now.microsecondsSinceEpoch,
    );
    final day = dayKey(now);
    final oldest = dayKey(
      DateTime(now.year, now.month, now.day - _historyDays),
    );
    final wins = {
      for (final e in state.winsByDay.entries)
        if (e.key.compareTo(oldest) > 0) e.key: e.value,
    };
    if (result.attackerWon) wins[day] = (wins[day] ?? 0) + 1;

    state = DuelDay(
      day: day,
      results: {...today, bot.id: result.attackerWon},
      winsByDay: wins,
    );
    await ref
        .read(prefsProvider)
        .setString(
          _duelsKey,
          jsonEncode({'day': day, 'results': state.results, 'winsByDay': wins}),
        );
    await ref
        .read(heroProvider.notifier)
        .addCoins(
          result.attackerWon
              ? GameConfig.duelWinCoins
              : GameConfig.duelLossCoins,
        );
    ref.read(currentDuelProvider.notifier).show(result);
    return result;
  }
}

final duelProvider = NotifierProvider<DuelNotifier, DuelDay>(DuelNotifier.new);

/// Бой, который показывает экран дуэли.
class CurrentDuelNotifier extends Notifier<DuelResult?> {
  @override
  DuelResult? build() => null;

  void show(DuelResult result) => state = result;
}

final currentDuelProvider = NotifierProvider<CurrentDuelNotifier, DuelResult?>(
  CurrentDuelNotifier.new,
);
