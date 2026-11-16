import 'dart:ui';

import 'dart:math';

import 'calendar.dart';
import 'duel_flavor.dart';
import 'game_config.dart';

class LeagueEntry {
  const LeagueEntry({
    required this.name,
    required this.points,
    this.isPlayer = false,
    this.isBot = false,
    this.friendId,
  });

  final String name;
  final int points;
  final bool isPlayer;

  /// Бот лиги: по нажатию — облако «бот», а не профиль (п. 127).
  final bool isBot;

  /// Друг: по нажатию — его профиль. Чужих id сервер не отдаёт.
  final String? friendId;

  factory LeagueEntry.fromJson(Map<String, dynamic> e) => LeagueEntry(
    name: e['name'] as String,
    points: (e['points'] as num).toInt(),
    isPlayer: e['isPlayer'] == true,
    isBot: e['isBot'] == true,
    friendId: e['friendId'] as String?,
  );
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
    final nameRng = Random(weekSeed);
    final names = botNames([
      for (var i = 0; i < botsInLeague; i++) nameRng.nextBool(),
    ], nameRng);
    final entries = [
      LeagueEntry(name: playerName, points: playerPoints, isPlayer: true),
      for (var i = 0; i < botsInLeague; i++)
        LeagueEntry(
          name: names[i],
          points: _botPoints(weekSeed, i, daysPassed),
          isBot: true,
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

/// Уровни лиги (сервер: src/game/league.ts). Цвет — цвет металла медали.
enum LeagueTier {
  bronze('Бронзовая лига', Color(0xFFC08457)),
  silver('Серебряная лига', Color(0xFFB8BEC6)),
  gold('Золотая лига', Color(0xFFD9B25A)),
  platinum('Платиновая лига', Color(0xFF7FD4D4)),
  diamond('Алмазная лига', Color(0xFF6FA8FF)),
  champion('Чемпионская лига', Color(0xFFE45CFF));

  const LeagueTier(this.title, this.color);

  final String title;
  final Color color;

  static LeagueTier of(int index) => values[index.clamp(0, values.length - 1)];
}
