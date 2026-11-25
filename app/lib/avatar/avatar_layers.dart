import 'dart:math';
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
    TopKind.vneck => Path.combine(PathOperation.difference, _teePath, _vCut),
    TopKind.oversize => mirroredPath([
      const Offset(0, 72),
      Offset(_f.neck + 2, 63),
      Offset(_f.trapX + 2, 70),
      Offset(_f.shoulder + 1, 88),
      Offset(_f.lat + 5, 116),
      Offset(_f.lat + 5.5, 150),
      Offset(_f.hip + 5, 214),
      Offset(_f.hip + 5, 222),
      const Offset(0, 224),
    ]),
    TopKind.crop => mirroredPath([
      const Offset(0, 72),
      Offset(_f.neck + 1.5, 63),
      Offset(_f.trapX + 1, 69.5),
      Offset(_f.shoulder - _f.deltSize * 0.45 + 1, 81),
      Offset(_f.lat + 1.6, 112),
      Offset(_f.lat + 1.2, 124),
      Offset(_f.ribs + 1.2, 146),
      const Offset(0, 148),
    ]),
    TopKind.haori => mirroredPath([
      const Offset(0, 72),
      Offset(_f.neck + 2, 63),
      Offset(_f.trapX + 2, 70),
      Offset(_f.shoulder + 1, 88),
      Offset(_f.lat + 4, 116),
      Offset(_f.lat + 5, 160),
      Offset(_f.hip + 8, 220),
      Offset(_f.hip + 10, 250),
      const Offset(0, 252),
    ]),
    TopKind.tee ||
    TopKind.betaTee ||
    TopKind.clownSuit ||
    TopKind.creatorTee ||
    TopKind.uniform ||
    TopKind.openShirt ||
    TopKind.suit => _teePath,
  };

  Path get _teePath => mirroredPath([
    const Offset(0, 72),
    Offset(_f.neck + 1.5, 63),
    Offset(_f.trapX + 1, 69.5),
    Offset(_f.shoulder - _f.deltSize * 0.45 + 1, 81),
    Offset(_f.lat + 1.6, 112),
    Offset(_f.lat + 1.2, 124),
    Offset(max(_f.ribs, _f.lat - 3) + 1.2, 150),
    Offset(max(_f.waist, _f.lat - 5) + 1.6, 172),
    Offset(_f.hip + 1.6, 200),
    Offset(_f.hip + 1.8, 208),
    const Offset(0, 210),
  ]);

  /// Рукава футболки повторяют дельту и доходят до середины бицепса.
  /// Дельта под рукавом целиком — край рукава не обнажает плечо.
  /// Длинный рукав — по всей руке до запястья, широкий — до локтя с раструбом.
  List<Path> get sleeves => look.top.teeCut
      ? [
          for (final arm in [_f.rightArm, _f.leftArm])
            Path.combine(
              PathOperation.union,
              look.top.longSleeves
                  ? _longSleeveOf(arm)
                  : look.top.wideSleeves
                  ? _wideSleeveOf(arm)
                  : _sleeveOf(arm),
              _f.deltCap(arm, grow: 1.4),
            ),
        ]
      : const [];

  Path _longSleeveOf(ArmGeometry arm) => Path.combine(
    PathOperation.union,
    arm.outline([
      for (final (t, w) in _f.armStations)
        if (t <= 0.86) (t, w + 1.4),
      (0.88, _f.wristWidth + 1.8),
    ]),
    Path()..addOval(
      Rect.fromCircle(center: arm.elbow, radius: _f.elbowWidth + 1.4),
    ),
  );

  Path _wideSleeveOf(ArmGeometry arm) => smoothClosedPath([
    arm.at(-0.08, -(_f.deltSize * 0.15 + 1.6)),
    arm.at(-0.01, -(_f.deltSize * 0.85 + 1.6)),
    arm.at(0.12, -(_f.deltSize + 2.4)),
    arm.at(0.44, -(_f.bicepWidth + 5.5)),
    arm.at(0.44, _f.bicepWidth + 5.5),
    arm.at(0.1, _f.deltSize * 0.6 + 2),
    arm.at(-0.04, _f.deltSize * 0.4 + 1.4),
  ]);

  /// Разрез спереди: рубаха нараспашку открывает грудь и пресс, хаори —
  /// тёмную рубаху под собой.
  Path? get _frontOpening => switch (look.top) {
    TopKind.openShirt => polygonPath([
      Offset(100 - _f.neck * 0.7, 62),
      Offset(100 + _f.neck * 0.7, 62),
      Offset(100 + _f.lat * 0.42, 120),
      Offset(100 + _f.waist * 0.5, 172),
      Offset(100 + _f.hip * 0.42, 212),
      Offset(100 - _f.hip * 0.42, 212),
      Offset(100 - _f.waist * 0.5, 172),
      Offset(100 - _f.lat * 0.42, 120),
    ]),
    TopKind.haori => polygonPath([
      Offset(100 - _f.neck - 1, 62),
      Offset(100 + _f.neck + 1, 62),
      Offset(100 + _f.lat * 0.32, 150),
      Offset(100 + _f.hip * 0.42, 254),
      Offset(100 - _f.hip * 0.42, 254),
      Offset(100 - _f.lat * 0.32, 150),
    ]),
    _ => null,
  };

  /// Что видно в разрезе хаори: тёмная рубаха по телу.
  Path? get topInner {
    if (look.top != TopKind.haori) return null;
    return Path.combine(
      PathOperation.intersect,
      _frontOpening!,
      Path.combine(
        PathOperation.union,
        Path.combine(
          PathOperation.intersect,
          _f.bodyOutline,
          Path()..addRect(const Rect.fromLTRB(-50, 60, 250, 209)),
        ),
        _hemSkirt,
      ),
    );
  }

  /// Пиджак: белая рубашка в вырезе лацканов и галстук.
  (Path, Path)? get suitFront {
    if (look.top != TopKind.suit) return null;
    final w = _f.lat * 0.4;
    final shirt = polygonPath([
      Offset(100 - _f.neck - 1, 62),
      Offset(100 + _f.neck + 1, 62),
      Offset(100 + w, 104),
      const Offset(100, 138),
      Offset(100 - w, 104),
    ]);
    final tie = polygonPath([
      const Offset(97.6, 64),
      const Offset(102.4, 64),
      const Offset(101.4, 70),
      const Offset(103.6, 118),
      const Offset(100, 126),
      const Offset(96.4, 118),
      const Offset(98.6, 70),
    ]);
    return (shirt, tie);
  }

  /// Лацканы пиджака: линии от ворота к вырезу.
  Path? get lapels {
    if (look.top != TopKind.suit) return null;
    final w = _f.lat * 0.4;
    return Path()
      ..moveTo(100 - _f.neck - 3, 62)
      ..lineTo(100 - w - 4, 100)
      ..lineTo(100 - w + 1, 106)
      ..moveTo(100 + _f.neck + 3, 62)
      ..lineTo(100 + w + 4, 100)
      ..lineTo(100 + w - 1, 106);
  }

  /// Мундир: стойка-воротник и золотые пуговицы в ряд по центру.
  (Path, List<Offset>)? get uniformDetails {
    if (look.top != TopKind.uniform) return null;
    final collar = Path()
      ..addRRect(
        RRect.fromLTRBR(
          100 - _f.neck - 2,
          55,
          100 + _f.neck + 2,
          66,
          const Radius.circular(2.5),
        ),
      );
    return (collar, [for (var y = 78.0; y <= 196; y += 19) Offset(100, y)]);
  }

  /// Пушистые отвороты шорт.
  Path? get shortsCuffs {
    if (look.bottom != BottomKind.cuffedShorts) return null;
    return Path.combine(
      PathOperation.intersect,
      bottom,
      Path()..addRect(const Rect.fromLTRB(-50, 276, 250, 290)),
    );
  }

  /// Верх по телу: контур тела (с дельтами), обрезанный по крою вещи, —
  /// горловина, лямки, длина. Сидит на любой фигуре и в любой позе: тянется
  /// по широчайшим, не рвётся на плечах и не открывает «дыр» у подмышек.
  /// Рукава — отдельно (sleeves): их рисуют поверх рук, чтобы рука в позе
  /// была перед корпусом, а плечо — в рукаве. Оверсайз свободнее тела.
  Path? get fittedTop {
    final cut = top;
    if (cut == null) return null;
    final hem = switch (look.top) {
      TopKind.bra => 142.0,
      TopKind.crop => 148.0,
      TopKind.oversize => 224.0,
      TopKind.haori => 252.0,
      TopKind.tank => 207.0,
      _ => 209.0,
    };
    // Ниже подмышек крой — во всю ширину тела: края задаёт само тело.
    // У футболок — от уровня плеч (рука поднята — подмышка всё равно в ткани),
    // у маек и топов — от подмышек: плечи открыты.
    final sleeved = look.top.teeCut;
    final region = Path.combine(
      PathOperation.union,
      cut,
      Path()..addRect(Rect.fromLTRB(-50, sleeved ? 76 : 116, 250, hem)),
    );
    // Тело вместе с низом: у пояса верх не уже штанов — углы таза и пояса
    // не выглядывают из-под подола на узкой талии.
    var body = Path.combine(PathOperation.union, _f.bodyOutline, _hemSkirt);
    if (sleeved) {
      for (final arm in [_f.rightArm, _f.leftArm]) {
        body = Path.combine(PathOperation.union, body, _f.deltCap(arm));
      }
    }
    var fitted = Path.combine(PathOperation.intersect, region, body);
    if (look.top == TopKind.vneck) {
      fitted = Path.combine(PathOperation.difference, fitted, _vCut);
    }
    if (look.top == TopKind.oversize || look.top == TopKind.haori) {
      fitted = Path.combine(PathOperation.union, fitted, cut);
    }
    if (_frontOpening case final opening?) {
      fitted = Path.combine(PathOperation.difference, fitted, opening);
    }
    return fitted;
  }

  /// Ровный клин от талии к бёдрам по ширине низа у пояса: подол прямой,
  /// без бугорков от пояса штанов, и закрывает их углы.
  Path get _hemSkirt {
    // Ширины — по самим фигурам: getBounds у кривых учитывает контрольные
    // точки и завышает.
    final low = fittedBottom;
    final half =
        max(_halfWidth(low, 196), _halfWidth(low, 204)).clamp(_f.hip, 60) + 1.6;
    // Клин начинается там, где тело ещё не шире него, и плавно выходит
    // к ширине низа: на узкой талии без ступеньки.
    final start = _halfWidth(_f.bodyOutline, 182) + 1;
    return mirroredPath([
      const Offset(0, 182),
      Offset(start, 182),
      Offset(_lerp(start, half, 0.55), 193),
      Offset(half, 203),
      Offset(half, 230),
      const Offset(0, 230),
    ]);
  }

  /// Полуширина фигуры [path] на высоте [y] от середины холста.
  static double _halfWidth(Path path, double y) {
    var x = 0.0;
    while (x < 80 && path.contains(Offset(100 + x + 0.5, y))) {
      x += 0.5;
    }
    return x;
  }

  Path get _vCut => Path()
    ..moveTo(100 - _f.neck - 2.5, 62)
    ..lineTo(100 + _f.neck + 2.5, 62)
    ..lineTo(100, 100)
    ..close();

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

  /// Горошек на рукавах — та же сетка, шире по бокам (рукава в позах высоко).
  List<(Offset, int)> get sleeveDots {
    if (look.top != TopKind.clownSuit) return const [];
    return [
      for (var row = -3; row < 9; row++)
        for (var col = -9; col <= 9; col++)
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

  /// Рукав облегает дельту и бицепс: чуть шире руки, без «шара».
  Path _sleeveOf(ArmGeometry arm) => smoothClosedPath([
    arm.at(-0.08, -(_f.deltSize * 0.15 + 1.2)),
    arm.at(-0.01, -(_f.deltSize * 0.82 + 1.2)),
    arm.at(0.1, -(_f.deltSize * 0.95 + 1.2)),
    arm.at(0.32, -(_f.bicepWidth + 1.3)),
    arm.at(0.32, _f.bicepWidth + 1.3),
    arm.at(0.08, _f.deltSize * 0.55 + 1.4),
    arm.at(-0.04, _f.deltSize * 0.4 + 1.2),
  ]);

  /// Низ по телу: своя форма вещи плюс тело от пояса до края штанин —
  /// нога закрыта целиком при любой фигуре (раньше по внутренней стороне
  /// голени проступала кожа); свободные вещи сохраняют свой силуэт.
  Path get fittedBottom {
    final own = bottom;
    final r = own.getBounds();
    final band = Path()
      ..addRect(Rect.fromLTRB(-50, r.top + 1.5, 250, r.bottom - 1));
    return Path.combine(
      PathOperation.union,
      own,
      Path.combine(PathOperation.intersect, band, _f.bodyOutline),
    );
  }

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
    BottomKind.wideShorts => mirroredPath([
      const Offset(0, 190),
      Offset(_f.waistband + 1.4, 192),
      Offset(_f.hip + 2.6, 200),
      Offset(_f.thigh + 5, 226),
      Offset(_f.thigh + 6.5, 274),
      const Offset(2.6, 276),
      const Offset(1.4, 234),
    ]),
    // Шаровары: объём от бёдер до голени, низкий шаг, узкий манжет у щиколотки.
    BottomKind.harem => mirroredPath([
      const Offset(0, 190),
      Offset(_f.waistband + 1.6, 192),
      Offset(_f.hip + 4, 204),
      Offset(_f.thigh + 9, 236),
      Offset(_f.knee + 14, 288),
      Offset(_f.calf + 12, 326),
      Offset(_f.shin + 7, 350),
      Offset(_f.ankle + 3, 362),
      Offset(_f.ankle + 2.6, 374),
      const Offset(3.4, 374),
      const Offset(3.4, 362),
      const Offset(1.6, 330),
      const Offset(0.6, 286),
    ]),
    BottomKind.cargo => mirroredPath([
      const Offset(0, 190),
      Offset(_f.waistband + 1.4, 192),
      Offset(_f.hip + 2.4, 200),
      Offset(_f.thigh + 3, 224),
      Offset(_f.thigh + 1.6, 256),
      Offset(_f.knee + 4.6, 292),
      Offset(_f.calf + 4, 320),
      Offset(_f.shin + 5, 352),
      Offset(_f.ankle + 6, 374),
      const Offset(3, 374),
      const Offset(3.4, 350),
      const Offset(3.8, 292),
      const Offset(4.2, 254),
      const Offset(1.3, 232),
    ]),
    BottomKind.trousers => mirroredPath([
      const Offset(0, 190),
      Offset(_f.waistband + 1.4, 192),
      Offset(_f.hip + 2, 200),
      Offset(_f.thigh + 2.4, 224),
      Offset(_f.thigh + 0.8, 256),
      Offset(_f.knee + 3, 292),
      Offset(_f.calf + 2.4, 320),
      Offset(_f.shin + 3.4, 352),
      Offset(_f.ankle + 4, 374),
      const Offset(3, 374),
      const Offset(3.4, 350),
      const Offset(3.8, 292),
      const Offset(4.2, 254),
      const Offset(1.3, 232),
    ]),
    // Хакама: от пояса расходятся книзу, шаг низкий, внизу почти юбка.
    BottomKind.hakama => mirroredPath([
      const Offset(0, 188),
      Offset(_f.waistband + 1.8, 190),
      Offset(_f.hip + 4, 204),
      Offset(_f.thigh + 8, 236),
      Offset(_f.knee + 12, 290),
      Offset(_f.calf + 15, 334),
      Offset(_f.ankle + 19, 376),
      const Offset(2.4, 376),
      const Offset(1.6, 330),
      const Offset(0.6, 290),
    ]),
    BottomKind.cuffedShorts => mirroredPath([
      const Offset(0, 190),
      Offset(_f.waistband + 1.4, 192),
      Offset(_f.hip + 2.4, 200),
      Offset(_f.thigh + 4, 226),
      Offset(_f.thigh + 4.5, 262),
      Offset(_f.knee + 6, 284),
      const Offset(2.6, 286),
      const Offset(1.4, 234),
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
    for (final p in switch (look.shoes) {
      // Чешки: низкие, по стопе.
      ShoeKind.slippers => [
        Offset(_f.ankle + 0.4, 377),
        Offset(_f.ankle + 5.2, 384),
        Offset(_f.ankle + 4.6, 391),
        const Offset(3, 391),
        const Offset(2.8, 379),
      ],
      // Массивные: выше и шире, толстая подошва.
      ShoeKind.chunky => [
        Offset(_f.ankle + 1.4, 363),
        Offset(_f.ankle + 7.6, 379),
        Offset(_f.ankle + 7, 393),
        const Offset(2.4, 393),
        const Offset(2.2, 366),
      ],
      ShoeKind.sneakers => [
        Offset(_f.ankle + 0.8, 367),
        Offset(_f.ankle + 5.8, 381),
        Offset(_f.ankle + 4.6, 391),
        const Offset(3, 391),
        const Offset(2.8, 369),
      ],
    })
      Offset(100 + side * p.dx, p.dy),
  ]);

  /// Боковые карманы карго: прямоугольники на внешней стороне бедра.
  Path? get cargoPockets {
    if (look.bottom != BottomKind.cargo) return null;
    final path = Path();
    for (final side in const [-1.0, 1.0]) {
      final x = 100 + side * (_f.thigh + 1.6);
      path.addRRect(
        RRect.fromLTRBR(
          side < 0 ? x : x - 9,
          262,
          side < 0 ? x + 9 : x,
          284,
          const Radius.circular(1.5),
        ),
      );
    }
    return path;
  }

  Path get soles {
    final reach = look.shoes == ShoeKind.chunky ? 7 : 4.6;
    final y = look.shoes == ShoeKind.chunky ? 390.6 : 389.6;
    return Path()
      ..moveTo(103.4, y)
      ..lineTo(100 + _f.ankle + reach, y)
      ..moveTo(96.6, y)
      ..lineTo(100 - _f.ankle - reach, y);
  }

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
    // Корпус — по оси предплечья (раньше прямоугольник по экрану: в позах
    // часы оставались «параллельны полу»).
    final face = smoothClosedPath([
      arm.at(0.808, w + 0.9),
      arm.at(0.84, w + 1.45),
      arm.at(0.872, w + 0.9),
      arm.at(0.872, -w - 0.9),
      arm.at(0.84, -w - 1.45),
      arm.at(0.808, -w - 0.9),
    ]);
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

  /// Бандана: повязка пониже и узел-уголок сзади сбоку.
  Path? get bandana {
    if (!_has(Accessory.bandana)) return null;
    final top = _f.headHalfWidthAt(13) + 0.8;
    final bottom = _f.headHalfWidthAt(22) + 0.8;
    return Path.combine(
      PathOperation.union,
      polygonPath([
        Offset(100 - top, 13),
        Offset(100 + top, 13),
        Offset(100 + bottom, 22),
        Offset(100 - bottom, 22),
      ]),
      polygonPath([
        Offset(100 + bottom - 1, 16),
        Offset(100 + bottom + 7, 20),
        Offset(100 + bottom + 4, 27),
        Offset(100 + bottom - 1, 22),
      ]),
    );
  }

  /// Серебряная цепь: тоньше золотой и ниже.
  Path? get silverChain {
    if (!_has(Accessory.silverChain)) return null;
    final x = _f.neck + 2.5;
    return Path()
      ..moveTo(100 - x, 62)
      ..quadraticBezierTo(100, 104, 100 + x, 62)
      ..lineTo(100 + x - 1.4, 62)
      ..quadraticBezierTo(100, 100.5, 100 - x + 1.4, 62)
      ..close();
  }

  /// Шарф (сезон 2): обмотка вокруг шеи и конец, свисающий на грудь слева.
  (Path, Path)? get scarf {
    if (!_has(Accessory.scarf)) return null;
    final x = _f.neck + 4;
    final wrap = Path()
      ..addRRect(
        RRect.fromLTRBR(100 - x, 55, 100 + x, 65, const Radius.circular(5)),
      );
    final tail = polygonPath([
      Offset(100 - x + 2, 60),
      Offset(100 - x + 10, 60),
      Offset(100 - x + 12, 92),
      Offset(100 - x + 3, 93),
    ]);
    return (wrap, tail);
  }

  /// Панама: купол и широкие опущенные поля.
  (Path, Path)? get bucketHat {
    if (!_has(Accessory.bucketHat)) return null;
    final rx = _f.headRx;
    return (
      Path()
        ..moveTo(100 - rx - 0.5, 19)
        ..cubicTo(100 - rx + 1, -2, 100 + rx - 1, -2, 100 + rx + 0.5, 19)
        ..close(),
      polygonPath([
        Offset(100 - rx - 1, 16),
        Offset(100 + rx + 1, 16),
        Offset(100 + rx + 8, 25),
        Offset(100 - rx - 8, 25),
      ]),
    );
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
  /// Круглые очки: две линзы и мостик.
  Path? get roundShades {
    if (!_has(Accessory.roundShades)) return null;
    return Path()
      ..addOval(Rect.fromCircle(center: const Offset(92.6, 28.6), radius: 5))
      ..addOval(Rect.fromCircle(center: const Offset(107.4, 28.6), radius: 5))
      ..addRect(const Rect.fromLTRB(97.4, 27.2, 102.6, 28.4));
  }

  /// Повязка на глаза: широкая лента через всю голову и узел сбоку.
  Path? get blindfold {
    if (!_has(Accessory.blindfold)) return null;
    final top = _f.headHalfWidthAt(23) + 0.8;
    final bottom = _f.headHalfWidthAt(33) + 0.8;
    return Path.combine(
      PathOperation.union,
      polygonPath([
        Offset(100 - top, 23),
        Offset(100 + top, 23),
        Offset(100 + bottom, 33),
        Offset(100 - bottom, 33),
      ]),
      polygonPath([
        Offset(100 + top - 1, 25),
        Offset(100 + top + 6, 29),
        Offset(100 + top + 4, 37),
        Offset(100 + top - 1, 31),
      ]),
    );
  }

  /// Соломенная шляпа: купол, лента и широкие поля.
  (Path, Path, Path)? get strawHat {
    if (!_has(Accessory.strawHat)) return null;
    final rx = _f.headRx;
    final dome = Path()
      ..moveTo(100 - rx + 1, 17)
      ..cubicTo(100 - rx + 2, -2, 100 + rx - 2, -2, 100 + rx - 1, 17)
      ..close();
    final band = polygonPath([
      Offset(100 - rx + 0.6, 11.5),
      Offset(100 + rx - 0.6, 11.5),
      Offset(100 + rx - 1, 16.5),
      Offset(100 - rx + 1, 16.5),
    ]);
    final brim = Path()
      ..addOval(Rect.fromLTRB(100 - rx - 13, 13.5, 100 + rx + 13, 22.5));
    return (dome, band, brim);
  }

  /// Кушак: лента по поясу и конец, свисающий сбоку.
  (Path, Path)? get sash {
    if (!_has(Accessory.sash)) return null;
    final w = _f.waistband + 2.4;
    final wrap = mirroredPath([
      const Offset(0, 182),
      Offset(w - 0.6, 182),
      Offset(w, 194),
      const Offset(0, 195),
    ]);
    final tail = smoothClosedPath([
      Offset(100 + w - 7, 186),
      Offset(100 + w + 1, 188),
      Offset(100 + w + 4, 214),
      Offset(100 + w + 2, 236),
      Offset(100 + w - 5, 236),
      Offset(100 + w - 3, 212),
    ]);
    return (wrap, tail);
  }

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

  /// Волосы за головой: от висков вниз до [depth], бока расходятся на [spread].
  /// Сверху — дуга за макушкой чуть ниже шапки, а не прямая на высоте виска:
  /// иначе по бокам у широких причёсок (грива) видна ступенька.
  Path _backHair(double depth, double spread) {
    final rx = _f.headRx;
    final headTop = BodyFrame.headCenter.dy - _f.headRy;
    final crownY = (headTop + 1 - 0.25 * 30) / 0.75;
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
      ..cubicTo(100 + rx + 3, crownY, 100 - rx - 3, crownY, 100 - rx - 3, 30)
      ..close();
  }

  Path _circle(double x, double y, double r) =>
      Path()..addOval(Rect.fromCircle(center: Offset(x, y), radius: r));

  /// Волосы за головой (рисуются до тела).
  Path? get hairBack {
    final rx = _f.headRx;
    return switch (look.hair) {
      HairStyle.mane => _backHair(84, 13),
      HairStyle.wolfcut => _backHair(58, 7),
      // Маллет: длинные пряди сзади по шее до плеч.
      HairStyle.mullet =>
        Path()
          ..moveTo(100 - rx + 1, 28)
          ..cubicTo(
            100 - rx - 3,
            50,
            100 - _f.neck - 6,
            64,
            100 - _f.neck - 4,
            72,
          )
          ..lineTo(100 + _f.neck + 4, 72)
          ..cubicTo(100 + _f.neck + 6, 64, 100 + rx + 3, 50, 100 + rx - 1, 28)
          ..close(),
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

  /// Парик клоуна сзади: облако кудрей вокруг головы в два слоя, пышное
  /// по бокам —
  /// снаружи красные и оранжевые, ближе к голове жёлтые и зелёные, как дуга
  /// радуги. Кудри: (центр, радиус, место в радуге 0…1).
  List<(Offset, double, double)> get wigBack => [
    ..._wigRing(
      from: -pi - 0.75,
      to: 0.75,
      grow: 9,
      growTop: -2,
      count: 17,
      radius: 8,
      colors: const (0.0, 0.2),
    ),
    ..._wigRing(
      from: -pi - 0.45,
      to: 0.45,
      grow: 3,
      growTop: -6,
      count: 13,
      radius: 7.4,
      colors: const (0.4, 0.6),
    ),
  ];

  /// Парик спереди: чёлка из синих и фиолетовых кудрей по линии волос —
  /// закрывает стык парика с головой, лоб и лицо открыты.
  List<(Offset, double, double)> get wigFront => _wigRing(
    from: -pi + 0.4,
    to: -0.4,
    grow: -4,
    growTop: -8,
    count: 8,
    radius: 5.6,
    colors: const (0.8, 1.0),
  );

  List<(Offset, double, double)> _wigRing({
    required double from,
    required double to,
    required double grow,
    required double growTop,
    required int count,
    required double radius,
    required (double, double) colors,
  }) {
    if (look.hair != HairStyle.clownWig) return const [];
    final c = BodyFrame.headCenter;
    // По бокам пышнее, на макушке ниже: над головой у холста всего 7 px.
    final rx = _f.headRx + grow, ry = _f.headRy + growTop;
    return [
      for (var i = 0; i < count; i++)
        (
          Offset(
            c.dx + cos(from + (to - from) * i / (count - 1)) * rx,
            c.dy + sin(from + (to - from) * i / (count - 1)) * ry,
          ),
          // Кудри неровные: соседние чуть больше и меньше, через одну
          // — второй цвет слоя.
          radius * (i.isEven ? 1.0 : 0.86),
          i.isEven ? colors.$1 : colors.$2,
        ),
    ];
  }

  /// Волосы поверх головы.
  Path get hairFront => switch (look.hair) {
    HairStyle.clownWig => Path(),
    HairStyle.spiky => Path.combine(
      PathOperation.union,
      _cap(24, 1.4),
      _spikes,
    ),
    HairStyle.mane => _cap(36, 4, 17),
    HairStyle.mullet => _cap(26, 1.8),
    HairStyle.wolfcut => Path.combine(
      PathOperation.union,
      _cap(32, 2.6, 20),
      _flicks,
    ),
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

  /// Торчащие пряди: крупные неровные зубцы с наклоном, вверх и в стороны.
  Path get _spikes {
    final top = BodyFrame.headCenter.dy - _f.headRy;
    final rx = _f.headRx;
    final path = Path();
    // (смещение основания, ширина, высота, наклон кончика)
    for (final (dx, w, h, tilt) in const [
      (-14.0, 8.0, 9.0, -7.0),
      (-8.0, 9.0, 13.0, -4.0),
      (-1.0, 9.0, 15.0, 1.0),
      (6.0, 9.0, 13.0, 4.0),
      (12.0, 8.0, 10.0, 7.0),
    ]) {
      path.addPath(
        polygonPath([
          Offset(100 + dx - w / 2, top + 6),
          Offset(100 + dx + w / 2, top + 6),
          Offset(100 + dx + tilt, (top + 6 - h).clamp(0.5, 40)),
        ]),
        Offset.zero,
      );
    }
    // Боковые пряди над ушами. Объединяем, а не складываем: у зеркальной пряди
    // обход контура обратный, и там, где она ложится на зубец, заливка гасилась
    // (серый треугольник в волосах).
    var result = path;
    for (final side in const [-1.0, 1.0]) {
      result = Path.combine(
        PathOperation.union,
        result,
        polygonPath([
          Offset(100 + side * (rx - 3), 12),
          Offset(100 + side * (rx + 5), 14),
          Offset(100 + side * (rx + 0.5), 22),
        ]),
      );
    }
    return result;
  }

  /// Вульфкат: рваные пряди-отскоки по бокам у скул.
  Path get _flicks {
    final rx = _f.headRx;
    var path = Path();
    for (final side in const [-1.0, 1.0]) {
      path = Path.combine(
        PathOperation.union,
        path,
        polygonPath([
          Offset(100 + side * (rx - 1), 26),
          Offset(100 + side * (rx + 4), 34),
          Offset(100 + side * (rx + 1.5), 33),
          Offset(100 + side * (rx + 3), 41),
          Offset(100 + side * (rx - 2), 34),
        ]),
      );
    }
    return path;
  }

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
        ..moveTo(100 - lat * 0.78, 114)
        ..quadraticBezierTo(100 - lat * 0.42, 130 + sag * 0.4, 97, 119)
        ..moveTo(100 + lat * 0.78, 114)
        ..quadraticBezierTo(100 + lat * 0.42, 130 + sag * 0.4, 103, 119);
    }
    return Path()
      ..moveTo(100 - lat * 0.86, 111)
      ..quadraticBezierTo(100 - lat * 0.4, 120 + sag, 100, 115 + sag * 0.5)
      ..quadraticBezierTo(100 + lat * 0.4, 120 + sag, 100 + lat * 0.86, 111);
  }

  /// Пресс по всему корпусу: от грудных до пояса, четыре ряда кубиков —
  /// верхние шире (у рёбер), нижние уже (к талии).
  Path get absLines {
    final path = Path()
      ..moveTo(100, 124)
      ..lineTo(100, 190);
    const rows = [134.0, 149.0, 164.0, 179.0];
    for (final (i, y) in rows.indexed) {
      final half = _lerp(_f.ribs * 0.46, _f.waist * 0.4, i / (rows.length - 1));
      path
        ..moveTo(100 - half, y)
        ..quadraticBezierTo(100, y + 2.2, 100 + half, y);
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
