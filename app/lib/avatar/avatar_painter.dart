import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../game/body_part.dart';
import 'avatar_layers.dart';
import 'avatar_look.dart';
import 'body_frame.dart';

/// Рисует аватар слоями: тень, волосы сзади, руки, тело, рельеф, одежда, голова.
class AvatarPainter extends CustomPainter {
  AvatarPainter({required this.levels, required this.look})
      : frame = BodyFrame(levels, look.sex) {
    layers = AvatarLayers(frame, look);
  }

  final Map<BodyPart, num> levels;
  final AvatarLook look;
  final BodyFrame frame;
  late final AvatarLayers layers;

  static const _floorShadow = Color(0xFF0B0B0C);

  @override
  void paint(Canvas canvas, Size size) {
    final scale = min(size.width / avatarCanvasWidth, size.height / avatarCanvasHeight);
    canvas
      ..save()
      ..translate((size.width - avatarCanvasWidth * scale) / 2,
          (size.height - avatarCanvasHeight * scale) / 2)
      ..scale(scale);

    _paintFloorShadow(canvas);
    _fillSolid(canvas, layers.hairBack, look.hairColor);
    _paintArms(canvas);
    _paintTorso(canvas);
    _paintRelief(canvas);
    _paintClothes(canvas);
    _paintHead(canvas);

    canvas.restore();
  }

  void _paintFloorShadow(Canvas canvas) => canvas.drawOval(
        Rect.fromCenter(center: const Offset(100, 392), width: 108, height: 10),
        Paint()..color = _floorShadow,
      );

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
        Rect.fromCenter(center: arm.handCenter, width: look.isFemale ? 9.2 : 10.8, height: look.isFemale ? 16 : 18),
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
      (layers.chestLines, 0.12 + 0.45 * frame.chest),
      (layers.absLines, 0.05 + 0.45 * frame.core),
      (layers.quadLines, 0.05 + 0.4 * frame.legs),
      (layers.deltLines, 0.1 + 0.45 * (frame.arms + frame.back) / 2),
      (layers.armLines, 0.08 + 0.4 * frame.arms),
    ];
    for (final (path, opacity) in lines) {
      final depth = min(0.9, opacity * style.strength);
      _paintShine(canvas, path, style, depth);
      canvas.drawPath(path, style.paint(style.color.withValues(alpha: depth)));
    }
  }

  /// Светлая грань рядом с линией. Ярче там, где рельеф глубже.
  void _paintShine(Canvas canvas, Path path, _ReliefStyle style, double depth) {
    final shine = style.paint(Colors.white.withValues(alpha: style.shine * depth / 0.9));
    canvas
      ..save()
      ..translate(style.shineShift.dx, style.shineShift.dy)
      ..drawPath(path, shine)
      ..restore();
  }

  void _paintClothes(Canvas canvas) {
    _fillCloth(canvas, layers.bottom, look.bottomColor);
    final top = layers.top;
    if (top != null) _fillCloth(canvas, top, look.topColor, withFall: true);
    for (final sleeve in layers.sleeves) {
      _fillCloth(canvas, sleeve, look.topColor, withFall: true);
    }
    final sneakers = look.sneakersColor;
    if (sneakers != null) {
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
  }

  void _paintHead(Canvas canvas) {
    _fillSkin(canvas, Path()..addRect(Rect.fromLTRB(100 - frame.neck, 46, 100 + frame.neck, 64)));
    _fillSkin(
      canvas,
      Path()
        ..addOval(Rect.fromCenter(
            center: BodyFrame.headCenter, width: frame.headRx * 2, height: frame.headRy * 2)),
    );
    _fillSolid(canvas, layers.headband, look.accessoryColor);
    _fillSolid(canvas, layers.hairFront, look.hairColor);
  }

  // ---------- Заливки ----------

  static const _figureBounds = Rect.fromLTWH(0, 0, avatarCanvasWidth, avatarCanvasHeight);

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

  void _fillCloth(Canvas canvas, Path path, Color color, {bool withFall = false}) {
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
      colors: [Color(0x6B000000), Color(0x00000000), Color(0x0DFFFFFF), Color(0x6B000000)],
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
  bool shouldRepaint(AvatarPainter old) => old.look != look || !mapEquals(old.levels, levels);
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
