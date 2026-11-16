import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../avatar/avatar_look.dart';
import '../game/body_part.dart';
import '../game/duel.dart';
import '../game/league.dart';
import 'account_state.dart';
import '../game/aura.dart';

/// Данные игры с сервера — когда игрок вошёл в аккаунт. Без аккаунта
/// экраны работают на локальной логике, как раньше.

Map<BodyPart, int> _levels(Map<String, dynamic> j) => {
  for (final p in BodyPart.values) p: (j[p.name] as num?)?.toInt() ?? 1,
};

AvatarLook? _look(Object? appearance) {
  if (appearance is! Map) return null;
  try {
    return AvatarLook.fromJson(Map<String, dynamic>.from(appearance));
  } catch (_) {
    return null; // неполный образ — покажем стартовый
  }
}

Fighter fighterFromJson(Map<String, dynamic> j) => Fighter(
  id: j['id'] as String,
  name: j['name'] as String,
  levels: _levels(Map<String, dynamic>.from(j['levels'] as Map)),
  streakDays: (j['streakDays'] as num).toInt(),
  isFemale: j['isFemale'] == true,
  look: _look(j['appearance']),
);

DuelResult duelFromJson(Map<String, dynamic> j) => DuelResult(
  attacker: fighterFromJson(Map<String, dynamic>.from(j['attacker'] as Map)),
  defender: fighterFromJson(Map<String, dynamic>.from(j['defender'] as Map)),
  attackerWon: j['attackerWon'] as bool,
  coins: (j['coins'] as num?)?.toInt(),
  repeat: j['repeat'] == true,
  hits: [
    for (final h in j['log'] as List)
      DuelHit(
        byAttacker: h['byAttacker'] as bool,
        part: BodyPart.values.byName(h['part'] as String),
        kind: HitKind.values.byName(h['kind'] as String),
        damage: (h['damage'] as num).toInt(),
        targetHpAfter: (h['targetHpAfter'] as num).toInt(),
        eventId: (h['event'] as Map?)?['id'] as String?,
        heal: ((h['event'] as Map?)?['heal'] as num?)?.toInt() ?? 0,
        selfHpAfter: ((h['event'] as Map?)?['selfHpAfter'] as num?)?.toInt(),
        boosted: h['boosted'] == true,
        auras: [
          for (final m in (h['auras'] as List? ?? const []))
            if (AuraKind.values.asNameMap()[m['kind']] case final kind?)
              AuraMark(
                attacker: m['owner'] == 'attacker',
                kind: kind,
                start: m['start'] == true,
              ),
        ],
      ),
  ],
);

typedef ServerBots = ({
  List<Fighter> bots,
  Map<String, bool> results,

  /// Когда снова можно драться с ботом (если перезарядка идёт).
  Map<String, DateTime> nextFightAt,

  /// Сколько боёв с ботом сегодня.
  Map<String, int> fights,
});

final serverBotsProvider = FutureProvider.autoDispose<ServerBots>((ref) async {
  final j = await ref.read(apiProvider).get('/v1/duels/bots');
  return (
    bots: [
      for (final b in j['bots'] as List)
        fighterFromJson(Map<String, dynamic>.from(b as Map)),
    ],
    results: Map<String, bool>.from(j['results'] as Map),
    nextFightAt: {
      for (final e in (j['nextFightAt'] as Map? ?? const {}).entries)
        e.key as String: DateTime.parse(e.value as String).toLocal(),
    },
    fights: {
      for (final e in (j['fights'] as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
  );
});

/// Итог прошлой недели: место и куда сдвинулась лига.
typedef LeagueWeekResult = ({
  int rank,
  String outcome,
  int tierBefore,
  int tierAfter,
});

typedef ServerLeague = ({
  List<LeagueEntry> entries,
  int trainedDays,
  int wins,
  LeagueTier tier,
  int promoteTop,
  int minDaysToPromote,
  int demoteBottom,
  LeagueWeekResult? lastWeek,
});

/// Чужая лига этой недели — только посмотреть (п. 108): 0 — бронзовая … 5 — чемпионская.
final serverLeagueTierProvider = FutureProvider.autoDispose
    .family<List<LeagueEntry>, int>((ref, tier) async {
      final j = await ref.read(apiProvider).get('/v1/league/tier/$tier');
      return [
        for (final e in j['entries'] as List)
          LeagueEntry(
            name: e['name'] as String,
            points: (e['points'] as num).toInt(),
            isPlayer: e['isPlayer'] == true,
          ),
      ];
    });

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
    tier: LeagueTier.of((j['tier'] as num?)?.toInt() ?? 0),
    promoteTop: (j['promoteTop'] as num?)?.toInt() ?? 0,
    minDaysToPromote: (j['minDaysToPromote'] as num?)?.toInt() ?? 1,
    demoteBottom: (j['demoteBottom'] as num?)?.toInt() ?? 0,
    lastWeek: switch (j['lastWeek']) {
      final Map<String, dynamic> w => (
        rank: (w['rank'] as num).toInt(),
        outcome: w['outcome'] as String,
        tierBefore: (w['tierBefore'] as num).toInt(),
        tierAfter: (w['tierAfter'] as num).toInt(),
      ),
      _ => null,
    },
  );
});

