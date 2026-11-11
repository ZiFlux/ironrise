import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/shop.dart';

void main() {
  test('стартовый образ целиком из бесплатных вещей', () {
    for (final sex in AvatarSex.values) {
      expect(ShopCatalog.unpaid(AvatarLook.starter(sex), const {}), isEmpty);
    }
  });

  test('примерка платной вещи попадает в корзину, купленная — нет', () {
    final look = ShopCatalog.byId('top_tee')
        .apply(AvatarLook.starter(AvatarSex.male));
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

  test('id предметов уникальны, в магазине 10–30 платных вещей', () {
    final ids = ShopCatalog.all.map((i) => i.id).toList();
    expect(ids.toSet().length, ids.length);
    expect(
      ShopCatalog.all.where((i) => !i.isFree).length,
      inInclusiveRange(10, 30),
    );
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
