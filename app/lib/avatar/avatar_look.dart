import 'package:flutter/material.dart';

/// Внешний вид аватара: всё, что можно поменять в магазине и гардеробе.
/// Пропорции тела сюда не входят: они считаются из уровней.

enum AvatarSex { male, female }

enum SkinTone {
  iron(Color(0xFF606068), Color(0xFF2A2A2F), Color(0xFF34343A)),
  light(Color(0xFFE3C2A8), Color(0xFFA8846C), Color(0xFFC09A80)),
  tan(Color(0xFFC79A76), Color(0xFF8A6244), Color(0xFFA07652)),
  brown(Color(0xFF996848), Color(0xFF5E3B26), Color(0xFF744C32)),
  dark(Color(0xFF6E4A35), Color(0xFF3A251A), Color(0xFF4C3123));

  const SkinTone(this.lit, this.shade, this.hand);

  final Color lit;
  final Color shade;
  final Color hand;
}

enum HairStyle { short, buzz, curly, manBun, bob, ponytail, bun, long }

enum TopKind { none, tank, tee, bra }

enum BottomKind { shorts, joggers, leggings }

enum Accessory { headband, wristbands }

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
    this.accessories = const {},
    this.accessoryColor = const Color(0xFFC6FF3D),
  });

  /// Базовый образ нового героя: без покупок из магазина.
  factory AvatarLook.starter(AvatarSex sex) => AvatarLook(
        sex: sex,
        hair: sex == AvatarSex.male ? HairStyle.short : HairStyle.bob,
        top: sex == AvatarSex.male ? TopKind.none : TopKind.bra,
      );

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
  final Set<Accessory> accessories;
  final Color accessoryColor;

  bool get isFemale => sex == AvatarSex.female;

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
        'accessories': accessories.map((a) => a.name).toList(),
        'accessoryColor': accessoryColor.toARGB32(),
      };

  factory AvatarLook.fromJson(Map<String, dynamic> j) {
    final sneakers = j['sneakersColor'] as int?;
    return AvatarLook(
      sex: AvatarSex.values.byName(j['sex']),
      skin: SkinTone.values.byName(j['skin']),
      hair: HairStyle.values.byName(j['hair']),
      hairColor: Color(j['hairColor']),
      top: TopKind.values.byName(j['top']),
      topColor: Color(j['topColor']),
      bottom: BottomKind.values.byName(j['bottom']),
      bottomColor: Color(j['bottomColor']),
      sneakersColor: sneakers == null ? null : Color(sneakers),
      accessories: {
        for (final a in List<String>.from(j['accessories'] ?? const [])) Accessory.values.byName(a),
      },
      accessoryColor: Color(j['accessoryColor']),
    );
  }
}
