import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/game_config.dart';
import 'package:ironrise/state/duel_state.dart';

void main() {
  test('с ботом — снова через 5 часов', () {
    final fought = DateTime(2026, 11, 13, 10);
    final day = DuelDay(
      day: '2026-11-13',
      results: const {'b1': false},
      winsByDay: const {},
      lastFightAt: {'b1': fought},
      fights: const {'b1': 1},
    );
    expect(
      day.nextFightAt('b1', DateTime(2026, 11, 13, 12)),
      fought.add(GameConfig.duelCooldown),
    );
    expect(day.nextFightAt('b1', DateTime(2026, 11, 13, 15, 1)), isNull);
    expect(day.nextFightAt('b2', DateTime(2026, 11, 13, 12)), isNull);
  });
}
