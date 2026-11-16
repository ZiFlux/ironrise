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
  sneakersColor('Цвет обуви'),
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
    this.exclusiveLabel,
    this.costume = false,
  });

  /// Костюм (клоун): в редакторе стартового образа его нет — только покупка.
  final bool costume;

  /// Вещь за серию: сколько дней (на плитке — огонёк и число).
  int? get streakDays => (exclusiveLabel ?? '').startsWith('серия')
      ? int.tryParse(RegExp(r'(\d+)').firstMatch(exclusiveLabel!)?[1] ?? '')
      : null;

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

  /// Подпись эксклюзива вместо «тестерам», например «серия 7 дн.».
  final String? exclusiveLabel;

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

/// Причёска для обоих полов (новые модные стрижки).
ShopItem _hairAny(String id, String name, HairStyle s, int price) => ShopItem(
  id: id,
  name: name,
  slot: ShopSlot.hair,
  price: price,
  apply: (l) => l.copyWith(hair: s),
  isWorn: (l) => l.hair == s,
);

/// Модель обуви. Без обуви — надеваем в белом.
ShopItem _shoe(String id, String name, ShoeKind k, int price) => ShopItem(
  id: id,
  name: name,
  slot: ShopSlot.sneakers,
  price: price,
  apply: (l) => l.copyWith(
    shoes: k,
    sneakersColor: l.sneakersColor ?? AvatarLook.starterSneakersColor,
  ),
  isWorn: (l) => l.sneakersColor != null && l.shoes == k,
);

ShopItem _color(
  String id,
  String name,
  ShopSlot slot,
  Color c,
  int price, {
  bool premium = false,
  bool testerOnly = false,
  String? exclusiveLabel,
}) => ShopItem(
  id: id,
  name: name,
  slot: slot,
  price: price,
  premium: premium,
  testerOnly: testerOnly,
  exclusiveLabel: exclusiveLabel,
  swatch: c,
  // Вещи тестера всегда своего цвета: выбор цвета меняет их на обычные того же кроя.
  apply: (l) => switch (slot) {
    ShopSlot.hairColor => l.copyWith(hairColor: c),
    ShopSlot.topColor => l.copyWith(
      topColor: c,
      top: l.top.fixedColor ? TopKind.tee : null,
    ),
    ShopSlot.bottomColor => l.copyWith(
      bottomColor: c,
      bottom: l.bottom == BottomKind.betaJoggers ? BottomKind.joggers : null,
    ),
    ShopSlot.sneakersColor => l.copyWith(sneakersColor: c),
    _ => l,
  },
  isWorn: (l) => switch (slot) {
    ShopSlot.hairColor => l.hairColor == c,
    ShopSlot.topColor => !l.top.fixedColor && l.topColor == c,
    ShopSlot.bottomColor =>
      l.bottom != BottomKind.betaJoggers && l.bottomColor == c,
    ShopSlot.sneakersColor => l.sneakersColor == c,
    _ => false,
  },
);

ShopItem _top(
  String id,
  String name,
  TopKind k,
  int price, [
  AvatarSex? sex,
  bool testerOnly = false,
]) => ShopItem(
  id: id,
  name: name,
  slot: ShopSlot.top,
  price: price,
  onlyFor: sex,
  testerOnly: testerOnly,
  apply: (l) => l.copyWith(top: k),
  isWorn: (l) => l.top == k,
);

