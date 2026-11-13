import 'dart:ui';

import 'avatar_look.dart';
import 'body_frame.dart';

/// Пути одежды, волос и рельефа. Каждая вещь строится по точкам тела,
/// поэтому садится на любые пропорции.
class AvatarLayers {
  AvatarLayers(this.frame, this.look);

  final BodyFrame frame;
  final AvatarLook look;

  BodyFrame get _f => frame;

  // ---------- Одежда ----------

  Path? get top => switch (look.top) {
    TopKind.none => null,
    TopKind.bra => mirroredPath([
      const Offset(0, 104),
      Offset(_f.neck + 4.5, 66),
      Offset(_f.neck + 8, 67),
      Offset(_f.lat + 1.4, 110),
      Offset(_f.lat + 1, 124),
      Offset(_lerp(_f.lat, _f.waist, 0.3) + 0.8, 141),
      const Offset(0, 142),
    ]),
    TopKind.tank => mirroredPath([
      Offset(0, look.isFemale ? 92 : 78),
      Offset(_f.neck + 2.5, 64),
      Offset(_f.neck + (look.isFemale ? 6 : 7), 66),
      Offset(_f.lat + 1.6, 108),
      Offset(_f.lat + 1, 124),
      Offset(_f.ribs + 1, 150),
      Offset(_f.waist + 1, 172),
      Offset(_f.hip + 1.2, 200),
      Offset(_f.hip + 1.4, 206),
      const Offset(0, 208),
    ]),
    TopKind.tee ||
    TopKind.betaTee ||
    TopKind.clownSuit ||
    TopKind.creatorTee => mirroredPath([
      const Offset(0, 72),
      Offset(_f.neck + 1.5, 63),
      Offset(_f.trapX + 1, 69.5),
      Offset(_f.shoulder - _f.deltSize * 0.45 + 1, 81),
      Offset(_f.lat + 1.6, 112),
      Offset(_f.lat + 1.2, 124),
      Offset(_f.ribs + 1.2, 150),
      Offset(_f.waist + 1.4, 172),
      Offset(_f.hip + 1.6, 200),
      Offset(_f.hip + 1.8, 208),
      const Offset(0, 210),
    ]),
  };

  /// Рукава футболки повторяют дельту и доходят до середины бицепса.
  List<Path> get sleeves => look.top.teeCut
      ? [_sleeveOf(_f.rightArm), _sleeveOf(_f.leftArm)]
      : const [];

  /// Горошек костюма клоуна: кружки по сетке (обрезаются по костюму при рисовании).
  List<(Offset, int)> get clownDots {
    if (look.top != TopKind.clownSuit) return const [];
    return [
      for (var row = 0; row < 7; row++)
        for (var col = -3; col <= 3; col++)
          (
            Offset(100 + col * 11.0 + (row.isOdd ? 5.5 : 0), 74 + row * 17.0),
            (row + col) % 3,
          ),
    ];
  }

  /// Воротник-жабо: белые полукруги вокруг шеи.
  List<Offset> get ruffle {
    if (look.top != TopKind.clownSuit) return const [];
    final w = _f.neck + 11;
    return [
      for (var i = 0; i <= 6; i++)
        Offset(100 - w + i * (2 * w / 6), 65 + (i == 0 || i == 6 ? -1 : 1.5)),
    ];
  }

  /// Центр эмблемы на груди футболки тестера.
  Offset get chestEmblem => Offset(100 + _f.lat * 0.42, 100);

  /// Косые карманы джоггеров: от пояса к боку бедра.
  Path? get joggerPockets {
    if (look.bottom != BottomKind.joggers &&
        look.bottom != BottomKind.betaJoggers) {
      return null;
    }
    final path = Path();
    for (final s in const [-1.0, 1.0]) {
      path
        ..moveTo(100 + s * (_f.waistband - 4.5), 193.5)
        ..quadraticBezierTo(
          100 + s * (_f.hip - 3.5),
          199,
          100 + s * (_f.hip + 1.2),
          214,
        );
    }
    return path;
  }

