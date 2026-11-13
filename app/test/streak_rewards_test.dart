import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/shop.dart';
import 'package:ironrise/game/streak_rewards.dart';
import 'package:ironrise/game/workout.dart';

void main() {
  test('как на сервере: рубежи 5 и 7 при прыжке серии с 4 до 7', () {
    final r = streakReward(4, 7)!;
    expect(r.milestones, [5, 7]);
    expect(r.boosters.xp, 1);
    expect(r.items, ['sn_streak']);
    expect(r.coins, dailyStreakCoins(7) + 30 + 50);
    expect(streakReward(5, 5), isNull);
  });

  test('вещи за серию есть в каталоге и не продаются', () {
    for (final m in streakMilestones.where((m) => m.item != null)) {
      final item = ShopCatalog.byId(m.item!);
      expect(item.forSale, isFalse);
      expect(item.isFree, isFalse);
      expect(item.exclusiveLabel, contains('${m.day}'));
    }
  });

  test('бустеры: опыт ×1,5 и монеты ×2, по одному за тренировку', () {
    const s = WorkoutSummary(
      duration: Duration(minutes: 40),
      totalSets: 10,
      gains: [
        PartGain(
          part: BodyPart.chest,
          xp: 100,
          levelBefore: 1,
          levelAfter: 2,
          xpAfter: 150,
          wasLagging: false,
        ),
      ],
      coins: 20,
      validity: 1,
    );
    final xpBefore = {for (final p in BodyPart.values) p: 50};
    final b = boostedSummary(s, xpBefore, xp: true, coins: true);
    expect(b.gains.single.xp, 150);
    expect(b.gains.single.xpAfter, 200);
    expect(b.coins, 60);
    expect(const Boosters(xp: 1, coins: 2).afterUse.coins, 1);
  });
}
