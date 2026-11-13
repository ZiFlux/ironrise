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
    _fillSolid(canvas, layers.hairBack, look.hairColor);
    _paintArms(canvas);
    _inStance(canvas, () {
      _paintTorso(canvas);
      _paintRelief(canvas);
      _paintClothes(canvas);
    });
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
    final handPaint = Paint()..color = look.skin.hand;
    for (final arm in [frame.rightArm, frame.leftArm]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: arm.handCenter,
          width: look.isFemale ? 9.2 : 10.8,
          height: look.isFemale ? 16 : 18,
        ),
        handPaint,
      );
    }
  }

  void _paintTorso(Canvas canvas) {
    _fillSkin(canvas, frame.bodyOutline);
    for (final arm in [frame.rightArm, frame.leftArm]) {
      _fillSkin(canvas, frame.deltCap(arm));
    }
  }

  /// У героини мягкие тени в тон кожи, у героя резкие тёмные линии со светлой гранью.
  void _paintRelief(Canvas canvas) {
    final style = _ReliefStyle.of(look);
    final lines = <(Path, double)>[
      // Рост мышц бывает больше 1 (перекачанные) — рельеф всё равно не чернее обычного.
      (layers.chestLines, 0.12 + 0.45 * min(1.0, frame.chest)),
      (layers.absLines, 0.05 + 0.45 * min(1.0, frame.core)),
      (layers.quadLines, 0.05 + 0.4 * min(1.0, frame.thighs)),
      // Дельта — часть плеча, а не отдельный шар: граница едва намечена.
      (layers.deltLines, 0.04 + 0.2 * min(1.0, frame.delts)),
      (layers.armLines, 0.08 + 0.4 * min(1.0, frame.upperArm)),
    ];
    for (final (path, opacity) in lines) {
      final depth = min(0.9, opacity * style.strength);
      _paintShine(canvas, path, style, depth);
      canvas.drawPath(path, style.paint(style.color.withValues(alpha: depth)));
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
    final topColor = switch (look.top) {
      TopKind.betaTee => _beta,
      TopKind.clownSuit => _clownYellow,
      TopKind.creatorTee => _creatorBlack,
      _ => look.topColor,
    };
    final top = layers.top;
    if (top != null) _fillCloth(canvas, top, topColor, withFall: true);
    for (final sleeve in layers.sleeves) {
      _fillCloth(canvas, sleeve, topColor, withFall: true);
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
      final suit = Path.combine(
        PathOperation.union,
        top,
        layers.sleeves.fold(
          Path(),
          (a, b) => Path.combine(PathOperation.union, a, b),
        ),
      );
      canvas
        ..save()
        ..clipPath(suit);
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
    _fillSkin(
      canvas,
      Path()
        ..addRect(Rect.fromLTRB(100 - frame.neck, 46, 100 + frame.neck, 64)),
    );
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
    _fillSolid(canvas, layers.hairFront, look.hairColor);
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

  factory _ReliefStyle.of(AvatarLook look) => look.isFemale
      ? _ReliefStyle(
          color: look.skin.shade,
          width: 2.6,
          strength: 0.6,
          blur: 0.9,
          shine: 0.1,
          shineShift: const Offset(-1.2, -1.2),
        )
      : const _ReliefStyle(
          color: Colors.black,
          width: 1.7,
          strength: 1.15,
          blur: 0,
          shine: 0.2,
          shineShift: Offset(0.9, -0.9),
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
