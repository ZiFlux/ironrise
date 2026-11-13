import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_look.dart';
import '../game/calendar.dart';
import '../game/duel.dart';
import '../game/game_config.dart';
import 'account_state.dart';
import 'hero.dart';
import 'providers.dart';
import 'server_game.dart';

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
    this.lastFightAt = const {},
    this.fights = const {},
  });

  final String day;

  /// Исход последнего боя с каждым ботом сегодня.
  final Map<String, bool> results;

  /// Когда был последний бой с ботом — для перезарядки.
  final Map<String, DateTime> lastFightAt;

  /// Сколько боёв с ботом сегодня.
  final Map<String, int> fights;

  /// Когда снова можно драться; null — уже можно.
  DateTime? nextFightAt(String botId, DateTime now) {
    final last = lastFightAt[botId];
    if (last == null) return null;
    final next = last.add(GameConfig.duelCooldown);
    return next.isAfter(now) ? next : null;
  }

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
        final same = j['day'] == today;
        return DuelDay(
          day: today,
          results: results,
          winsByDay: wins,
          lastFightAt: same
              ? {
                  for (final e
                      in (j['lastFightAt'] as Map? ?? const {}).entries)
                    e.key as String: DateTime.parse(e.value as String),
                }
              : const {},
          fights: same
              ? Map<String, int>.from(j['fights'] ?? const {})
              : const {},
        );
      } catch (_) {}
    }
    return DuelDay(day: today, results: const {}, winsByDay: const {});
  }

  /// Результаты за сегодня (сбрасываются после полуночи, даже если приложение открыто).
  Map<String, bool> get today =>
      state.day == dayKey(DateTime.now()) ? state.results : const {};

  /// Бой через сервер (игрок в аккаунте): исход, лог и монеты считает сервер.
  Future<DuelResult> fightOnServer(Fighter bot) async {
    final j = await ref.read(apiProvider).post('/v1/duels/bots/${bot.id}', {});
    final result = duelFromJson(j);
    await ref
        .read(heroProvider.notifier)
        .applyServer(Map<String, dynamic>.from(j['hero'] as Map));
    ref.read(currentDuelProvider.notifier).show(result);
    ref.invalidate(serverBotsProvider);
    ref.invalidate(serverLeagueProvider);
    return result;
  }

  /// Бой с другом: сервер дерётся со снимком его героя, друг может быть офлайн.
  Future<DuelResult> fightFriendOnServer(Fighter friend) async {
    final j = await ref
        .read(apiProvider)
        .post('/v1/duels/users/${friend.id}', {});
    final result = duelFromJson(j);
    await ref
        .read(heroProvider.notifier)
        .applyServer(Map<String, dynamic>.from(j['hero'] as Map));
    ref.read(currentDuelProvider.notifier).show(result);
    ref.invalidate(serverFriendsProvider);
    ref.invalidate(serverLeagueProvider);
    ref.invalidate(serverFriendsLeagueProvider);
    return result;
  }

  /// Провести бой и сразу начислить награду, чтобы выход из анимации ничего не менял.
  /// Бой с ботом без аккаунта: с тем же ботом — снова через 5 часов,
  /// повторный за сутки — половина монет (как на сервере).
  Future<DuelResult?> fight(Fighter bot) async {
    final hero = ref.read(heroProvider);
    if (hero == null) return null;
    final now = DateTime.now();
    final sameDay = state.day == dayKey(now);
    if (sameDay && state.nextFightAt(bot.id, now) != null) return null;
    final repeat = sameDay && (state.fights[bot.id] ?? 0) > 0;

    final simulated = DuelSimulator.fight(
      playerFighter(hero),
      bot,
      now.microsecondsSinceEpoch,
    );
    final base = simulated.attackerWon
        ? GameConfig.duelWinCoins
        : GameConfig.duelLossCoins;
    final coins = repeat
        ? (base * GameConfig.duelRepeatCoinFactor).round()
        : base;
    final result = simulated.withCoins(coins, repeat: repeat);
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
      lastFightAt: {if (sameDay) ...state.lastFightAt, bot.id: now},
      fights: {
        if (sameDay) ...state.fights,
        bot.id: (sameDay ? state.fights[bot.id] ?? 0 : 0) + 1,
      },
    );
    await ref
        .read(prefsProvider)
        .setString(
          _duelsKey,
          jsonEncode({
            'day': day,
            'results': state.results,
            'winsByDay': wins,
            'lastFightAt': {
              for (final e in state.lastFightAt.entries)
                e.key: e.value.toIso8601String(),
            },
            'fights': state.fights,
          }),
        );
    if (coins > 0) await ref.read(heroProvider.notifier).addCoins(coins);
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
