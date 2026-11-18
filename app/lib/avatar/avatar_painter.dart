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
    _inStance(canvas, () {
      _paintTorso(canvas);
      _paintRelief(canvas);
      _paintClothes(canvas);
    });
    // Руки — поверх корпуса и одежды: в позах и переходах рука перед телом,
    // а не «проглядывает» кусками сквозь футболку.
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

  void _paintArms(Canvas canvas) {
    for (final arm in [frame.rightArm, frame.leftArm]) {
      _fillSkin(canvas, arm.outline(frame.armStations));
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
      canvas.drawPath(
        arm.hand(frame.wristWidth, look.isFemale ? 15 : 17),
        handPaint,
      );
    }
  }

  void _paintTorso(Canvas canvas) {
    _fillSkin(canvas, frame.bodyOutline);
    _paintNeck(canvas);
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
      (layers.armLines, 0.08 + 0.4 * min(1.0, frame.upperArm)),
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
    _fillSkin(
      canvas,
      Path()..addOval(
        Rect.fromCenter(
          center: BodyFrame.headCenter,
          width: frame.headRx * 2,
          height: frame.headRy * 2,
        ),
      ),
    );
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

  void _fillSkin(Canvas canvas, Path path) {
    final skin = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [look.skin.lit, look.skin.shade],
      ).createShader(_figureBounds);
    canvas
      ..drawPath(path, skin)
      ..drawPath(path, _rimPaint(path));
  }

  /// Дельта: та же кожа, свет сверху снаружи, мягкая тень снизу — округлая
  /// мышца, а не шар с тёмной кромкой.
  void _fillDelt(Canvas canvas, Path path, ArmGeometry arm) {
    final skin = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [look.skin.lit, look.skin.shade],
      ).createShader(_figureBounds);
    canvas.drawPath(path, skin);
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
  }

  void _fillCloth(
    Canvas canvas,
    Path path,
    Color color, {
    bool withFall = false,
  }) {
    canvas
      ..drawPath(path, Paint()..color = color)
      ..drawPath(path, _rimPaint(path));
    if (withFall) canvas.drawPath(path, _fallPaint(path));
  }

  void _fillSolid(Canvas canvas, Path? path, Color color) {
    if (path != null) canvas.drawPath(path, Paint()..color = color);
  }

  /// Затенение по краям формы даёт объём без свечения.
  Paint _rimPaint(Path path) => Paint()
    ..shader = const LinearGradient(
      colors: [
        Color(0x6B000000),
        Color(0x00000000),
        Color(0x0DFFFFFF),
        Color(0x6B000000),
      ],
      stops: [0, 0.28, 0.62, 1],
    ).createShader(path.getBounds());

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
