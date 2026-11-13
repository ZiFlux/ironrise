import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/avatar_icons.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/hero_milestones.dart';
import 'package:ironrise/game/shop.dart';

void main() {
  test('вехи героя 5/10/20 — как на сервере, подарки есть в магазине', () {
    expect(heroMilestonesBetween(4, 11).map((m) => m.level), [5, 10]);
    expect(heroMilestonesBetween(10, 11), isEmpty);
    for (final m in heroMilestones) {
      expect(() => ShopCatalog.byId(m.item), returnsNormally);
    }
    expect(heroLevel({for (final p in BodyPart.values) p: 5}), 5);
  });

  test('аватарки за достижения открываются по порогу', () {
    final trophy = avatarIcons.firstWhere((i) => i.id == 'trophy');
    final medal = avatarIcons.firstWhere((i) => i.id == 'medal');
    expect(
      trophy.unlockedFor(heroLevel: 9, streak: 99, workouts: 999),
      isFalse,
    );
    expect(trophy.unlockedFor(heroLevel: 10, streak: 0, workouts: 0), isTrue);
    expect(medal.unlockText, 'серия 7 дней');
    expect(
      avatarIcons.first.unlockedFor(heroLevel: 1, streak: 0, workouts: 0),
      isTrue,
    );
  });
}
