import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/body_part.dart';
import '../game/muscles.dart';
import 'avatar_layers.dart';
import 'avatar_look.dart';
import 'body_frame.dart';

/// Рисует аватар слоями: тень, волосы сзади, руки, тело, рельеф, одежда, голова.
class AvatarPainter extends CustomPainter {
  AvatarPainter({
    required this.levels,
    required this.look,
    this.muscles = const {},
    this.pose = AvatarPose.relaxed,
    this.poseT = 0,
  }) : frame = BodyFrame(levels, look.sex, look.build, muscles, pose, poseT) {
    layers = AvatarLayers(frame, look);
  }

  final Map<BodyPart, num> levels;
  final AvatarLook look;
  final AvatarPose pose;
  final double poseT;

  /// Очки мышц: пропорции внутри частей тела. Пусто — все мышцы ровные.
  final MusclePoints muscles;
  final BodyFrame frame;
  late final AvatarLayers layers;

  static const _floorShadow = Color(0xFF0B0B0C);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(
      size.width / avatarCanvasWidth,
      size.height / avatarCanvasHeight,
    );
    canvas
      ..save()
      ..translate(
        (size.width - avatarCanvasWidth * scale) / 2,
        (size.height - avatarCanvasHeight * scale) / 2,
      )
      ..scale(scale);

    _paintFloorShadow(canvas);
    // Причёска — только у героини (герой без волос).
    if (look.isFemale) _fillSolid(canvas, layers.hairBack, look.hairColor);
    // Как у человека в анфас: плечо (бицепс, трицепс) — за корпусом, край
    // груди и широчайших поверх; предплечье и кисть — перед корпусом и
    // одеждой (кулаки на поясе, руки перед телом в позах); дельта сверху
    // закрывает стык плеча с грудью.
    _paintUpperArms(canvas);
    _inStance(canvas, () {
      _paintTorso(canvas);
      _paintRelief(canvas);
      _paintClothes(canvas);
    });
    _paintArms(canvas);
    _paintShoulders(canvas);
    _paintHead(canvas);

