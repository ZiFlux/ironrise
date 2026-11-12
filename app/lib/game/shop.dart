import 'package:flutter/material.dart';

import '../avatar/avatar_look.dart';

/// Слоты гардероба в порядке вкладок.
enum ShopSlot {
  hair('Причёска'),
  hairColor('Цвет волос'),
  top('Верх'),
  topColor('Цвет верха'),
  bottom('Низ'),
  bottomColor('Цвет низа'),
  sneakers('Обувь'),
  accessory('Аксессуары'),
  skin('Кожа');

  const ShopSlot(this.label);
  final String label;
}

/// Косметика за монеты (ТЗ: магазин, PLAN 5.3 — 10–15 предметов на старте).
/// Цена 0 — есть у всех с начала. На силу косметика не влияет.
class ShopItem {
  const ShopItem({
    required this.id,
    required this.name,
    required this.slot,
    required this.price,
    required this.apply,
    required this.isWorn,
    this.swatch,
    this.onlyFor,
    this.takeOff,
    this.premium = false,
    this.testerOnly = false,
  });

  final String id;
  final String name;
  final ShopSlot slot;
  final int price;

  /// Цвет образца для плитки; null — показываем иконку слота.
  final Color? swatch;

  /// null — для обоих полов.
  final AvatarSex? onlyFor;

  final AvatarLook Function(AvatarLook) apply;
  final bool Function(AvatarLook) isWorn;

  /// Есть только у аксессуаров: их можно снять, остальное лишь заменить.
  final AvatarLook Function(AvatarLook)? takeOff;

  /// Купить можно только с премиумом (носить купленное — всегда).
  final bool premium;

  /// Эксклюзив бета-тестеров: не продаётся, выдаётся аккаунту.
  final bool testerOnly;

  bool get isFree => price == 0 && !testerOnly;

  /// Продаётся в магазине (бесплатное и эксклюзивы — нет).
  bool get forSale => price > 0 && !testerOnly;
}

ShopItem _hair(String id, String name, HairStyle s, int price, AvatarSex sex) =>
    ShopItem(
      id: id,
      name: name,
      slot: ShopSlot.hair,
      price: price,
      onlyFor: sex,
      apply: (l) => l.copyWith(hair: s),
      isWorn: (l) => l.hair == s,
    );

ShopItem _color(
  String id,
  String name,
  ShopSlot slot,
  Color c,
  int price, {
  bool premium = false,
  bool testerOnly = false,
}) => ShopItem(
  id: id,
  name: name,
  slot: slot,
  price: price,
  premium: premium,
  testerOnly: testerOnly,
  swatch: c,
  apply: (l) => switch (slot) {
    ShopSlot.hairColor => l.copyWith(hairColor: c),
    ShopSlot.topColor => l.copyWith(topColor: c),
    ShopSlot.bottomColor => l.copyWith(bottomColor: c),
    ShopSlot.sneakers => l.copyWith(sneakersColor: c),
    _ => l,
  },
  isWorn: (l) => switch (slot) {
    ShopSlot.hairColor => l.hairColor == c,
    ShopSlot.topColor => l.topColor == c,
    ShopSlot.bottomColor => l.bottomColor == c,
    ShopSlot.sneakers => l.sneakersColor == c,
    _ => false,
  },
);

ShopItem _top(String id, String name, TopKind k, int price, [AvatarSex? sex]) =>
    ShopItem(
      id: id,
      name: name,
      slot: ShopSlot.top,
      price: price,
      onlyFor: sex,
      apply: (l) => l.copyWith(top: k),
      isWorn: (l) => l.top == k,
    );

ShopItem _bottom(String id, String name, BottomKind k, int price) => ShopItem(
  id: id,
  name: name,
  slot: ShopSlot.bottom,
  price: price,
  apply: (l) => l.copyWith(bottom: k),
  isWorn: (l) => l.bottom == k,
);

ShopItem _accessory(
  String id,
  String name,
  Accessory a,
  int price, {
  bool premium = false,
  bool testerOnly = false,
}) => ShopItem(
  id: id,
  name: name,
  slot: ShopSlot.accessory,
  price: price,
  premium: premium,
  testerOnly: testerOnly,
  apply: (l) => l.copyWith(accessories: {...l.accessories, a}),
  isWorn: (l) => l.accessories.contains(a),
  takeOff: (l) => l.copyWith(accessories: {...l.accessories}..remove(a)),
);