ShopItem _bottom(
  String id,
  String name,
  BottomKind k,
  int price, {
  bool testerOnly = false,
}) => ShopItem(
  id: id,
  name: name,
  slot: ShopSlot.bottom,
  price: price,
  testerOnly: testerOnly,
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
    _hairAny('hair_spiky', 'Взъерошенные', HairStyle.spiky, 70),
    _hairAny('hair_mane', 'Грива', HairStyle.mane, 90),
    _hairAny('hair_mullet', 'Маллет', HairStyle.mullet, 80),
    ShopItem(
      id: 'hair_wolfcut',
      name: 'Вульфкат',
      slot: ShopSlot.hair,
      price: 0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
      apply: (l) => l.copyWith(hair: HairStyle.wolfcut),
      isWorn: (l) => l.hair == HairStyle.wolfcut,
    ),
    ShopItem(
      id: 'hair_clown',
      name: 'Парик клоуна',
      slot: ShopSlot.hair,
      price: 120,
      costume: true,
      apply: (l) => l.copyWith(hair: HairStyle.clownWig),
      isWorn: (l) => l.hair == HairStyle.clownWig,
    ),
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
    _color(
      'hc_white',
      'Снежные',
      ShopSlot.hairColor,
      const Color(0xFFF2F2EE),
      70,
    ),
    _color(
      'hc_silver',
      'Серебро',
      ShopSlot.hairColor,
      const Color(0xFFB8BEC6),
      60,
    ),
    _color(
      'hc_cherry',
      'Вишня',
      ShopSlot.hairColor,
      const Color(0xFF8E1B2E),
      70,
    ),
    // Верх
    _top('top_none', 'Без верха', TopKind.none, 0, AvatarSex.male),
    _top('top_bra', 'Топ', TopKind.bra, 0, AvatarSex.female),
    _top('top_tank', 'Майка', TopKind.tank, 50),
    _top('top_tee', 'Футболка', TopKind.tee, 40),
    _top('top_beta_tee', 'Футболка тестера', TopKind.betaTee, 0, null, true),
    _top('top_vneck', 'Футболка с V-вырезом', TopKind.vneck, 50),
    _top('top_oversize', 'Оверсайз', TopKind.oversize, 60),
    _top('top_crop', 'Кроп-топ', TopKind.crop, 50),
    ShopItem(
      id: 'top_clown',
      name: 'Костюм клоуна',
      slot: ShopSlot.top,
      price: 150,
      costume: true,
      apply: (l) => l.copyWith(top: TopKind.clownSuit),
      isWorn: (l) => l.top == TopKind.clownSuit,
    ),
    ShopItem(
      id: 'top_creator_tee',
      name: 'Футболка создателя',
      slot: ShopSlot.top,
      price: 0,
      testerOnly: true,
      exclusiveLabel: 'создатель',
      apply: (l) => l.copyWith(top: TopKind.creatorTee),
      isWorn: (l) => l.top == TopKind.creatorTee,
    ),
    _color('tc_graphite', 'Графит', ShopSlot.topColor, _graphite, 0),
    _color('tc_white', 'Белый', ShopSlot.topColor, const Color(0xFFE8E8E8), 30),
    _color(
      'tc_cream',
      'Молочный',
      ShopSlot.topColor,
      const Color(0xFFEDE6D6),
      30,
    ),
    _color('tc_sage', 'Шалфей', ShopSlot.topColor, const Color(0xFF8FA98A), 40),
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
    _color('tc_gold', 'Золото', ShopSlot.topColor, const Color(0xFFD9B25A), 0),
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
    _bottom('bottom_wide_shorts', 'Широкие шорты', BottomKind.wideShorts, 60),
    _bottom('bottom_harem', 'Шаровары', BottomKind.harem, 80),
    _bottom('bottom_cargo', 'Карго', BottomKind.cargo, 70),
    _bottom(
      'bottom_beta_joggers',
      'Джоггеры тестера',
      BottomKind.betaJoggers,
      0,
      testerOnly: true,
    ),
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
    _color(
      'bc_white',
      'Белый',
      ShopSlot.bottomColor,
      const Color(0xFFF2F2EE),
      30,
    ),
    _color(
      'bc_denim',
      'Деним',
      ShopSlot.bottomColor,
      const Color(0xFF4F6D93),
      40,
    ),
    _color(
      'bc_sand',
      'Бежевый',
      ShopSlot.bottomColor,
      const Color(0xFFD9C9A3),
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
    _shoe('sh_sneakers', 'Кроссовки', ShoeKind.sneakers, 0),
    _shoe('sh_slippers', 'Чешки', ShoeKind.slippers, 60),
    _shoe('sh_chunky', 'Массивные кроссовки', ShoeKind.chunky, 90),
    _color(
      'sn_white',
      'Белые',
      ShopSlot.sneakersColor,
      const Color(0xFFEDEDED),
      40,
    ),
    _color(
      'sn_black',
      'Чёрные',
      ShopSlot.sneakersColor,
      const Color(0xFF2A2A2E),
      40,
    ),
    _color(
      'sn_lime',
      'Лаймовые',
      ShopSlot.sneakersColor,
      const Color(0xFFC6FF3D),
      70,
    ),
    _color(
      'sn_red',
      'Красные',
      ShopSlot.sneakersColor,
      const Color(0xFFE5484D),
      70,
    ),
    _color(
      'sn_blue',
      'Синие',
      ShopSlot.sneakersColor,
      const Color(0xFF3D7BFF),
      70,
    ),
    _color(
      'sn_gold',
      'Золотые',
      ShopSlot.sneakersColor,
      const Color(0xFFD9B25B),
      0,
    ),
    _color(
      'sn_beta',
      'Бета',
      ShopSlot.sneakersColor,
      const Color(0xFF8B5CF7),
      0,
      testerOnly: true,
    ),
    // Вещи за серию (streak_rewards.dart): не продаются, выдаются на рубежах.
    _color(
      'sn_streak',
      'Пламя',
      ShopSlot.sneakersColor,
      const Color(0xFFFF5A20),
      0,
      testerOnly: true,
      exclusiveLabel: 'серия 7 дн.',
    ),
    _color(
      'tc_streak',
      'Пламя',
      ShopSlot.topColor,
      const Color(0xFFFF5A1F),
      0,
      testerOnly: true,
      exclusiveLabel: 'серия 21 дн.',
    ),
    _color(
      'bc_streak',
      'Угли',
      ShopSlot.bottomColor,
      const Color(0xFF3A1A12),
      0,
      testerOnly: true,
      exclusiveLabel: 'серия 30 дн.',
    ),
    _color(
      'hc_streak',
      'Огненные',
      ShopSlot.hairColor,
      const Color(0xFFFF6A00),
      0,
      testerOnly: true,
      exclusiveLabel: 'серия 60 дн.',
    ),
    // За достижения в приложении (server/src/game/shop.ts, ACHIEVEMENT_ITEMS).
    _color(
      'sn_first_step',
      'Первый шаг',
      ShopSlot.sneakersColor,
      const Color(0xFF5CE1A5),
      0,
      testerOnly: true,
      exclusiveLabel: 'за гайд',
    ),
    // Сезон 1 «Пробуждение» (server/src/game/season.ts): бесплатная и премиум-дорожки.
    _color(
      'sn_s1',
      'Бирюза',
      ShopSlot.sneakersColor,
      const Color(0xFF2EC4B6),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
    ),
    _color(
      'tc_s1',
      'Бирюза',
      ShopSlot.topColor,
      const Color(0xFF2EC4B6),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
    ),
    _color(
      'bc_s1',
      'Глубина',
      ShopSlot.bottomColor,
      const Color(0xFF14403D),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
    ),
    _color(
      'hc_s1',
      'Мята',
      ShopSlot.hairColor,
      const Color(0xFF7FDBDA),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
    ),
    _color(
      'sn_s1p',
      'Солнце',
      ShopSlot.sneakersColor,
      const Color(0xFFFFD166),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
    ),
    _color(
      'tc_s1p',
      'Лагуна',
      ShopSlot.topColor,
      const Color(0xFF0B6E6E),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
    ),
    // Сезон 2 «Закалка» (server/src/game/season.ts): сталь и мороз.
    _color(
      'sn_s2',
      'Иней',
      ShopSlot.sneakersColor,
      const Color(0xFFB9D8F0),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
    ),
    _color(
      'tc_s2',
      'Сталь',
      ShopSlot.topColor,
      const Color(0xFF5B6B7A),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
    ),
    _color(
      'bc_s2',
      'Ночная сталь',
      ShopSlot.bottomColor,
      const Color(0xFF26313D),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
    ),
    _color(
      'hc_s2',
      'Иней',
      ShopSlot.hairColor,
      const Color(0xFFDDE8F2),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
    ),
    _color(
      'sn_s2p',
      'Окалина',
      ShopSlot.sneakersColor,
      const Color(0xFFE85D3A),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
    ),
    _color(
      'bc_s2p',
      'Окалина',
      ShopSlot.bottomColor,
      const Color(0xFF4A2E2A),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
    ),
    _color(
      'tc_s2p',
      'Закалённая сталь',
      ShopSlot.topColor,
      const Color(0xFF2B5C8A),
      0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
    ),
    // Аксессуары
    _accessory('acc_headband', 'Повязка', Accessory.headband, 50),
    _accessory('acc_wristbands', 'Напульсники', Accessory.wristbands, 50),
    _accessory('acc_belt', 'Атлетический пояс', Accessory.belt, 90),
    _accessory('acc_knee_sleeves', 'Наколенники', Accessory.kneeSleeves, 70),
    _accessory('acc_cap', 'Кепка', Accessory.cap, 80),
    _accessory('acc_glasses', 'Тёмные очки', Accessory.glasses, 60),
    _accessory('acc_headphones', 'Наушники', Accessory.headphones, 100),
    _accessory('acc_gold_chain', 'Золотая цепь', Accessory.goldChain, 0),
    _accessory(
      'acc_beta_cap',
      'Кепка тестера',
      Accessory.betaCap,
      0,
      testerOnly: true,
    ),
    _accessory('acc_clown_nose', 'Красный нос', Accessory.clownNose, 60),
    _accessory('acc_bandana', 'Бандана', Accessory.bandana, 60),
    _accessory(
      'acc_silver_chain',
      'Серебряная цепь',
      Accessory.silverChain,
      90,
    ),
    ShopItem(
      id: 'acc_bucket',
      name: 'Панама',
      slot: ShopSlot.accessory,
      price: 0,
      testerOnly: true,
      exclusiveLabel: 'сезон 1',
      apply: (l) =>
          l.copyWith(accessories: {...l.accessories, Accessory.bucketHat}),
      isWorn: (l) => l.accessories.contains(Accessory.bucketHat),
      takeOff: (l) => l.copyWith(
        accessories: {...l.accessories}..remove(Accessory.bucketHat),
      ),
    ),
    ShopItem(
      id: 'acc_scarf',
      name: 'Шарф',
      slot: ShopSlot.accessory,
      price: 0,
      testerOnly: true,
      exclusiveLabel: 'сезон 2',
      apply: (l) =>
          l.copyWith(accessories: {...l.accessories, Accessory.scarf}),
      isWorn: (l) => l.accessories.contains(Accessory.scarf),
      takeOff: (l) =>
          l.copyWith(accessories: {...l.accessories}..remove(Accessory.scarf)),
    ),
    ShopItem(
      id: 'acc_smartwatch',
      name: 'Смарт-часы',
      slot: ShopSlot.accessory,
      price: 0,
      testerOnly: true,
      exclusiveLabel: 'за часы',
      apply: (l) =>
          l.copyWith(accessories: {...l.accessories, Accessory.smartwatch}),
      isWorn: (l) => l.accessories.contains(Accessory.smartwatch),
      takeOff: (l) => l.copyWith(
        accessories: {...l.accessories}..remove(Accessory.smartwatch),
      ),
    ),
    ShopItem(
      id: 'acc_crown',
      name: 'Корона создателя',
      slot: ShopSlot.accessory,
      price: 0,
      testerOnly: true,
      exclusiveLabel: 'создатель',
      apply: (l) =>
          l.copyWith(accessories: {...l.accessories, Accessory.crown}),
      isWorn: (l) => l.accessories.contains(Accessory.crown),
      takeOff: (l) =>
          l.copyWith(accessories: {...l.accessories}..remove(Accessory.crown)),
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

  /// Бесплатно, пока собирается стартовый образ: одежда, причёски и цвета
  /// без аксессуаров, премиума и эксклюзивов. Совпадает с server/src/game/start-look.ts.
  static bool inCreator(ShopItem i) =>
      i.slot != ShopSlot.accessory && !i.premium && !i.testerOnly && !i.costume;

  /// Вещи редактора, надетые в образе и ещё не купленные: их выдают при фиксации.
  static List<ShopItem> creatorGrant(AvatarLook look, Set<String> owned) => [
    for (final i in unpaid(look, owned))
      if (inCreator(i)) i,
  ];

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
