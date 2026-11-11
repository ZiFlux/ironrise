import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/duel.dart';

Fighter fighter(String id, int level, {int streak = 0}) => Fighter(
      id: id,
      name: id,
      levels: {for (final p in BodyPart.values) p: level},
      streakDays: streak,
    );

double winRate(Fighter a, Fighter b, {int n = 4000}) {
  var wins = 0;
  for (var s = 0; s < n; s++) {
    if (DuelSimulator.fight(a, b, s).attackerWon) wins++;
  }
  return wins / n;
}

void main() {
  test('равные силы — около 50% побед', () {
    expect(winRate(fighter('a', 10), fighter('b', 10)), closeTo(0.5, 0.05));
  });

  test('перевес 20% — около 85% побед (ТЗ 4.5)', () {
    final a = fighter('a', 12);
    final b = fighter('b', 10);
    expect(a.power / b.power, closeTo(1.2, 0.01));
    expect(winRate(a, b), inInclusiveRange(0.78, 0.92));
  });

  test('бой детерминирован по seed и длится 6–10 ходов', () {
    final a = fighter('a', 5);
    final b = fighter('b', 6);
    final r1 = DuelSimulator.fight(a, b, 42);
    final r2 = DuelSimulator.fight(a, b, 42);
    expect(r1.attackerWon, r2.attackerWon);
    expect(r1.hits.map((h) => h.damage), r2.hits.map((h) => h.damage));
    expect(r1.hits.length ~/ 2, inInclusiveRange(6, 10));
  });

  test('боты дня стабильны и упорядочены по силе', () {
    final player = fighter('me', 5, streak: 4);
    final day = DateTime(2026, 11, 11);
    final bots = DuelBots.forDay(player, day);
    expect(bots.length, 4);
    expect(bots.map((b) => b.id), DuelBots.forDay(player, day).map((b) => b.id));
    expect(bots.first.power, lessThan(bots.last.power));
  });

  test('совет при отстающей части называет её', () {
    final p = Fighter(
      id: 'me',
      name: 'me',
      levels: {for (final b in BodyPart.values) b: 6}..[BodyPart.legs] = 2,
      streakDays: 0,
    );
    expect(DuelAdvice.forPlayer(p), contains('ноги'));
  });
}
