import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_cache.dart';

/// Награда уровня сезона (server/src/game/season.ts).
class SeasonReward {
  const SeasonReward({
    required this.coins,
    required this.items,
    required this.xpBoosters,
    required this.coinBoosters,
  });

  factory SeasonReward.fromJson(Map<String, dynamic> j) {
    final b = (j['boosters'] as Map?) ?? const {};
    return SeasonReward(
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      items: [for (final i in (j['items'] as List? ?? const [])) i as String],
      xpBoosters: (b['xp'] as num?)?.toInt() ?? 0,
      coinBoosters: (b['coins'] as num?)?.toInt() ?? 0,
    );
  }

  final int coins;
  final List<String> items;
  final int xpBoosters;
  final int coinBoosters;
}

class SeasonTier {
  const SeasonTier(this.level, this.free, this.premium);

  final int level;
  final SeasonReward free;
  final SeasonReward premium;
}

/// Сезон с сервера: прогресс, обе дорожки и что уже выдано.
class SeasonInfo {
  const SeasonInfo({
    required this.number,
    required this.name,
    required this.endsAt,
    required this.points,
    required this.level,
    required this.levelPoints,
    required this.maxLevel,
    required this.premium,
    required this.freeGranted,
    required this.premiumGranted,
    required this.tiers,
  });

  factory SeasonInfo.fromJson(Map<String, dynamic> j) => SeasonInfo(
    number: (j['number'] as num).toInt(),
    name: j['name'] as String,
    endsAt: DateTime.parse(j['endsAt'] as String).toLocal(),
    points: (j['points'] as num).toInt(),
    level: (j['level'] as num).toInt(),
    levelPoints: (j['levelPoints'] as num).toInt(),
    maxLevel: (j['maxLevel'] as num).toInt(),
    premium: j['premium'] == true,
    freeGranted: (j['freeGranted'] as num?)?.toInt() ?? 0,
    premiumGranted: (j['premiumGranted'] as num?)?.toInt() ?? 0,
    tiers: [
      for (final t in j['tracks'] as List)
        SeasonTier(
          (t['level'] as num).toInt(),
          SeasonReward.fromJson(Map<String, dynamic>.from(t['free'])),
          SeasonReward.fromJson(Map<String, dynamic>.from(t['premium'])),
        ),
    ],
  );

  final int number;
  final String name;
  final DateTime endsAt;
  final int points;
  final int level;
  final int levelPoints;
  final int maxLevel;
  final bool premium;
  final int freeGranted;
  final int premiumGranted;
  final List<SeasonTier> tiers;

  /// Очки внутри текущего уровня и сколько нужно до следующего.
  int get pointsIntoLevel =>
      level >= maxLevel ? levelPoints : points - level * levelPoints;

  int daysLeft(DateTime now) => endsAt.difference(now).inHours <= 0
      ? 0
      : (endsAt.difference(now).inHours / 24).ceil();
}

final seasonProvider = StreamProvider<SeasonInfo>(
  (ref) => cachedGet(
    ref,
    '/v1/season',
    (raw) => SeasonInfo.fromJson(raw as Map<String, dynamic>),
  ),
);
