import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/duel.dart';
import 'package:ironrise/state/server_game.dart';

Map<String, dynamic> fighter(String id, int level) => {
  'id': id,
  'name': id,
  'isFemale': false,
  'streakDays': 3,
  'levels': {for (final p in BodyPart.values) p.name: level},
};

void main() {
  test('ответ сервера о бое разбирается в DuelResult', () {
    final r = duelFromJson({
      'attacker': fighter('me', 5),
      'defender': fighter('bot_20261111_0', 4),
      'attackerWon': true,
      'log': [
        {'byAttacker': true, 'part': 'legs', 'kind': 'crit', 'damage': 9, 'targetHpAfter': 41},
        {'byAttacker': false, 'part': 'chest', 'kind': 'miss', 'damage': 0, 'targetHpAfter': 63},
      ],
    });
    expect(r.attackerWon, isTrue);
    expect(r.hits.first.kind, HitKind.crit);
    expect(r.hits.first.part, BodyPart.legs);
    expect(r.defenderHpLeft, 41);
    // Сила считается той же формулой, что и на сервере: (10·30 + 2·3) · 1,05 = 321
    expect(r.attacker.power, 321);
  });
}
