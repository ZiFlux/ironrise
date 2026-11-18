import 'package:flutter/material.dart';

/// Внешний вид аватара: всё, что можно поменять в магазине и гардеробе.
/// Пропорции тела сюда не входят: они считаются из уровней.

enum AvatarSex { male, female }

enum SkinTone {
  iron(Color(0xFF7C7C86), Color(0xFF3A3A42), Color(0xFF4A4A52)),
  light(Color(0xFFE3C2A8), Color(0xFFA8846C), Color(0xFFC09A80)),
  tan(Color(0xFFC79A76), Color(0xFF8A6244), Color(0xFFA07652)),
  brown(Color(0xFF996848), Color(0xFF5E3B26), Color(0xFF744C32)),
  dark(Color(0xFF6E4A35), Color(0xFF3A251A), Color(0xFF4C3123));

  const SkinTone(this.lit, this.shade, this.hand);

  final Color lit;
  final Color shade;
  final Color hand;
}

/// Телосложение на старте: каким герой был в первый день. Запас «лишнего»
/// уходит с ростом кардио и пресса, худоба — с ростом мышц (body_frame.dart).
enum BodyBuild {
  slim('Худощавое'),
  average('Среднее'),
  solid('Плотное'),
  heavy('Крупное');

  const BodyBuild(this.label);
  final String label;
}

enum HairStyle {
  short,
  buzz,
  curly,
  manBun,
  bob,
  ponytail,
  bun,
  long,

  /// Парик клоуна: разноцветные кудри по бокам, макушка открыта.
  clownWig,

  /// Взъерошенные: пряди торчат вверх.
  spiky,

  /// Грива: длинные густые волосы до плеч и ниже.
  mane,

  /// Маллет: коротко сверху и по бокам, длинно сзади.
  mullet,

  /// Вульфкат: рваные слои, чёлка (батлпас).
  wolfcut,
}

/// Модель обуви; цвет — отдельно (sneakersColor).
enum ShoeKind {
  sneakers,

  /// Чешки: мягкая обувь на тонкой подошве.
  slippers,

  /// Массивные кроссовки на толстой подошве.
  chunky,
}

enum TopKind {
  none,
  tank,
  tee,
  bra,

  /// Футболка бета-тестера: фиолетовая с эмблемой β (эксклюзив).
  betaTee,

  /// Костюм клоуна: жёлтый в горошек, с воротником-жабо.
  clownSuit,

  /// Футболка создателя: чёрная с золотой эмблемой (эксклюзив).
  creatorTee,

  /// Футболка с глубоким V-вырезом.
  vneck,

  /// Оверсайз: шире и длиннее, плечо ниже.
  oversize,

  /// Кроп-топ: короткая футболка выше пупка.
  crop;

  /// Крой футболки (с рукавами).
  bool get teeCut => const {
    tee,
    betaTee,
    clownSuit,
    creatorTee,
    vneck,
    oversize,
    crop,
  }.contains(this);

  /// Свой цвет, выбранный «цвет верха» к нему не применяется.
  bool get fixedColor =>
      this == betaTee || this == clownSuit || this == creatorTee;
}

enum BottomKind {
  shorts,
  joggers,
  leggings,

  /// Джоггеры бета-тестера: тёмные с лаймовыми лампасами (эксклюзив).
  betaJoggers,

  /// Широкие шорты до колена.
  wideShorts,

  /// Шаровары: широкие в бёдрах, на манжете у щиколотки.
  harem,

  /// Карго: прямые широкие брюки с боковыми карманами.
  cargo,
}

enum Accessory {
  headband,
  wristbands,
  belt,
  kneeSleeves,
  cap,
  glasses,
  headphones,
  goldChain,

  /// Эксклюзив бета-тестеров.
  betaCap,

  /// Красный нос клоуна.
  clownNose,

  /// Корона создателя (эксклюзив).
  crown,

  /// Смарт-часы на левом запястье — за первое подключение часов.
  smartwatch,

  /// Бандана на голове.
  bandana,

  /// Серебряная цепь.
  silverChain,

  /// Панама (батлпас).
  bucketHat,

  /// Шарф (сезон 2 «Закалка»).
  scarf,
}

class AvatarLook {
  const AvatarLook({
    required this.sex,
    this.skin = SkinTone.iron,
    required this.hair,
    this.hairColor = const Color(0xFF26262A),
    required this.top,
    this.topColor = const Color(0xFF1F1F22),
    this.bottom = BottomKind.shorts,
    this.bottomColor = const Color(0xFF1F1F22),
    this.sneakersColor,
    this.shoes = ShoeKind.sneakers,
    this.accessories = const {},
    this.accessoryColor = const Color(0xFFC6FF3D),
    this.build = BodyBuild.average,
  });

