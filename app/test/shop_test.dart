import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/shop.dart';

/// Образ только из бесплатных вещей.
const _bare = AvatarLook(
  sex: AvatarSex.male,
  hair: HairStyle.short,
  top: TopKind.none,
);

void main() {
  test('стартовый образ целиком из вещей редактора: выдаются при фиксации', () {
    for (final sex in AvatarSex.values) {
      final look = AvatarLook.starter(sex);
      final unpaid = ShopCatalog.unpaid(look, const {});
      expect(unpaid.every(ShopCatalog.inCreator), isTrue);
      expect(ShopCatalog.creatorGrant(look, const {}), unpaid);
    }
  });

  test('примерка платной вещи попадает в корзину, купленная — нет', () {
    final look = ShopCatalog.byId('top_tee').apply(_bare);
    expect(ShopCatalog.unpaid(look, const {}).map((i) => i.id), ['top_tee']);
    expect(ShopCatalog.unpaid(look, const {'top_tee'}), isEmpty);
  });

  test('аксессуар надевается и снимается', () {
    final band = ShopCatalog.byId('acc_headband');
    final on = band.apply(AvatarLook.starter(AvatarSex.female));
    expect(band.isWorn(on), isTrue);
    expect(band.isWorn(band.takeOff!(on)), isFalse);
  });

  test('причёски фильтруются по полу', () {
    final male = ShopCatalog.forSlot(ShopSlot.hair, AvatarSex.male);
    expect(male.every((i) => i.onlyFor != AvatarSex.female), isTrue);
  });

  test('id предметов уникальны, в магазине 30–60 вещей на продажу', () {
    final ids = ShopCatalog.all.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(
      ShopCatalog.all.where((i) => i.forSale).length,
      inInclusiveRange(30, 60),
    );
  });

  test('цены, премиум и эксклюзивы совпадают с сервером', () {
    final ts = File('../server/src/game/shop.ts').readAsStringSync();
    final prices = {
      for (final m in RegExp(r'(\w+): (\d+)').allMatches(
        ts.substring(ts.indexOf('SHOP_PRICES'), ts.indexOf('PREMIUM_ITEMS')),
      ))
        m[1]!: int.parse(m[2]!),
    };
    final premium = RegExp(r"PREMIUM_ITEMS[^=]*=[^\[]*\[([^\]]*)\]")
        .firstMatch(ts)![1]!;
    final tester = RegExp(r"TESTER_ITEMS[^=]*=[^\[]*\[([^\]]*)\]")
        .firstMatch(ts)![1]!;
    final streak = RegExp(r"STREAK_ITEMS[^=]*=[^\[]*\[([^\]]*)\]").firstMatch(
      File('../server/src/game/streak-rewards.ts').readAsStringSync(),
    )![1]!;
    final seasonTs = File('../server/src/game/season.ts').readAsStringSync();
    final season = seasonTs.substring(
      seasonTs.indexOf('SEASON_ITEM_TABLE'),
      seasonTs.indexOf('SEASON_ITEMS'),
    );
    final achievements = RegExp(r"ACHIEVEMENT_ITEMS = \{([^}]*)\}")
        .firstMatch(ts)![1]!;
    final author = RegExp(r"AUTHOR_ITEMS[^=]*=[^\[]*\[([^\]]*)\]")
        .firstMatch(ts)![1]!;
    for (final i in ShopCatalog.all) {
      if (i.testerOnly) {
        // Эксклюзивы: тестерам — TESTER_ITEMS, за серию — STREAK_ITEMS, создателю — AUTHOR_ITEMS.
        expect(
          i.streakDays != null
              ? streak
              : i.exclusiveLabel?.startsWith('сезон') ?? false
              ? season
              : i.exclusiveLabel != null && i.exclusiveLabel!.startsWith('за ')
              ? achievements
              : i.exclusiveLabel != null
              ? author
              : tester,
          contains("'${i.id}'"),
          reason: i.id,
        );
        expect(prices.containsKey(i.id), isFalse, reason: i.id);
      } else {
        expect(prices[i.id], i.price, reason: i.id);
      }
      expect(premium.contains("'${i.id}'"), i.premium, reason: i.id);
    }
    expect(prices.length, ShopCatalog.all.where((i) => !i.testerOnly).length);
  });

  test('эксклюзив тестера в образе требует владения', () {
    final look = _bare.copyWith(accessories: {Accessory.betaCap});
    expect(ShopCatalog.unpaid(look, {}).map((i) => i.id), ['acc_beta_cap']);
    expect(ShopCatalog.unpaid(look, {'acc_beta_cap'}), isEmpty);
  });

  test('образ без обуви сохраняется и читается', () {
    final look = ShopCatalog.byId('sn_lime')
        .apply(AvatarLook.starter(AvatarSex.male));
    final barefoot = ShopCatalog.byId('sneakers_none').apply(look);
    expect(barefoot.sneakersColor, isNull);
    expect(
      AvatarLook.fromJson(look.toJson()).sneakersColor,
      look.sneakersColor,
    );
  });
}