    canvas.restore();
  }

  void _paintFloorShadow(Canvas canvas) => canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(100, 392),
      width: look.isFemale ? 112 : 124,
      height: 10,
    ),
    Paint()..color = _floorShadow,
  );

  /// Тело в стойке: выше таза как есть, каждая нога — своя половина холста,
  /// повёрнутая вокруг тазобедренного сустава. Так ноги встают на ширину плеч
  /// вместе с одеждой, наколенниками и кроссовками.
  void _inStance(Canvas canvas, void Function() draw) {
    const top = BodyFrame.stanceTop;
    canvas
      ..save()
      ..clipRect(const Rect.fromLTRB(-200, -200, 400, top + 0.5));
    draw();
    canvas.restore();
    for (final side in const [1, -1]) {
      final pivot = Offset(100 + side * frame.hipJointX, top - 4);
      canvas
        ..save()
        ..translate(pivot.dx, pivot.dy)
        ..rotate(-side * frame.stanceAngle)
        ..translate(-pivot.dx, -pivot.dy)
        // Обрезка — в исходных координатах: берём свою половину ниже таза.
        ..clipRect(
          side == 1
              ? const Rect.fromLTRB(100, top, 400, 600)
              : const Rect.fromLTRB(-200, top, 100, 600),
        );
      draw();
      canvas.restore();
      // Ступня — туда же, куда ушла нога, но ровно: только сдвиг.
      final ankle = Offset(100 + side * frame.ankle, 380);
      final a = ankle - pivot;
      final angle = -side * frame.stanceAngle;
      final moved =
          pivot +
          Offset(
            a.dx * cos(angle) - a.dy * sin(angle),
            a.dx * sin(angle) + a.dy * cos(angle),
          );
      final shift = moved - ankle;
      canvas
        ..save()
        ..clipRect(
          side == 1
              ? Rect.fromLTRB(100 + shift.dx, top, 400, 600)
              : Rect.fromLTRB(-200, top, 100 + shift.dx, 600),
        )
        ..translate(shift.dx, shift.dy);
      _paintShoes(canvas);
      canvas.restore();
    }
  }

  /// Станции руки до локтя (плечо) и от локтя (предплечье) — с нахлёстом
  /// у локтя, чтобы стык не просвечивал.
  List<(double, double)> get _upperStations =>
      frame.armStations.where((st) => st.$1 <= 0.52).toList()
        ..add((0.6, frame.elbowWidth * 0.98));

  List<(double, double)> get _foreStations => [
    (0.44, frame.elbowWidth * 0.98),
    ...frame.armStations.where((st) => st.$1 > 0.52),
  ];

  void _paintUpperArms(Canvas canvas) {
    for (final arm in [frame.rightArm, frame.leftArm]) {
      _fillSkin(canvas, arm.outline(_upperStations));
    }
    // Рельеф плеча — тут же, под корпусом: на груди его не видно.
    final style = _ReliefStyle.of(look);
    final depth = min(
      0.9,
      (0.08 + 0.4 * min(1.0, frame.upperArm)) * style.strength,
    );
    _paintShine(canvas, layers.armLines, style, depth);
    canvas.drawPath(
      layers.armLines,
      style.paint(style.color.withValues(alpha: depth)),
    );
  }

  void _paintArms(Canvas canvas) {
    for (final arm in [frame.rightArm, frame.leftArm]) {
      // Предплечье продолжает плечо: обводка — только снаружи плеча,
      // без дуги над локтем.
      _fillSkin(
        canvas,
        arm.outline(_foreStations),
        outlineOutside: arm.outline(_upperStations),
      );
    }
    for (final band in layers.wristbands) {
      _fillSolid(canvas, band, look.accessoryColor);
    }
    if (layers.smartwatch case (final strap, final face)) {
      _fillSolid(canvas, strap, const Color(0xFF1C1C1F));
      _fillSolid(canvas, face, const Color(0xFF0B0B0D));
      // Экран светится акцентом — как пульс на часах.
      canvas.drawPath(
        face,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = look.accessoryColor,
      );
    }
    final handPaint = Paint()..color = look.skin.hand;
    for (final arm in [frame.rightArm, frame.leftArm]) {
      final hand = arm.hand(frame.wristWidth, look.isFemale ? 18 : 20);
      canvas
        ..drawPath(hand, handPaint)
        ..drawPath(hand, _shadePaint(hand));
      // Без «манжеты» на запястье: обводка кисти — снаружи предплечья.
      _strokeOutside(canvas, hand, arm.outline(_foreStations));
    }
  }

  void _paintTorso(Canvas canvas) {
    // Шея — под телом: видна только над плечами, светотень берёт торс.
    _paintNeck(canvas);
    _fillSkin(canvas, frame.bodyOutline);
  }

  /// Шея — с телом, под одеждой: её основание у трапеций прячется под ворот.
  void _paintNeck(Canvas canvas) {
    final n = frame.neck;
    // Верх шеи — внутри головы и не шире подбородка на этой высоте:
    // иначе углы среза торчат по бокам челюсти.
    const top = 46.0;
    final topHalf = min(n * 0.8, frame.headHalfWidthAt(top) * 0.85);
    final neck = Path()
      ..moveTo(100 - topHalf, top)
      ..lineTo(100 + topHalf, top)
      // Книзу ровно, у основания расходится в трапеции.
      ..cubicTo(100 + n * 0.86, 58, 100 + n * 1.2, 64, 100 + frame.trapX, 71)
      ..lineTo(100 - frame.trapX, 71)
      ..cubicTo(100 - n * 1.2, 64, 100 - n * 0.86, 58, 100 - topHalf, top)
      ..close();
    canvas.drawPath(
      neck,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [look.skin.lit, look.skin.shade],
        ).createShader(_figureBounds),
    );
    canvas
      ..save()
      ..clipPath(neck)
      // Тень от головы под подбородком.
      ..drawOval(
        Rect.fromCenter(
          center: const Offset(100, 45.5),
          width: frame.headRx * 1.4,
          height: 6,
        ),
        Paint()
          ..color = look.skin.shade.withValues(alpha: 0.4)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      )
      ..restore();
  }

  /// Плечи поверх рук: дельты, рельеф руки и рукава футболки.
  void _paintShoulders(Canvas canvas) {
    for (final arm in [frame.rightArm, frame.leftArm]) {
      _fillDelt(canvas, frame.deltCap(arm), arm);
    }
    final style = _ReliefStyle.of(look);
    for (final (path, opacity) in [
      (layers.deltLines, 0.04 + 0.2 * min(1.0, frame.delts)),
    ]) {
      final depth = min(0.9, opacity * style.strength);
      _paintShine(canvas, path, style, depth);
      canvas.drawPath(path, style.paint(style.color.withValues(alpha: depth)));
    }
    final sleeves = layers.sleeves;
    if (sleeves.isEmpty) return;
    final color = _topColor;
    for (final sleeve in sleeves) {
      canvas.drawPath(
        sleeve,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = color,
      );
      // Без тёмной кромки по краям: рукав — продолжение футболки, не «пузырь».
      canvas
        ..drawPath(sleeve, Paint()..color = color)
        ..drawPath(sleeve, _shadePaint(sleeve))
        ..drawPath(sleeve, _fallPaint(sleeve));
      if (look.top == TopKind.clownSuit) {
        canvas
          ..save()
          ..clipPath(sleeve);
        for (final (at, c) in layers.sleeveDots) {
          canvas.drawCircle(at, 4.2, Paint()..color = _clownDots[c]);
        }
        canvas.restore();
      }
    }
  }

  Color get _topColor => switch (look.top) {
    TopKind.betaTee => _beta,
    TopKind.clownSuit => _clownYellow,
    TopKind.creatorTee => _creatorBlack,
    _ => look.topColor,
  };

  /// У героини мягкие тени в тон кожи, у героя резкие тёмные линии со светлой гранью.
  void _paintRelief(Canvas canvas) {
    final style = _ReliefStyle.of(look);
    _paintPecs(canvas);
    final lines = <(Path, double)>[
      // Рост мышц бывает больше 1 (перекачанные) — рельеф всё равно не чернее обычного.
      (layers.chestLines, 0.12 + 0.45 * min(1.0, frame.chest)),
      (layers.absLines, 0.05 + 0.45 * min(1.0, frame.core)),
      (layers.quadLines, 0.05 + 0.4 * min(1.0, frame.thighs)),
    ];
    for (final (path, opacity) in lines) {
      final depth = min(0.9, opacity * style.strength);
      _paintShine(canvas, path, style, depth);
      canvas.drawPath(path, style.paint(style.color.withValues(alpha: depth)));
    }
    _paintKnees(canvas);
    _paintLegMuscles(canvas);
  }

  /// Квадрицепсы и икры: мягкие борозды и блики, сильнее с прокачкой.
  /// Квадрицепс — «размах» наружной мышцы, «капля» над коленом изнутри,
  /// блик на прямой мышце; икра — две головки (наружная выше, внутренняя
  /// ниже), тень под ними к ахиллу, блик на кости голени.
  void _paintLegMuscles(Canvas canvas) {
    final q = min(1.0, frame.thighs);
    final c = min(1.0, frame.calves);
    final f = look.isFemale;
    final k = f ? 0.7 : 1.0;
    final shade = Color.lerp(look.skin.shade, Colors.black, f ? 0.25 : 0.4)!;
    Paint groove(double a, double w) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = shade.withValues(alpha: a * k)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4);
    Paint gloss(double a) => Paint()
      ..color = Colors.white.withValues(alpha: a * k)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);
    final thigh = frame.thigh, knee = frame.knee, calf = frame.calf;
    final ankle = frame.ankle;
    // Рельеф — только на ноге: размытые края не выходят на фон.
    canvas
      ..save()
      ..clipPath(frame.bodyOutline);
    for (final sd in const [-1.0, 1.0]) {
      double x(double d) => 100 + sd * d;
      // Квадрицепс: блик на прямой мышце бедра.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x((thigh + 5) / 2 + 1), 246),
          width: 7 + q * 3,
          height: 30,
        ),
        gloss(0.07 + q * 0.09),
      );
      // «Размах» наружной широкой мышцы — борозда с внешней стороны.
      canvas.drawPath(
        Path()
          ..moveTo(x(thigh * 0.8), 230)
          ..quadraticBezierTo(x(thigh * 0.86), 258, x(knee * 0.86), 283),
        groove(0.12 + q * 0.3, 2.6),
      );
      // «Капля» над коленом изнутри: тень по её нижнему краю.
      canvas.drawPath(
        Path()
          ..moveTo(x(7), 262)
          ..quadraticBezierTo(x(5 + knee * 0.2), 280, x(knee * 0.42 + 2), 284),
        groove(0.1 + q * 0.32, 3),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x(9), 272),
          width: 5 + q * 2,
          height: 12,
        ),
        gloss(0.05 + q * 0.08),
      );
      // Икра: блик на наружной головке, она выше и круглее.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(x(calf * 0.7), 314),
          width: 6 + c * 2,
          height: 20,
        ),
        gloss(0.08 + c * 0.1),
      );
      // Нижний край головок — переход в ахилл: внутренняя ниже наружной.
      canvas.drawPath(
        Path()
          ..moveTo(x(calf * 0.95), 326)
          ..quadraticBezierTo(x(calf * 0.75), 337, x(calf * 0.58), 338),
        groove(0.1 + c * 0.32, 2.6),
      );
      canvas.drawPath(
        Path()
          ..moveTo(x(calf * 0.4 + 1), 332)
          ..quadraticBezierTo(x(calf * 0.48), 343, x(calf * 0.62), 345),
        groove(0.08 + c * 0.28, 2.4),
      );
      // Блик на кости голени — к щиколотке.
      canvas.drawPath(
        Path()
          ..moveTo(x(calf * 0.55), 300)
          ..quadraticBezierTo(x(calf * 0.5), 335, x(ankle * 0.7 + 2), 362),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeCap = StrokeCap.round
          ..color = Colors.white.withValues(alpha: 0.08 * k)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.2),
      );
    }
    canvas.restore();
  }

  /// Грудные объёмом: блик на верхней части, тень под нижним краем, борозда
  /// грудины, ключицы и складка к подмышке. Ярче с ростом грудных.
  void _paintPecs(Canvas canvas) {
    final lat = frame.lat;
    final chest = min(1.0, frame.chest);
    final f = look.isFemale;
    final shade = Color.lerp(look.skin.shade, Colors.black, 0.3)!;
    Paint soft(Color c, double a, double blur) => Paint()
      ..color = c.withValues(alpha: a)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    Paint groove(Color c, double a, double w, double blur) => Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w
      ..strokeCap = StrokeCap.round
      ..color = c.withValues(alpha: a)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    final sag = frame.chest * 8;
    for (final s in const [-1.0, 1.0]) {
      // Блик на верхней (ключичной) части — сторона к свету ярче.
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(100 + s * lat * 0.44, f ? 104 : 98),
          width: lat * 0.62,
          height: f ? 12 : 11 + chest * 3,
        ),
        soft(Colors.white, (s < 0 ? 0.13 : 0.07) + chest * 0.06, 3),
      );
      // Тень под нижним краем: объём «полки» грудной.
      final edgeY = f ? 119.0 : 115 + sag * 0.5;
      canvas.drawPath(
        Path()
          ..moveTo(100 + s * 2, edgeY + 1)
          ..quadraticBezierTo(
            100 + s * lat * 0.42,
            edgeY + (f ? 13 : 7) + sag * 0.5,
            100 + s * lat * 0.86,
            f ? 116 : 111,
          ),
        groove(shade, (f ? 0.22 : 0.18) + chest * 0.22, f ? 5 : 4.5, 3),
      );
      // Складка к подмышке: грудная уходит под дельту.
      canvas.drawPath(
        Path()
          ..moveTo(100 + s * lat * 0.86, f ? 116 : 111)
          ..quadraticBezierTo(
            100 + s * lat * 0.98,
            100,
            100 + s * (frame.shoulder - frame.deltSize * 0.6),
            88,
          ),
        groove(shade, 0.1 + chest * 0.2, 2.6, 1.6),
      );
      // Ключица — тонкий блик.
      canvas.drawPath(
        Path()
          ..moveTo(100 + s * (frame.neck + 1), 73)
          ..quadraticBezierTo(
            100 + s * lat * 0.45,
            75,
            100 + s * (frame.shoulder - frame.deltSize * 0.5),
            79,
          ),
        groove(Colors.white, 0.14, 1.6, 1),
      );
    }
    if (!f) {
      // Борозда грудины между грудными.
      canvas.drawPath(
        Path()
          ..moveTo(100, 84)
          ..lineTo(100, 114 + sag * 0.5),
        groove(shade, 0.12 + chest * 0.25, 2.4, 1.4),
      );
    }
  }

  /// Колени: блик на чашечке и мягкая тень под ней — нога не «палка».
  void _paintKnees(Canvas canvas) {
    final cx = (frame.knee + 5.5) / 2;
    for (final side in const [-1.0, 1.0]) {
      final at = Offset(100 + side * cx, 289);
      canvas.drawOval(
        Rect.fromCenter(center: at, width: frame.knee * 0.45, height: 9),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.1)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: at + const Offset(0, 6.5),
          width: frame.knee * 0.4,
          height: 2.6,
        ),
        Paint()
          ..color = look.skin.shade.withValues(alpha: 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 1.4),
      );
    }
  }

  /// Светлая грань рядом с линией. Ярче там, где рельеф глубже.
  void _paintShine(Canvas canvas, Path path, _ReliefStyle style, double depth) {
    final shine = style.paint(
      Colors.white.withValues(alpha: style.shine * depth / 0.9),
    );
    canvas
      ..save()
      ..translate(style.shineShift.dx, style.shineShift.dy)
      ..drawPath(path, shine)
      ..restore();
  }

  void _paintClothes(Canvas canvas) {
    final betaBottom = look.bottom == BottomKind.betaJoggers;
    _fillCloth(
      canvas,
      layers.bottom,
      betaBottom ? _betaDark : look.bottomColor,
    );
    if (layers.cargoPockets case final pockets?) {
      canvas.drawPath(
        pockets,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..color = Color.lerp(look.bottomColor, Colors.black, 0.45)!,
      );
    }
    if (layers.joggerPockets case final pockets?) {
      canvas.drawPath(
        pockets,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round
          ..color = Color.lerp(
            betaBottom ? _betaDark : look.bottomColor,
            Colors.black,
            0.5,
          )!.withValues(alpha: 0.9),
      );
    }
    if (betaBottom) {
      canvas.drawPath(
        layers.sideStripes,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.4
          ..strokeCap = StrokeCap.round
          ..strokeJoin = StrokeJoin.round
          ..color = look.accessoryColor,
      );
    }
    final topColor = _topColor;
    final top = layers.fittedTop;
    if (top != null) {
      // Ткань чуть шире кожи: обводка тем же цветом «надувает» вещь на 1 px.
      canvas.drawPath(
        top,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..strokeJoin = StrokeJoin.round
          ..color = topColor,
      );
      _fillCloth(canvas, top, topColor, withFall: true);
    }
    if (look.top == TopKind.betaTee) {
      _paintEmblem(canvas, layers.chestEmblem);
    }
    if (look.top == TopKind.creatorTee) {
      _paintEmblem(
        canvas,
        layers.chestEmblem,
        fill: _gold,
        label: 'IR',
        size: 9,
        radius: 9,
      );
    }
    if (top != null && look.top == TopKind.clownSuit) {
      canvas
        ..save()
        ..clipPath(top);
      for (final (at, color) in layers.clownDots) {
        canvas.drawCircle(at, 4.2, Paint()..color = _clownDots[color]);
      }
      canvas.restore();
      for (final at in layers.ruffle) {
        canvas.drawCircle(at, 6, Paint()..color = const Color(0xFFF4F4F0));
      }
    }
    for (final sleeve in layers.kneeSleeves) {
      _fillCloth(canvas, sleeve, _sleeveColor);
    }
    if (layers.belt case (final belt, final buckle)) {
      _fillCloth(canvas, belt, _leather);
      _fillSolid(canvas, buckle, _steel);
    }
    _fillSolid(canvas, layers.goldChain, _gold);
    _fillSolid(canvas, layers.silverChain, const Color(0xFFD7DADF));
  }

  /// Кроссовки рисуются отдельно: в стойке их сдвигают за ногой, не поворачивая,
  /// чтобы подошва стояла на полу.
  void _paintShoes(Canvas canvas) {
    final sneakers = look.sneakersColor;
    if (sneakers == null) return;
    for (final shoe in layers.sneakers) {
      _fillSolid(canvas, shoe, sneakers);
    }
    canvas.drawPath(
      layers.soles,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..color = const Color(0xFFD8D8D2),
    );
  }

  void _paintHead(Canvas canvas) {
    // Шарф — поверх шеи, иначе шея «проходит» сквозь обмотку.
    if (layers.scarf case (final wrap, final tail)) {
      _fillCloth(canvas, tail, _scarfDark);
      _fillCloth(canvas, wrap, _scarf);
    }
    final head = Path()
      ..addOval(
        Rect.fromCenter(
          center: BodyFrame.headCenter,
          width: frame.headRx * 2,
          height: frame.headRy * 2,
        ),
      );
    canvas
      ..drawPath(
        head,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [look.skin.lit, look.skin.shade],
          ).createShader(_figureBounds),
      )
      ..drawPath(
        head,
        Paint()
          ..shader = const RadialGradient(
            center: Alignment(-0.35, -0.4),
            radius: 1.05,
            colors: [Color(0x1AFFFFFF), Color(0x00000000), Color(0x52000000)],
            stops: [0, 0.5, 1],
          ).createShader(head.getBounds()),
      )
      ..drawPath(head, _outline);
    if (look.isFemale) _fillSolid(canvas, layers.hairFront, look.hairColor);
    _fillSolid(canvas, layers.headband, look.accessoryColor);
    _fillSolid(canvas, layers.bandana, const Color(0xFFC8323A));
    for (final (tuft, color) in layers.wigTufts) {
      _fillSolid(canvas, tuft, _rainbow[color]);
    }
    _fillSolid(canvas, layers.clownNose, const Color(0xFFE5302A));
    _fillSolid(canvas, layers.crown, _gold);
    _fillSolid(canvas, layers.glasses, _lens);
    if (layers.cap case (final dome, final brim)) {
      final beta = look.accessories.contains(Accessory.betaCap);
      _fillCloth(canvas, dome, beta ? _beta : _capColor);
      _fillSolid(canvas, brim, beta ? look.accessoryColor : _capBrim);
    }
    if (layers.bucketHat case (final dome, final brim)) {
      _fillCloth(canvas, dome, const Color(0xFFD9C9A3));
      _fillSolid(canvas, brim, const Color(0xFFC9B88F));
    }
    if (layers.headphones case (final band, final cups)) {
      _fillSolid(canvas, band, _capColor);
      _fillSolid(canvas, cups, look.accessoryColor);
    }
  }

  // Цвета аксессуаров: у каждой вещи свой, кроме акцентных деталей.
  static const _leather = Color(0xFF5C3A21);
  static const _steel = Color(0xFFC9CDD2);
  static const _gold = Color(0xFFD9B25A);
  static const _sleeveColor = Color(0xFF1A1A1D);
  static const _lens = Color(0xFF111114);
  static const _capColor = Color(0xFF2A2A2E);
  static const _capBrim = Color(0xFF1C1C1F);
  static const _beta = Color(0xFF8B5CF6);
  static const _betaDark = Color(0xFF17171A);
  static const _clownYellow = Color(0xFFFFD23F);
  static const _creatorBlack = Color(0xFF26262B);
  static const _scarf = Color(0xFF3E6E9E);
  static const _scarfDark = Color(0xFF2F587F);
  static const _clownDots = [
    Color(0xFFE5302A),
    Color(0xFF3D7BFF),
    Color(0xFF2EBD59),
  ];
  static const _rainbow = [
    Color(0xFFE5302A),
    Color(0xFFFF8A1F),
    Color(0xFFFFD23F),
    Color(0xFF2EBD59),
    Color(0xFF3D7BFF),
    Color(0xFF9B5CF6),
  ];

  /// Эмблема на груди: у тестера — лаймовый круг с «β», у создателя — золотой с «IR».
  void _paintEmblem(
    Canvas canvas,
    Offset at, {
    Color? fill,
    String label = 'β',
    double size = 10,
    double radius = 6.5,
  }) {
    canvas.drawCircle(at, radius, Paint()..color = fill ?? look.accessoryColor);
    final text = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(
          fontSize: size,
          fontWeight: FontWeight.w700,
          color: Color(0xFF17171A),
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    text.paint(canvas, at - Offset(text.width / 2, text.height / 2));
  }

  // ---------- Заливки ----------

  static const _figureBounds = Rect.fromLTWH(
    0,
    0,
    avatarCanvasWidth,
    avatarCanvasHeight,
  );

  /// Обводка формы только там, где она не лежит на [other].
  void _strokeOutside(Canvas canvas, Path path, Path other) {
    canvas
      ..save()
      ..clipPath(
        Path.combine(
          PathOperation.difference,
          Path()..addRect(const Rect.fromLTWH(-100, -100, 400, 600)),
          other,
        ),
      )
      ..drawPath(path, _outline)
      ..restore();
  }

  void _fillSkin(Canvas canvas, Path path, {Path? outlineOutside}) {
    final skin = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [look.skin.lit, look.skin.shade],
      ).createShader(_figureBounds);
    canvas
      ..drawPath(path, skin)
      ..drawPath(path, _shadePaint(path));
    outlineOutside == null
        ? canvas.drawPath(path, _outline)
        : _strokeOutside(canvas, path, outlineOutside);
  }

  /// Тонкая тёмная обводка: силуэт читается на тёмном фоне, руки — поверх
  /// тела, а не сливаются с ним.
  static final _outline = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.1
    ..strokeJoin = StrokeJoin.round
    ..color = const Color(0xA60C0A0D);

  /// Светотень в 2–3 тона: свет слева сверху — светлая сторона, середина,
  /// тень справа с чётким переходом (вместо мягкого градиента по краям).
  /// Свет общий для всей фигуры (по ширине плеч), а не по каждой части:
  /// иначе на стыках торса, дельт и рук — ступеньки тона.
  Paint _shadePaint(Path _) => Paint()
    ..shader = const LinearGradient(
      colors: [
        Color(0x1FFFFFFF),
        Color(0x0FFFFFFF),
        Color(0x00000000),
        Color(0x00000000),
        Color(0x47000000),
        Color(0x66000000),
      ],
      stops: [0, 0.22, 0.32, 0.6, 0.7, 1],
    ).createShader(_lightBounds);

  late final Rect _lightBounds = Rect.fromLTRB(
    100 - frame.shoulder - 14,
    0,
    100 + frame.shoulder + 14,
    avatarCanvasHeight,
  );

  /// Дельта: та же кожа, свет сверху снаружи, мягкая тень снизу — округлая
  /// мышца, а не шар с тёмной кромкой.
  void _fillDelt(Canvas canvas, Path path, ArmGeometry arm) {
    final skin = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [look.skin.lit, look.skin.shade],
      ).createShader(_figureBounds);
    canvas
      ..drawPath(path, skin)
      ..drawPath(path, _shadePaint(path));
    final r = path.getBounds();
    final outer = arm.at(0.06, -frame.deltSize * 0.55);
    canvas
      ..save()
      ..clipPath(path)
      ..drawPath(
        path,
        Paint()
          ..shader = RadialGradient(
            center: Alignment(
              ((outer.dx - r.center.dx) / (r.width / 2)).clamp(-1.0, 1.0),
              -0.55,
            ),
            radius: 0.9,
            colors: [
              Colors.white.withValues(alpha: 0.16),
              Colors.transparent,
              look.skin.shade.withValues(alpha: 0.35),
            ],
            stops: const [0, 0.55, 1],
          ).createShader(r),
      )
      ..restore();
    canvas
      ..save()
      ..clipPath(
        // Только внешний край: на груди и на самой руке — без дуг.
        Path.combine(
          PathOperation.difference,
          Path()..addRect(const Rect.fromLTWH(-100, -100, 400, 600)),
          Path.combine(
            PathOperation.union,
            frame.bodyOutline,
            arm.outline(frame.armStations),
          ),
        ),
      )
      ..drawPath(path, _outline)
      ..restore();
  }

  void _fillCloth(
    Canvas canvas,
    Path path,
    Color color, {
    bool withFall = false,
  }) {
    canvas
      ..drawPath(path, Paint()..color = color)
      ..drawPath(path, _shadePaint(path));
    if (withFall) canvas.drawPath(path, _fallPaint(path));
    canvas.drawPath(path, _outline);
  }

  void _fillSolid(Canvas canvas, Path? path, Color color) {
    if (path != null) canvas.drawPath(path, Paint()..color = color);
  }

  /// Свет сверху, тень снизу: для ткани.
  Paint _fallPaint(Path path) => Paint()
    ..shader = const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0x14FFFFFF), Color(0x4D000000)],
    ).createShader(path.getBounds());

  @override
  // Уровни сравниваются по значениям: при каждой пересборке экрана карта новая,
  // а перерисовка дорогая (контуры тела, градиенты, рельеф).
  bool shouldRepaint(AvatarPainter old) =>
      old.look != look ||
      old.pose != pose ||
      old.poseT != poseT ||
      !mapEquals(old.levels, levels) ||
      !mapEquals(old.muscles, muscles);
}

class _ReliefStyle {
  const _ReliefStyle({
    required this.color,
    required this.width,
    required this.strength,
    required this.blur,
    required this.shine,
    required this.shineShift,
  });

  /// Рельеф — мягкие борозды в тон кожи с бликом со стороны света
  /// (раньше — тёмные линии, «нарисованные» поверх тела).
  factory _ReliefStyle.of(AvatarLook look) => look.isFemale
      ? _ReliefStyle(
          color: Color.lerp(look.skin.shade, Colors.black, 0.25)!,
          width: 3.2,
          strength: 0.55,
          blur: 1.5,
          shine: 0.16,
          shineShift: const Offset(-1.3, -1.4),
        )
      : _ReliefStyle(
          color: Color.lerp(look.skin.shade, Colors.black, 0.4)!,
          width: 3,
          strength: 0.85,
          blur: 1.3,
          shine: 0.22,
          shineShift: const Offset(-1.2, -1.5),
        );

  final Color color;
  final double width;
  final double strength;
  final double blur;
  final double shine;
  final Offset shineShift;

  Paint paint(Color color) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (blur > 0) paint.maskFilter = MaskFilter.blur(BlurStyle.normal, blur);
    return paint;
  }
}
