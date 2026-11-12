import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/duel.dart';
import 'package:ironrise/game/duel_flavor.dart';
import 'package:ironrise/state/server_game.dart';

Fighter fighter(String id, int level, {bool female = false}) => Fighter(
  id: id,
  name: id,
  levels: {for (final p in BodyPart.values) p: level},
  streakDays: 0,
  isFemale: female,
);

void main() {
  test('каталог событий совпадает с серверным (id и виды)', () {
    // server/src/game/duel-flavor.ts — DUEL_EVENTS.
    const server = {
      'creatine': 'heal',
      'protein_shake': 'heal',
      'buckwheat': 'heal',
      'eight_hours_sleep': 'heal',
      'pre_workout': 'boost',
      'pump': 'boost',
      'gym_playlist': 'boost',
      'coach_shouts': 'boost',
      'mirror_selfie': 'skip',
      'bench_hunt': 'skip',
      'forgot_towel': 'skip',
      'protein_debate': 'skip',
    };
    expect({for (final e in duelEvents) e.id: e.kind.name}, server);
  });

  test('события в офлайн-бою: ~12% ходов, лечение не выше максимума, пропуск без урона', () {
    var turns = 0, events = 0;
    for (var s = 0; s < 2000; s++) {
      final r = DuelSimulator.fight(fighter('a', 7), fighter('b', 7), s);
      for (var i = 0; i < r.hits.length; i++) {
        final h = r.hits[i];
        turns++;
        if (h.eventId != null) events++;
        if (h.kind == HitKind.skip) expect(h.damage, 0);
        final hp = r.hpAfter(i + 1);
        expect(hp.attacker, inInclusiveRange(0, r.attacker.power));
        expect(hp.defender, inInclusiveRange(0, r.defender.power));
      }
    }
    expect(events / turns, inInclusiveRange(0.1, 0.14));
  });

  test('фразы событий согласуются с родом', () {
    final creatine = duelEventById('creatine')!;
    expect(creatine.phrase('Стас', female: false), 'Стас принял креатин');
    expect(creatine.phrase('Света', female: true), 'Света приняла креатин');
  });

  test('боты дня: разные имена, род, одежда из магазина', () {
    final bots = DuelBots.forDay(fighter('me', 5), DateTime(2026, 11, 12));
    expect(bots.map((b) => b.name).toSet().length, 4);
    for (final b in bots) {
      expect(b.look, isNotNull);
      expect(b.look!.sex, b.isFemale ? AvatarSex.female : AvatarSex.male);
      if (b.isFemale) expect(b.name, isNot(matches(RegExp('ый |ой '))));
    }
    expect(botNames(List.filled(40, true), Random(3)).toSet().length, 40);
  });

  test('ответ сервера с событием разбирается', () {
    final levels = {for (final p in BodyPart.values) p.name: 4};
    final r = duelFromJson({
      'attacker': {'id': 'me', 'name': 'me', 'levels': levels, 'streakDays': 0},
      'defender': {
        'id': 'b',
        'name': 'Протеиновый Стас',
        'levels': levels,
        'streakDays': 0,
      },
      'attackerWon': false,
      'log': [
        {
          'byAttacker': false,
          'part': 'legs',
          'kind': 'crit',
          'damage': 12,
          'targetHpAfter': 30,
          'event': {'id': 'creatine', 'heal': 4, 'selfHpAfter': 42},
          'boosted': false,
        },
        {
          'byAttacker': true,
          'part': 'chest',
          'kind': 'skip',
          'damage': 0,
          'targetHpAfter': 42,
          'event': {'id': 'mirror_selfie'},
        },
      ],
    });
    expect(r.hits.first.eventId, 'creatine');
    expect(r.hits.first.heal, 4);
    expect(r.hits.last.kind, HitKind.skip);
    expect(r.hpAfter(1).defender, 42);
  });
}
