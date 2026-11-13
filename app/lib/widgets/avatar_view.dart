import 'dart:math';

import 'package:flutter/material.dart';

import '../game/body_part.dart';

/// Временный аватар: пропорции фигуры зависят от уровней частей тела.
/// Позже его заменит модель в Rive с теми же шестью параметрами.
class AvatarView extends StatelessWidget {
  const AvatarView({super.key, required this.levels, this.lagging = const []});

  final Map<BodyPart, int> levels;
  final List<BodyPart> lagging;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
      builder: (context, t, _) => CustomPaint(
        painter: _AvatarPainter(levels: levels, lagging: lagging, appear: t),
        size: Size.infinite,
      ),
    );
  }
}

class _AvatarPainter extends CustomPainter {
  _AvatarPainter({
    required this.levels,
    required this.lagging,
    required this.appear,
  });

  final Map<BodyPart, int> levels;
  final List<BodyPart> lagging;
  final double appear;

  /// Плавное насыщение: рост заметен на первых уровнях и замедляется к 40+.
  double _g(BodyPart p) => 1 - exp(-((levels[p] ?? 1) - 1) / 15);

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final cx = size.width / 2;
    final u = h / 100; // условная единица

    final chest = _g(BodyPart.chest);
    final back = _g(BodyPart.back);
    final arms = _g(BodyPart.arms);
    final legs = _g(BodyPart.legs);
    final core = _g(BodyPart.core);
    final cardio = _g(BodyPart.cardio);

    final shoulderHalf = (13 + 6 * back + 3 * chest) * u;
    final chestDepth = (2 + 4 * chest) * u;
    final waistHalf = (9.5 - 2 * cardio - 1 * core + 0.5 * chest) * u;
    final armW = (3.2 + 3 * arms) * u;
    final legW = (4.5 + 3.5 * legs) * u;

    final top = 6 * u;
    final headR = 7 * u;
    final neckY = top + headR * 2 + 1 * u;
    final shoulderY = neckY + 3 * u;
    final waistY = shoulderY + 30 * u;
    final hipY = waistY + 6 * u;
    final footY = 97 * u;

    Paint fill(BodyPart p) {
      final isLag = lagging.contains(p);
      return Paint()
        ..color = Color.lerp(
          const Color(0xFF3A3F48),
          p.color,
          isLag ? 0.55 : 0.18,
        )!.withValues(alpha: appear);
    }

    final outline = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = Colors.white.withValues(alpha: 0.12 * appear);

    // Ноги
    for (final s in [-1, 1]) {
      final x = cx + s * (waistHalf * 0.55);
      final r = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, (hipY + footY) / 2),
          width: legW * 2,
          height: footY - hipY + 4 * u,
        ),
        Radius.circular(legW),
      );
      canvas.drawRRect(r, fill(BodyPart.legs));
      canvas.drawRRect(r, outline);
    }

    // Руки
    for (final s in [-1, 1]) {
      final x = cx + s * (shoulderHalf + armW * 0.35);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTRB(x - armW, shoulderY, x + armW, waistY + 10 * u),
        Radius.circular(armW),
      );
      canvas.drawRRect(r, fill(BodyPart.arms));
      canvas.drawRRect(r, outline);
    }

    // Торс (спина задаёт ширину плеч)
    final torso = Path()
      ..moveTo(cx - shoulderHalf, shoulderY + 2 * u)
      ..quadraticBezierTo(
        cx - shoulderHalf,
        shoulderY - 2 * u,
        cx - 5 * u,
        shoulderY - 2 * u,
      )
      ..lineTo(cx + 5 * u, shoulderY - 2 * u)
      ..quadraticBezierTo(
        cx + shoulderHalf,
        shoulderY - 2 * u,
        cx + shoulderHalf,
        shoulderY + 2 * u,
      )
      ..quadraticBezierTo(
        cx + shoulderHalf - 2 * u,
        waistY - 8 * u,
        cx + waistHalf,
        waistY,
      )
      ..lineTo(cx + waistHalf + 1 * u, hipY)
      ..lineTo(cx - waistHalf - 1 * u, hipY)
      ..lineTo(cx - waistHalf, waistY)
      ..quadraticBezierTo(
        cx - shoulderHalf + 2 * u,
        waistY - 8 * u,
        cx - shoulderHalf,
        shoulderY + 2 * u,
      )
      ..close();
    canvas.drawPath(torso, fill(BodyPart.back));
    canvas.drawPath(torso, outline);

    // Грудь
    for (final s in [-1, 1]) {
      final r = Rect.fromCenter(
        center: Offset(cx + s * shoulderHalf * 0.38, shoulderY + 7 * u),
        width: shoulderHalf * 0.72,
        height: 6 * u + chestDepth,
      );
      canvas.drawOval(r, fill(BodyPart.chest));
    }

    // Пресс: кубики проявляются с уровнем
    final absPaint = fill(BodyPart.core);
    final absAlpha = 0.25 + 0.75 * core;
    for (var row = 0; row < 3; row++) {
      for (final s in [-1, 1]) {
        final r = RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(
              cx + s * 2.6 * u,
              shoulderY + 17 * u + row * 5.2 * u,
            ),
            width: 4.4 * u,
            height: 4.4 * u,
          ),
          Radius.circular(1.4 * u),
        );
        canvas.drawRRect(
          r,
          absPaint..color = absPaint.color.withValues(alpha: absAlpha * appear),
        );
      }
    }

    // Голова и шея
    final skin = Paint()
      ..color = const Color(0xFF4A505A).withValues(alpha: appear);
    canvas.drawRect(
      Rect.fromLTRB(cx - 3 * u, neckY - 2 * u, cx + 3 * u, shoulderY),
      skin,
    );
    canvas.drawCircle(Offset(cx, top + headR), headR, skin);

    // Пульс кардио: свечение вокруг сердца
    final heart = Paint()
      ..color = BodyPart.cardio.color.withValues(
        alpha: (0.25 + 0.6 * cardio) * appear,
      )
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);
    canvas.drawCircle(
      Offset(cx - 3 * u, shoulderY + 8 * u),
      (1.5 + 2 * cardio) * u,
      heart,
    );
  }

  @override
  bool shouldRepaint(_AvatarPainter old) =>
      old.levels != levels || old.lagging != lagging || old.appear != appear;
}