  /// Базовый образ нового героя: без покупок из магазина.
  /// Одет сразу (майка, кроссовки): эти вещи бесплатны в редакторе старта
  /// и выдаются при его фиксации (ShopCatalog.creatorGrant).
  factory AvatarLook.starter(AvatarSex sex) => AvatarLook(
    sex: sex,
    hair: sex == AvatarSex.male ? HairStyle.short : HairStyle.bob,
    top: TopKind.tank,
    topColor: starterTopColor,
    sneakersColor: starterSneakersColor,
  );

  /// Тёмно-синий (tc_navy) и белые (sn_white) из каталога.
  static const starterTopColor = Color(0xFF1E2A4A);
  static const starterSneakersColor = Color(0xFFEDEDED);

  final AvatarSex sex;
  final SkinTone skin;
  final HairStyle hair;
  final Color hairColor;
  final TopKind top;
  final Color topColor;
  final BottomKind bottom;
  final Color bottomColor;

  /// null — без обуви.
  final Color? sneakersColor;
  final ShoeKind shoes;
  final Set<Accessory> accessories;
  final Color accessoryColor;
  final BodyBuild build;

  bool get isFemale => sex == AvatarSex.female;

  AvatarLook copyWith({
    SkinTone? skin,
    HairStyle? hair,
    Color? hairColor,
    TopKind? top,
    Color? topColor,
    BottomKind? bottom,
    Color? bottomColor,
    Color? sneakersColor,
    bool noSneakers = false,
    ShoeKind? shoes,
    Set<Accessory>? accessories,
    BodyBuild? build,
  }) => AvatarLook(
    sex: sex,
    build: build ?? this.build,
    skin: skin ?? this.skin,
    hair: hair ?? this.hair,
    hairColor: hairColor ?? this.hairColor,
    top: top ?? this.top,
    topColor: topColor ?? this.topColor,
    bottom: bottom ?? this.bottom,
    bottomColor: bottomColor ?? this.bottomColor,
    sneakersColor: noSneakers ? null : sneakersColor ?? this.sneakersColor,
    shoes: shoes ?? this.shoes,
    accessories: accessories ?? this.accessories,
    accessoryColor: accessoryColor,
  );

  Map<String, dynamic> toJson() => {
    'sex': sex.name,
    'skin': skin.name,
    'hair': hair.name,
    'hairColor': hairColor.toARGB32(),
    'top': top.name,
    'topColor': topColor.toARGB32(),
    'bottom': bottom.name,
    'bottomColor': bottomColor.toARGB32(),
    'sneakersColor': sneakersColor?.toARGB32(),
    if (shoes != ShoeKind.sneakers) 'shoes': shoes.name,
    'accessories': accessories.map((a) => a.name).toList(),
    'accessoryColor': accessoryColor.toARGB32(),
    'build': build.name,
  };

  /// Неизвестные значения (вещи из более новой версии) не роняют разбор:
  /// берётся стартовое, а незнакомый аксессуар пропускается.
  factory AvatarLook.fromJson(Map<String, dynamic> j) {
    final sex = AvatarSex.values.asNameMap()[j['sex']] ?? AvatarSex.male;
    final starter = AvatarLook.starter(sex);
    final sneakers = j['sneakersColor'] as int?;
    Color color(String key, Color fallback) =>
        j[key] is int ? Color(j[key] as int) : fallback;
    return AvatarLook(
      sex: sex,
      skin: SkinTone.values.asNameMap()[j['skin']] ?? starter.skin,
      hair: HairStyle.values.asNameMap()[j['hair']] ?? starter.hair,
      hairColor: color('hairColor', starter.hairColor),
      top: TopKind.values.asNameMap()[j['top']] ?? starter.top,
      topColor: color('topColor', starter.topColor),
      bottom: BottomKind.values.asNameMap()[j['bottom']] ?? starter.bottom,
      bottomColor: color('bottomColor', starter.bottomColor),
      sneakersColor: sneakers == null ? null : Color(sneakers),
      shoes: ShoeKind.values.asNameMap()[j['shoes']] ?? ShoeKind.sneakers,
      accessories: {
        for (final a in List<String>.from(j['accessories'] ?? const []))
          ?Accessory.values.asNameMap()[a],
      },
      accessoryColor: color('accessoryColor', starter.accessoryColor),
      build: BodyBuild.values.asNameMap()[j['build']] ?? BodyBuild.average,
    );
  }
}