typedef PlayerRef = ({String userId, String nickname});

typedef ServerFriends = ({
  List<Fighter> friends,
  List<PlayerRef> incoming,
  List<PlayerRef> outgoing,
  Map<String, bool> results,
  int fightsLeft,
});

List<PlayerRef> _refs(Object? list) => [
  for (final r in list as List)
    (userId: r['userId'] as String, nickname: r['nickname'] as String),
];

final serverFriendsProvider = FutureProvider.autoDispose<ServerFriends>((
  ref,
) async {
  final j = await ref.read(apiProvider).get('/v1/friends');
  return (
    friends: [
      for (final f in j['friends'] as List)
        fighterFromJson(Map<String, dynamic>.from(f as Map)),
    ],
    incoming: _refs(j['incoming']),
    outgoing: _refs(j['outgoing']),
    results: Map<String, bool>.from(j['results'] as Map),
    fightsLeft: (j['fightsLeft'] as num).toInt(),
  );
});

final serverFriendsLeagueProvider =
    FutureProvider.autoDispose<List<LeagueEntry>>((ref) async {
      final j = await ref.read(apiProvider).get('/v1/league/friends');
      return [
        for (final e in j['entries'] as List)
          LeagueEntry(
            name: e['name'] as String,
            points: (e['points'] as num).toInt(),
            isPlayer: e['isPlayer'] == true,
          ),
      ];
    });

typedef AttackOnMe = ({
  String attacker,
  String? attackerId,
  bool attackerWon,
  DateTime at,
});

final serverAttacksProvider = FutureProvider.autoDispose<List<AttackOnMe>>((
  ref,
) async {
  final list = await ref.read(apiProvider).getList('/v1/duels/incoming');
  return [
    for (final a in list)
      (
        attacker: a['attacker'] as String,
        attackerId: a['attackerId'] as String?,
        attackerWon: a['attackerWon'] as bool,
        at: DateTime.parse(a['at'] as String).toLocal(),
      ),
  ];
});

class AppNotification {
  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.screen,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String screen;
  final bool read;
  final DateTime createdAt;

  /// Куда вести по нажатию.
  String get path => switch (screen) {
    'friends' => '/duels/friends',
    'duels' => '/duels',
    'tip' => '/tip',
    _ => '/',
  };
}

typedef NotificationFeed = ({List<AppNotification> items, int unread});

final notificationsProvider = FutureProvider.autoDispose<NotificationFeed>((
  ref,
) async {
  final j = await ref.read(apiProvider).get('/v1/notifications');
  return (
    unread: (j['unread'] as num).toInt(),
    items: [
      for (final n in j['items'] as List)
        AppNotification(
          id: n['id'] as String,
          type: n['type'] as String,
          title: n['title'] as String,
          body: n['body'] as String,
          screen: n['screen'] as String,
          read: n['read'] as bool,
          createdAt: DateTime.parse(n['createdAt'] as String).toLocal(),
        ),
    ],
  );
});
