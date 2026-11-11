import 'dart:math';

import 'calendar.dart';
import 'duel.dart';
import 'game_config.dart';

class LeagueEntry {
  const LeagueEntry({
    required this.name,
    required this.points,
    this.isPlayer = false,
  });

  final String name;
  final int points;
  final bool isPlayer;
}

/// Недельная лига (экран 10), пока без сервера: игрок и боты.
/// Очки за активность, а не за силу: так новичок может обогнать «старичков».
class WeeklyLeague {
  const WeeklyLeague._();

  static const int botsInLeague = 7;

  static int playerPoints({required int trainedDays, required int duelWins}) =>
      trainedDays * GameConfig.leagueWorkoutPoints +
      duelWins * GameConfig.leagueWinPoints;

  /// Таблица на [today], по убыванию очков.
  static List<LeagueEntry> standings({
    required DateTime today,
    required String playerName,
    required int playerPoints,
  }) {
    final monday = mondayOf(today);
    final weekSeed = monday.year * 10000 + monday.month * 100 + monday.day;
    final daysPassed = today.weekday; // Пн = 1 … Вс = 7
    final names = [...DuelBots.names]..shuffle(Random(weekSeed));
    final entries = [
      LeagueEntry(name: playerName, points: playerPoints, isPlayer: true),
      for (var i = 0; i < botsInLeague; i++)
        LeagueEntry(
          name: names[i],
          points: _botPoints(weekSeed, i, daysPassed),
        ),
    ];
    // При равенстве очков игрок выше: он их заработал по-настоящему.
    entries.sort(
      (a, b) => b.points != a.points
          ? b.points.compareTo(a.points)
          : (a.isPlayer ? -1 : (b.isPlayer ? 1 : 0)),
    );
    return entries;
  }

  /// Очки бота за первые [days] дней недели. Растут день за днём и не убывают.
  static int _botPoints(int weekSeed, int bot, int days) {
    final rng = Random(weekSeed * 31 + bot);
    final activity = 0.25 + rng.nextDouble() * 0.55; // 2–5 тренировок в неделю
    var points = 0;
    for (var d = 0; d < 7; d++) {
      final trained = rng.nextDouble() < activity;
      final wins = rng.nextInt(3);
      if (d < days) {
        if (trained) points += GameConfig.leagueWorkoutPoints;
        points += wins * GameConfig.leagueWinPoints;
      }
    }
    return points;
  }
}
