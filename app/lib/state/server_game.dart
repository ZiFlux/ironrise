import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/body_part.dart';
import '../game/duel.dart';
import '../game/league.dart';
import 'account_state.dart';

/// Данные игры с сервера — когда игрок вошёл в аккаунт. Без аккаунта
/// экраны работают на локальной логике, как раньше.

Map<BodyPart, int> _levels(Map<String, dynamic> j) => {
  for (final p in BodyPart.values) p: (j[p.name] as num?)?.toInt() ?? 1,
};

Fighter fighterFromJson(Map<String, dynamic> j) => Fighter(
  id: j['id'] as String,
  name: j['name'] as String,
  levels: _levels(Map<String, dynamic>.from(j['levels'] as Map)),
  streakDays: (j['streakDays'] as num).toInt(),
  isFemale: j['isFemale'] == true,
);

DuelResult duelFromJson(Map<String, dynamic> j) => DuelResult(
  attacker: fighterFromJson(Map<String, dynamic>.from(j['attacker'] as Map)),
  defender: fighterFromJson(Map<String, dynamic>.from(j['defender'] as Map)),
  attackerWon: j['attackerWon'] as bool,
  hits: [
    for (final h in j['log'] as List)
      DuelHit(
        byAttacker: h['byAttacker'] as bool,
        part: BodyPart.values.byName(h['part'] as String),
        kind: HitKind.values.byName(h['kind'] as String),
        damage: (h['damage'] as num).toInt(),
        targetHpAfter: (h['targetHpAfter'] as num).toInt(),
      ),
  ],
);

typedef ServerBots = ({List<Fighter> bots, Map<String, bool> results});

final serverBotsProvider = FutureProvider.autoDispose<ServerBots>((ref) async {
  final j = await ref.read(apiProvider).get('/v1/duels/bots');
  return (
    bots: [
      for (final b in j['bots'] as List)
        fighterFromJson(Map<String, dynamic>.from(b as Map)),
    ],
    results: Map<String, bool>.from(j['results'] as Map),
  );
});

typedef ServerLeague = ({List<LeagueEntry> entries, int trainedDays, int wins});

final serverLeagueProvider = FutureProvider.autoDispose<ServerLeague>((
  ref,
) async {
  final j = await ref.read(apiProvider).get('/v1/league');
  return (
    entries: [
      for (final e in j['entries'] as List)
        LeagueEntry(
          name: e['name'] as String,
          points: (e['points'] as num).toInt(),
          isPlayer: e['isPlayer'] == true,
        ),
    ],
    trainedDays: (j['trainedDays'] as num).toInt(),
    wins: (j['wins'] as num).toInt(),
  );
});