  /// Лампасы джоггеров тестера — по внешнему краю штанин.
  Path get sideStripes {
    final path = Path();
    for (final s in const [-1.0, 1.0]) {
      final pts = [
        Offset(_f.hip + 0.6, 202),
        Offset(_f.thigh + 0.8, 224),
        Offset(_f.thigh - 2.4, 254),
        Offset(_f.knee + 1.2, 290),
        Offset(_f.calf + 0.6, 318),
        Offset(_f.shin + 0.6, 350),
        Offset(_f.ankle + 1.6, 364),
      ];
      path.moveTo(100 + s * pts.first.dx, pts.first.dy);
      for (final p in pts.skip(1)) {
        path.lineTo(100 + s * p.dx, p.dy);
      }
    }
    return path;
  }

  Path _sleeveOf(ArmGeometry arm) => smoothClosedPath([
    arm.at(-0.08, -(_f.deltSize * 0.15 + 1.6)),
    arm.at(-0.01, -(_f.deltSize * 0.9 + 1.6)),
    arm.at(0.09, -(_f.deltSize * 1.14 + 1.6)),
    arm.at(0.34, -(_f.bicepWidth + 2)),
    arm.at(0.34, _f.bicepWidth + 2),
    arm.at(0.08, _f.deltSize * 0.6 + 1.8),
    arm.at(-0.04, _f.deltSize * 0.42 + 1.6),
  ]);

  Path get bottom => switch (look.bottom) {
    BottomKind.shorts => mirroredPath([
      const Offset(0, 190),
      Offset(_f.waistband + 1.2, 192),
      Offset(_f.hip + 1.6, 200),
      Offset(_f.thigh + 1.8, 224),
      Offset(_f.thigh - 1.4, 256),
      const Offset(4.2, 259),
      const Offset(1.4, 232),
    ]),
    BottomKind.joggers || BottomKind.betaJoggers => mirroredPath([
      const Offset(0, 190),
      Offset(_f.waistband + 1.4, 192),
      Offset(_f.hip + 2, 200),
      Offset(_f.thigh + 2.2, 224),
      Offset(_f.thigh - 1, 254),
      Offset(_f.knee + 2.6, 290),
      Offset(_f.calf + 2, 318),
      Offset(_f.shin + 2, 350),
      Offset(_f.ankle + 3, 366),
      Offset(_f.ankle + 2.6, 374),
      const Offset(3.4, 374),
      const Offset(3.8, 366),
      Offset(_f.calf * 0.35 - 0.5, 330),
      const Offset(3.8, 292),
      const Offset(4.2, 254),
      const Offset(1.3, 232),
    ]),
    BottomKind.leggings => mirroredPath([
      const Offset(0, 186),
      Offset(_lerp(_f.waist, _f.hip, 0.55) + 0.6, 188),
      Offset(_f.hip + 0.6, 200),
      Offset(_f.thigh + 0.6, 224),
      Offset(_f.thigh - 2.4, 254),
      Offset(_f.knee + 1.6, 290),
      Offset(_f.calf + 0.6, 318),
      Offset(_f.shin + 0.6, 350),
      Offset(_f.ankle + 0.8, 368),
      const Offset(4, 368),
      Offset(_f.calf * 0.35 - 0.3, 330),
      const Offset(4.1, 292),
      const Offset(4.6, 254),
      const Offset(1.3, 230),
    ]),
  };

  List<Path> get sneakers =>
      look.sneakersColor == null ? const [] : [_shoe(1), _shoe(-1)];

  Path _shoe(int side) => smoothClosedPath([
    for (final p in [
      Offset(_f.ankle + 0.8, 367),
      Offset(_f.ankle + 5.8, 381),
      Offset(_f.ankle + 4.6, 391),
      const Offset(3, 391),
      const Offset(2.8, 369),
    ])
      Offset(100 + side * p.dx, p.dy),
  ]);

  Path get soles => Path()
    ..moveTo(103.4, 389.6)
    ..lineTo(100 + _f.ankle + 4.6, 389.6)
    ..moveTo(96.6, 389.6)
    ..lineTo(100 - _f.ankle - 4.6, 389.6);

  // ---------- Аксессуары ----------

  Path? get headband {
    if (!look.accessories.contains(Accessory.headband)) return null;
    final top = _f.headHalfWidthAt(15) + 0.6;
    final bottom = _f.headHalfWidthAt(21) + 0.6;
    return polygonPath([
      Offset(100 - top, 15),
      Offset(100 + top, 15),
      Offset(100 + bottom, 21),
      Offset(100 - bottom, 21),
    ]);
  }