ShopItem _skin(String id, String name, SkinTone t) => ShopItem(
  id: id,
  name: name,
  slot: ShopSlot.skin,
  price: 0,
  swatch: t.lit,
  apply: (l) => l.copyWith(skin: t),
  isWorn: (l) => l.skin == t,
);

const _graphite = Color(0xFF1F1F22);

class ShopCatalog {
  const ShopCatalog._();

  static final List<ShopItem> all = [
    // Причёски
    _hair('hair_short', 'Короткая', HairStyle.short, 0, AvatarSex.male),
    _hair('hair_buzz', 'Под машинку', HairStyle.buzz, 40, AvatarSex.male),
    _hair('hair_curly', 'Кудри', HairStyle.curly, 60, AvatarSex.male),
    _hair('hair_manbun', 'Пучок', HairStyle.manBun, 80, AvatarSex.male),
    _hair('hair_bob', 'Каре', HairStyle.bob, 0, AvatarSex.female),
    _hair('hair_ponytail', 'Хвост', HairStyle.ponytail, 40, AvatarSex.female),
    _hair('hair_bun', 'Пучок', HairStyle.bun, 60, AvatarSex.female),
    _hair('hair_long', 'Длинные', HairStyle.long, 80, AvatarSex.female),
    // Цвет волос
    _color(
      'hc_black',
      'Тёмные',
      ShopSlot.hairColor,
      const Color(0xFF26262A),
      0,
    ),
    _color(
      'hc_brown',
      'Каштан',
      ShopSlot.hairColor,
      const Color(0xFF5A3A24),
      30,
    ),
    _color(
      'hc_blond',
      'Блонд',
      ShopSlot.hairColor,
      const Color(0xFFD9B66E),
      30,
    ),
    _color('hc_red', 'Рыжие', ShopSlot.hairColor, const Color(0xFFB4532A), 40),
    _color(
      'hc_platinum',
      'Платина',
      ShopSlot.hairColor,
      const Color(0xFFE6E2D8),
      60,
    ),
    _color(
      'hc_pink',
      'Розовые',
      ShopSlot.hairColor,
      const Color(0xFFE86AA6),
      70,
    ),
    _color('hc_blue', 'Синие', ShopSlot.hairColor, const Color(0xFF4A7BD9), 70),
    // Верх
    _top('top_none', 'Без верха', TopKind.none, 0, AvatarSex.male),
    _top('top_bra', 'Топ', TopKind.bra, 0, AvatarSex.female),
    _top('top_tank', 'Майка', TopKind.tank, 50),
    _top('top_tee', 'Футболка', TopKind.tee, 40),
    _color('tc_graphite', 'Графит', ShopSlot.topColor, _graphite, 0),
    _color('tc_white', 'Белый', ShopSlot.topColor, const Color(0xFFE8E8E8), 30),
    _color('tc_lime', 'Лайм', ShopSlot.topColor, const Color(0xFFC6FF3D), 40),
    _color('tc_ember', 'Огонь', ShopSlot.topColor, const Color(0xFFFF7A3D), 40),
    _color('tc_ice', 'Лёд', ShopSlot.topColor, const Color(0xFF3DDCFF), 40),
    _color(
      'tc_navy',
      'Тёмно-синий',
      ShopSlot.topColor,
      const Color(0xFF1E2A4A),
      40,
    ),
    _color('tc_red', 'Красный', ShopSlot.topColor, const Color(0xFFD23C3C), 40),
    _color(
      'tc_gold',
      'Золото',
      ShopSlot.topColor,
      const Color(0xFFD9B25A),
      120,
      premium: true,
    ),
    _color(
      'tc_beta',
      'Бета',
      ShopSlot.topColor,
      const Color(0xFF8B5CF6),
      0,
      testerOnly: true,
    ),
    // Низ
    _bottom('bottom_shorts', 'Шорты', BottomKind.shorts, 0),
    _bottom('bottom_joggers', 'Джоггеры', BottomKind.joggers, 50),
    _bottom('bottom_leggings', 'Леггинсы', BottomKind.leggings, 50),
    _color('bc_graphite', 'Графит', ShopSlot.bottomColor, _graphite, 0),
    _color(
      'bc_navy',
      'Тёмно-синий',
      ShopSlot.bottomColor,
      const Color(0xFF1E2A4A),
      30,
    ),
    _color(
      'bc_olive',
      'Хаки',
      ShopSlot.bottomColor,
      const Color(0xFF4A5230),
      30,
    ),
    _color(
      'bc_grey',
      'Меланж',
      ShopSlot.bottomColor,
      const Color(0xFF8A8A90),
      30,
    ),
    _color(
      'bc_black',
      'Чёрный',
      ShopSlot.bottomColor,
      const Color(0xFF0E0E10),
      30,
    ),
    // Обувь
    ShopItem(
      id: 'sneakers_none',
      name: 'Босиком',
      slot: ShopSlot.sneakers,
      price: 0,
      apply: (l) => l.copyWith(noSneakers: true),
      isWorn: (l) => l.sneakersColor == null,
    ),
    _color('sn_white', 'Белые', ShopSlot.sneakers, const Color(0xFFEDEDED), 40),
    _color(
      'sn_black',
      'Чёрные',
      ShopSlot.sneakers,
      const Color(0xFF2A2A2E),
      40,
    ),
    _color(
      'sn_lime',
      'Лаймовые',
      ShopSlot.sneakers,
      const Color(0xFFC6FF3D),
      70,
    ),
    _color('sn_red', 'Красные', ShopSlot.sneakers, const Color(0xFFE5484D), 70),
    _color('sn_blue', 'Синие', ShopSlot.sneakers, const Color(0xFF3D7BFF), 70),
    _color(
      'sn_gold',
      'Золотые',
      ShopSlot.sneakers,
      const Color(0xFFD9B25B),
      120,
      premium: true,
    ),
    _color(
      'sn_beta',
      'Бета',
      ShopSlot.sneakers,
      const Color(0xFF8B5CF7),
      0,
      testerOnly: true,
    ),
    // Аксессуары
    _accessory('acc_headband', 'Повязка', Accessory.headband, 50),
    _accessory('acc_wristbands', 'Напульсники', Accessory.wristbands, 50),
    _accessory('acc_belt', 'Атлетический пояс', Accessory.belt, 90),
    _accessory('acc_knee_sleeves', 'Наколенники', Accessory.kneeSleeves, 70),
    _accessory('acc_cap', 'Кепка', Accessory.cap, 80),
    _accessory('acc_glasses', 'Тёмные очки', Accessory.glasses, 60),
    _accessory('acc_headphones', 'Наушники', Accessory.headphones, 100),
    _accessory(
      'acc_gold_chain',
      'Золотая цепь',
      Accessory.goldChain,
      150,
      premium: true,
    ),
    _accessory(
      'acc_beta_cap',
      'Кепка тестера',
      Accessory.betaCap,
      0,
      testerOnly: true,
    ),
    // Кожа — бесплатно: это внешность, а не награда.
    _skin('skin_iron', 'Железо', SkinTone.iron),
    _skin('skin_light', 'Светлая', SkinTone.light),
    _skin('skin_tan', 'Смуглая', SkinTone.tan),
    _skin('skin_brown', 'Тёмная', SkinTone.brown),
    _skin('skin_dark', 'Очень тёмная', SkinTone.dark),
  ];

  static List<ShopItem> forSlot(ShopSlot slot, AvatarSex sex) => [
    for (final i in all)
      if (i.slot == slot && (i.onlyFor == null || i.onlyFor == sex)) i,
  ];

  static ShopItem byId(String id) => all.firstWhere((i) => i.id == id);

  /// Платные (и эксклюзивные) вещи образа, которых ещё нет у игрока, — «корзина» примерки.
  static List<ShopItem> unpaid(AvatarLook look, Set<String> owned) => [
    for (final i in all)
      if (!i.isFree &&
          !owned.contains(i.id) &&
          (i.onlyFor == null || i.onlyFor == look.sex) &&
          i.isWorn(look))
        i,
  ];
}
