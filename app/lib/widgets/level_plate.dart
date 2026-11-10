import 'dart:math';

import 'package:flutter/material.dart';

import '../game/body_part.dart';
import '../game/progression.dart';
import '../theme.dart';

/// Фирменная деталь: уровень части тела как блин штанги.
/// Кольцо прогресса из трёх сегментов, уровень в центре.
class LevelPlate extends StatelessWidget {
  const LevelPlate({super.key, required this.part, required this.xp, this.lagging = false});

  final BodyPart part;
  final int xp;
  final bool lagging;

  @override
  Widget build(BuildContext context) {
    final level = Progression.levelFromXp(xp);
    final progress = Progression.levelProgress(xp);
    return Semantics(
      label: '${part.label}, уровень $level, ${(progress * 100).round()} из 100 опыта',
      child: Container(
        padding: const EdgeInsets.fromLTRB(0, 12, 0, 10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.hairline),
        ),
        child: Column(
          children: [
            SizedBox.square(
              dimension: 56,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: AppMotion.enter,
                curve: AppMotion.curve,
                builder: (_, value, _) => CustomPaint(
                  painter: _PlatePainter(progress: value, color: part.color),
                  child: Center(child: Text('$level', style: figureStyle())),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              part.label,
              style: TextStyle(
                fontSize: 13,
                color: lagging ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _strokeWidth = 7.0;
  static const _gripSlots = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2 - _strokeWidth / 2 - 1;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = _strokeWidth;

    canvas.drawCircle(center, radius, ring..color = AppColors.raised);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * progress,
      false,
      ring..color = color,
    );
    _cutGripSlots(canvas, center, radius);
  }

  /// Три прорези, как хваты у олимпийского диска.
  void _cutGripSlots(Canvas canvas, Offset center, double radius) {
    final slot = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 2.5;
    for (var i = 0; i < _gripSlots; i++) {
      final angle = -pi / 2 + i * 2 * pi / _gripSlots;
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * (radius - _strokeWidth / 2 - 0.5),
        center + direction * (radius + _strokeWidth / 2 + 0.5),
        slot,
      );
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.progress != progress || old.color != color;
}