  List<Path> get wristbands => look.accessories.contains(Accessory.wristbands)
      ? [_wristband(_f.rightArm), _wristband(_f.leftArm)]
      : const [];

  Path _wristband(ArmGeometry arm) => polygonPath([
    arm.at(0.8, _f.wristWidth + 1.4),
    arm.at(0.9, _f.wristWidth + 1.2),
    arm.at(0.9, -_f.wristWidth - 1.2),
    arm.at(0.8, -_f.wristWidth - 1.4),
  ]);

  bool _has(Accessory a) => look.accessories.contains(a);

  /// Смарт-часы на левом запястье: ремешок и корпус-экран поверх него.
  (Path, Path)? get smartwatch {
    if (!_has(Accessory.smartwatch)) return null;
    final arm = _f.leftArm;
    final w = _f.wristWidth;
    final strap = polygonPath([
      arm.at(0.8, w + 1.2),
      arm.at(0.88, w + 1.1),
      arm.at(0.88, -w - 1.1),
      arm.at(0.8, -w - 1.2),
    ]);
    final center = arm.at(0.84, 0);
    final face = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: center, width: w * 2 + 2.6, height: 7),
          const Radius.circular(2.4),
        ),
      );
    return (strap, face);
  }

  /// Атлетический пояс на талии и пряжка.
  (Path, Path)? get belt {
    if (!_has(Accessory.belt)) return null;
    final top = _lerp(_f.waist, _f.hip, 0.1) + 1.6;
    final bottom = _lerp(_f.waist, _f.hip, 0.6) + 1.6;
    return (
      polygonPath([
        Offset(100 - top, 175),
        Offset(100 + top, 175),
        Offset(100 + bottom, 189),
        Offset(100 - bottom, 189),
      ]),
      Path()..addRRect(
        RRect.fromLTRBR(95.5, 177.5, 104.5, 186.5, const Radius.circular(1.5)),
      ),
    );
  }

  /// Наколенники на обеих ногах.
  List<Path> get kneeSleeves {
    if (!_has(Accessory.kneeSleeves)) return const [];
    final top = _lerp(_f.thigh - 3, _f.knee + 1, 24 / 36) + 1.4;
    final bottom = _lerp(_f.knee + 1, _f.calf, 10 / 28) + 1.4;
    return [
      for (final s in const [-1.0, 1.0])
        polygonPath([
          Offset(100 + s * 4.2, 277),
          Offset(100 + s * top, 277),
          Offset(100 + s * bottom, 301),
          Offset(100 + s * 4.3, 301),
        ]),
    ];
  }

  /// Красный нос клоуна.
  Path? get clownNose =>
      _has(Accessory.clownNose) ? _circle(100, 36, 3.8) : null;

  /// Корона создателя: зубцы над макушкой.
  Path? get crown {
    if (!_has(Accessory.crown)) return null;
    const w = 13.0;
    final path = Path()..moveTo(100 - w, 13);
    for (var i = 0; i < 5; i++) {
      final x = 100 - w + i * (2 * w / 4);
      path
        ..lineTo(x, i == 2 ? 0.5 : 3)
        ..lineTo(x + (i < 4 ? w / 4 : 0), i < 4 ? 8 : 13);
    }
    return path
      ..lineTo(100 + w, 13)
      ..close();
  }

  /// Цепь на шее: дуга от ключиц к груди.
  Path? get goldChain {
    if (!_has(Accessory.goldChain)) return null;
    final x = _f.neck + 1.5;
    return Path()
      ..moveTo(100 - x, 61)
      ..quadraticBezierTo(100, 96, 100 + x, 61)
      ..lineTo(100 + x - 2.2, 61)
      ..quadraticBezierTo(100, 91, 100 - x + 2.2, 61)
      ..close();
  }

  /// Кепка (и кепка тестера): купол поверх волос и козырёк.
  (Path, Path)? get cap {
    if (!_has(Accessory.cap) && !_has(Accessory.betaCap)) return null;
    final rx = _f.headRx;
    return (
      Path()
        ..moveTo(100 - rx - 1.4, 21)
        ..cubicTo(100 - rx, -1, 100 + rx, -1, 100 + rx + 1.4, 21)
        ..close(),
      Path()..addRRect(
        RRect.fromLTRBR(
          100 - rx - 4,
          18.5,
          100 + rx + 4,
          23.5,
          const Radius.circular(2.5),
        ),
      ),
    );
  }

  /// Тёмные очки.
  Path? get glasses {
    if (!_has(Accessory.glasses)) return null;
    return Path()
      ..addRRect(RRect.fromLTRBR(86.5, 25, 98, 32.5, const Radius.circular(3)))
      ..addRRect(
        RRect.fromLTRBR(102, 25, 113.5, 32.5, const Radius.circular(3)),
      )
      ..addRect(const Rect.fromLTRB(97.5, 26.5, 102.5, 28));
  }

  /// Наушники: дуга над головой и чашки.
  (Path, Path)? get headphones {
    if (!_has(Accessory.headphones)) return null;
    final rx = _f.headRx;
    return (
      Path()
        ..moveTo(100 - rx - 2.5, 30)
        ..cubicTo(100 - rx - 2, -4, 100 + rx + 2, -4, 100 + rx + 2.5, 30)
        ..lineTo(100 + rx - 0.5, 30)
        ..cubicTo(100 + rx - 1, 0, 100 - rx + 1, 0, 100 - rx + 0.5, 30)
        ..close(),
      Path()
        ..addRRect(
          RRect.fromLTRBR(
            100 - rx - 5,
            22,
            100 - rx + 2,
            40,
            const Radius.circular(3),
          ),
        )
        ..addRRect(
          RRect.fromLTRBR(
            100 + rx - 2,
            22,
            100 + rx + 5,
            40,
            const Radius.circular(3),
          ),
        ),
    );
  }

  // ---------- Волосы ----------

  /// Шапка волос: от виска [lowY] через макушку — на [lift] выше макушки головы
  /// (объём причёски). Бока прилегают к голове на высоте виска. Надо лбом — почти
  /// прямая линия волос на высоте [hairline] (по умолчанию на 8 выше виска).
  Path _cap(double lowY, double lift, [double? hairline]) {
    final headTop = BodyFrame.headCenter.dy - _f.headRy;
    // Вершина кубической дуги — 0,25·виск + 0,75·контрольная точка.
    final crownY = (headTop - lift - 0.25 * lowY) / 0.75;
    final side = _f.headHalfWidthAt(lowY) + 0.9;
    // Контрольные точки чуть шире головы: дуга обнимает её, а не режет.
    final rx = _f.headRx + 0.9;
    final h = hairline ?? lowY - 8;
    return Path()
      ..moveTo(100 - side, lowY)
      ..cubicTo(100 - rx, crownY, 100 + rx, crownY, 100 + side, lowY)
      ..lineTo(100 + side - 3, h + 2)
      ..quadraticBezierTo(100, h - 2, 100 - side + 3, h + 2)
      ..close();
  }

  Path _backHair(double depth, double spread) {
    final rx = _f.headRx;
    return Path()
      ..moveTo(100 - rx - 3, 30)
      ..cubicTo(
        100 - rx - spread,
        depth - 6,
        100 - rx + 2,
        depth + 2,
        100,
        depth,
      )
      ..cubicTo(
        100 + rx - 2,
        depth + 2,
        100 + rx + spread,
        depth - 6,
        100 + rx + 3,
        30,
      )
      ..close();
  }

  Path _circle(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  /// Волосы за головой (рисуются до тела).
  Path? get hairBack {
    final rx = _f.headRx;
    return switch (look.hair) {
      HairStyle.bob => _backHair(64, 4),
      HairStyle.long => _backHair(88, 7),
      HairStyle.ponytail =>
        Path()
          ..moveTo(108, 14)
          ..cubicTo(100 + rx + 16, 12, 100 + rx + 14, 52, 100 + rx + 6, 76)
          ..cubicTo(100 + rx + 2, 52, 100 + rx + 4, 26, 106, 20)
          ..close(),
      _ => null,
    };
  }

  /// Пряди парика клоуна: кружки по бокам головы, у каждой свой цвет радуги.
  List<(Path, int)> get wigTufts {
    if (look.hair != HairStyle.clownWig) return const [];
    final rx = _f.headRx;
    final tufts = <(Path, int)>[];
    var i = 0;
    for (final side in const [-1.0, 1.0]) {
      for (final (dx, y) in const [
        (2.0, 12.0),
        (7.0, 18.0),
        (9.0, 26.0),
        (7.0, 34.0),
        (10.0, 13.0),
        (11.0, 22.0),
      ]) {
        tufts.add((_circle(100 + side * (rx - 1 + dx), y, 6.8), i++ % 6));
      }
    }
    return tufts;
  }

  /// Волосы поверх головы.
  Path get hairFront => switch (look.hair) {
    HairStyle.clownWig => Path(),
    HairStyle.short => _cap(26, 1.6),
    HairStyle.buzz => _cap(22, 0.7, 15),
    HairStyle.curly => Path.combine(PathOperation.union, _cap(26, 1.4), _curls),
    HairStyle.manBun => Path.combine(
      PathOperation.union,
      _cap(25, 1.4),
      _circle(100, 7, 6),
    ),
    HairStyle.bob || HairStyle.long => _cap(36, 2.2, 18),
    HairStyle.ponytail => _cap(30, 1.8, 18),
    HairStyle.bun => Path.combine(
      PathOperation.union,
      _cap(27, 1.8),
      _circle(100, 6, 7),
    ),
  };

  Path get _curls {
    final path = Path();
    for (final dx in const [-12.0, -6.0, 0.0, 6.0, 12.0]) {
      path.addPath(_circle(100 + dx, 12 + dx.abs() * 0.35, 5.2), Offset.zero);
    }
    return path;
  }

  // ---------- Рельеф ----------

  Path get chestLines {
    final lat = _f.lat;
    // Крупные грудные опускают нижний край ниже.
    final sag = _f.chest * 8;
    if (look.isFemale) {
      return Path()
        ..moveTo(100 - lat * 0.78, 126)
        ..quadraticBezierTo(100 - lat * 0.42, 142 + sag * 0.4, 97, 131)
        ..moveTo(100 + lat * 0.78, 126)
        ..quadraticBezierTo(100 + lat * 0.42, 142 + sag * 0.4, 103, 131);
    }
    return Path()
      ..moveTo(100 - lat * 0.86, 124)
      ..quadraticBezierTo(100 - lat * 0.4, 132 + sag, 100, 127 + sag * 0.5)
      ..quadraticBezierTo(100 + lat * 0.4, 132 + sag, 100 + lat * 0.86, 124);
  }

  Path get absLines {
    final half = _f.waist * 0.42;
    final path = Path()
      ..moveTo(100, 138)
      ..lineTo(100, 186);
    for (final y in const [150.0, 164.0, 178.0]) {
      path
        ..moveTo(100 - half, y)
        ..quadraticBezierTo(100, y + 2, 100 + half, y);
    }
    return path;
  }

  Path get quadLines {
    final hip = _f.hip;
    final path = Path();
    for (final s in const [-1.0, 1.0]) {
      path
        ..moveTo(100 + s * hip * 0.52, 236)
        ..quadraticBezierTo(
          100 + s * (hip * 0.6 - 2),
          262,
          100 + s * hip * 0.46,
          286,
        );
    }
    return path;
  }

  Path get armLines {
    final path = Path();
    for (final arm in [_f.rightArm, _f.leftArm]) {
      final a = arm.at(0.1, _f.deltWidth * 0.15);
      final b = arm.at(0.22, _f.deltWidth * 0.5);
      final c = arm.at(0.3, _f.bicepWidth * 0.2);
      path
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(b.dx, b.dy, c.dx, c.dy);
    }
    return path;
  }

  Path get deltLines {
    final path = Path();
    for (final arm in [_f.rightArm, _f.leftArm]) {
      // Только внешняя складка между дельтой и бицепсом: со стороны груди
      // плечо переходит в туловище без шва.
      final a = arm.at(0.25, -_f.deltSize * 0.05);
      final b = arm.at(0.25, -_f.deltSize * 0.45);
      final c = arm.at(0.2, -_f.deltSize * 0.85);
      path
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(b.dx, b.dy, c.dx, c.dy);
    }
    return path;
  }
}

double _lerp(double a, double b, double t) => a + (b - a) * t;
