import 'body_part.dart';
import 'progression.dart';
import 'workout.dart';

/// Награды за серию (п. 37 бэклога). Совпадает с server/src/game/streak-rewards.ts.
/// Каждое продление — немного монет, рубежи — монеты, опыт отстающей части,
/// бустеры на следующую тренировку и вещи «за серию».

/// Бустеры на следующую тренировку: сколько штук каждого.
class Boosters {
  const Boosters({this.xp = 0, this.coins = 0});

  /// Опыт ×1,5.
  final int xp;

  /// Монеты ×2.
  final int coins;

  static const xpFactor = 1.5;
  static const coinFactor = 2;

  bool get isEmpty => xp == 0 && coins == 0;

  Boosters operator +(Boosters o) =>
      Boosters(xp: xp + o.xp, coins: coins + o.coins);

  /// После тренировки: по одному каждого, если были.
  Boosters get afterUse =>
      Boosters(xp: xp > 0 ? xp - 1 : 0, coins: coins > 0 ? coins - 1 : 0);

  Map<String, dynamic> toJson() => {'xp': xp, 'coins': coins};

  factory Boosters.fromJson(Map<String, dynamic>? j) => Boosters(
    xp: (j?['xp'] as num?)?.toInt() ?? 0,
    coins: (j?['coins'] as num?)?.toInt() ?? 0,
  );
}

class StreakMilestone {
  const StreakMilestone(
    this.day,
    this.coins, {
    this.xp = 0,
    this.boosters = const Boosters(),
    this.item,
  });

  final int day;
  final int coins;

  /// Опыт отстающей части тела.
  final int xp;
  final Boosters boosters;

  /// Вещь «за серию» (id из ShopCatalog).
  final String? item;
}

const streakMilestones = <StreakMilestone>[
  StreakMilestone(3, 20),
  StreakMilestone(5, 30, boosters: Boosters(xp: 1)),
  StreakMilestone(7, 50, item: 'sn_streak'),
  StreakMilestone(10, 60, boosters: Boosters(coins: 1)),
  StreakMilestone(14, 80, xp: 100),
  StreakMilestone(21, 100, item: 'tc_streak'),
  StreakMilestone(
    30,
    150,
    item: 'bc_streak',
    boosters: Boosters(xp: 1, coins: 1),
  ),
  StreakMilestone(45, 200, xp: 200),
  StreakMilestone(60, 250, item: 'hc_streak'),
];

/// После 60 дней — рубеж каждые 30 дней.
StreakMilestone? milestoneFor(int day) {
  for (final m in streakMilestones) {
    if (m.day == day) return m;
  }
  if (day > 60 && day % 30 == 0) {
    return StreakMilestone(
      day,
      250,
      xp: 200,
      boosters: const Boosters(xp: 1, coins: 1),
    );
  }
  return null;
}

/// Монеты за каждое продление: чем длиннее серия, тем больше (до 10).
int dailyStreakCoins(int streak) => (2 + streak ~/ 3).clamp(0, 10);

class StreakReward {
  const StreakReward({
    required this.streak,
    required this.coins,
    required this.xp,
    required this.boosters,
    required this.items,
    required this.milestones,
  });

  final int streak;
  final int coins;
  final int xp;
  final Boosters boosters;
  final List<String> items;
  final List<int> milestones;
}

/// Награда за рост серии с [before] до [after]: пройденные рубежи и монеты за продление.
StreakReward? streakReward(int before, int after) {
  if (after <= before) return null;
  var coins = dailyStreakCoins(after);
  var xp = 0;
  var boosters = const Boosters();
  final items = <String>[];
  final milestones = <int>[];
  for (var d = before + 1; d <= after; d++) {
    final m = milestoneFor(d);
    if (m == null) continue;
    milestones.add(d);
    coins += m.coins;
    xp += m.xp;
    boosters = boosters + m.boosters;
    if (m.item != null) items.add(m.item!);
  }
  return StreakReward(
    streak: after,
    coins: coins,
    xp: xp,
    boosters: boosters,
    items: items,
    milestones: milestones,
  );
}

/// Следующий рубеж после [streak].
StreakMilestone nextMilestone(int streak) {
  for (var d = streak + 1; ; d++) {
    final m = milestoneFor(d);
    if (m != null) return m;
  }
}

/// Квест возвращения: серия сгорела — первая тренировка после паузы +25% опыта.
const comebackXpFactor = 1.25;

/// Итог тренировки с бустерами (опыт ×1,5, монеты ×2) и бонусом возвращения.
WorkoutSummary boostedSummary(
  WorkoutSummary s,
  Map<BodyPart, int> xpBefore, {
  required bool xp,
  required bool coins,
  bool comeback = false,
}) {
  final factor =
      (xp ? Boosters.xpFactor : 1) * (comeback ? comebackXpFactor : 1);
  if (factor == 1 && !coins) return s;
  final boostXp = factor != 1;
  final gains = [
    for (final g in s.gains)
      () {
        final gained = boostXp ? (g.xp * factor).round() : g.xp;
        final after = xpBefore[g.part]! + gained;
        return PartGain(
          part: g.part,
          xp: gained,
          levelBefore: g.levelBefore,
          levelAfter: Progression.levelFromXp(after),
          xpAfter: after,
          wasLagging: g.wasLagging,
        );
      }(),
  ];
  final baseCoins = boostXp && s.totalXp > 0
      ? (s.coins * gains.fold(0, (a, g) => a + g.xp) / s.totalXp).round()
      : s.coins;
  return WorkoutSummary(
    duration: s.duration,
    totalSets: s.totalSets,
    gains: gains,
    coins: coins ? baseCoins * Boosters.coinFactor : baseCoins,
    validity: s.validity,
    cardio: s.cardio,
    validityReport: s.validityReport,
  );
}
