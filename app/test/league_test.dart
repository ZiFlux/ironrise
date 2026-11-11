import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/league.dart';

void main() {
  List<int> botPoints(DateTime day) => [
    for (final e in WeeklyLeague.standings(
      today: day,
      playerName: 'me',
      playerPoints: 0,
    ))
      if (!e.isPlayer) e.points,
  ];

  test('очки за тренировки и победы', () {
    expect(WeeklyLeague.playerPoints(trainedDays: 3, duelWins: 4), 42);
  });

  test('таблица отсортирована, игрок в ней один', () {
    final t = WeeklyLeague.standings(
      today: DateTime(2026, 11, 12),
      playerName: 'me',
      playerPoints: 25,
    );
    expect(t.length, WeeklyLeague.botsInLeague + 1);
    expect(t.where((e) => e.isPlayer).length, 1);
    for (var i = 1; i < t.length; i++) {
      expect(t[i - 1].points, greaterThanOrEqualTo(t[i].points));
    }
  });

  test('очки ботов за неделю не убывают, с понедельника неделя новая', () {
    // 9–15 ноября 2026: понедельник — воскресенье.
    final monday = botPoints(DateTime(2026, 11, 9)).fold(0, (a, b) => a + b);
    final sunday = botPoints(DateTime(2026, 11, 15)).fold(0, (a, b) => a + b);
    expect(sunday, greaterThan(monday));
    expect(
      botPoints(DateTime(2026, 11, 12)),
      botPoints(DateTime(2026, 11, 12, 23)),
    );
  });

  test('при равенстве очков игрок выше бота', () {
    final bots = botPoints(DateTime(2026, 11, 15));
    final t = WeeklyLeague.standings(
      today: DateTime(2026, 11, 15),
      playerName: 'me',
      playerPoints: bots.first,
    );
    expect(
      t.indexWhere((e) => e.isPlayer),
      t.indexWhere((e) => e.points == bots.first),
    );
  });
}
