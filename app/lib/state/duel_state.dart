import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_look.dart';
import '../game/calendar.dart';
import '../game/duel.dart';
import '../game/game_config.dart';
import 'hero.dart';
import 'providers.dart';

const _duelsKey = 'duels_v1';

/// Итоги дуэлей за день: id бота → победа. Каждого бота можно вызвать раз в день.
class DuelDay {
  const DuelDay({required this.day, required this.results});

  final String day;
  final Map<String, bool> results;
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
        if (j['day'] == today) {
          return DuelDay(day: today, results: Map<String, bool>.from(j['results']));
        }
      } catch (_) {}
    }
    return DuelDay(day: today, results: const {});
  }

  /// Результаты за сегодня (сбрасываются после полуночи, даже если приложение открыто).
  Map<String, bool> get today => state.day == dayKey(DateTime.now()) ? state.results : const {};

  /// Провести бой и сразу начислить награду, чтобы выход из анимации ничего не менял.
  Future<DuelResult?> fight(Fighter bot) async {
    final hero = ref.read(heroProvider);
    if (hero == null || today.containsKey(bot.id)) return null;

    final result = DuelSimulator.fight(
      playerFighter(hero),
      bot,
      DateTime.now().microsecondsSinceEpoch,
    );
    final day = dayKey(DateTime.now());
    state = DuelDay(day: day, results: {...today, bot.id: result.attackerWon});
    await ref.read(prefsProvider).setString(
          _duelsKey,
          jsonEncode({'day': day, 'results': state.results}),
        );
    await ref.read(heroProvider.notifier).addCoins(
          result.attackerWon ? GameConfig.duelWinCoins : GameConfig.duelLossCoins,
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

final currentDuelProvider =
    NotifierProvider<CurrentDuelNotifier, DuelResult?>(CurrentDuelNotifier.new);
