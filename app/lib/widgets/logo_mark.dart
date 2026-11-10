import 'dart:math';

import 'package:flutter/material.dart';

import '../theme.dart';

/// Знак IronRise: блин штанги с буквами IR в ступице.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 64});

  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: 'IronRise',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _PlatePainter(accent: accent, hub: AppColors.background),
          child: Center(
            child: Text('IR', style: figureStyle(size: size * 0.195, color: accent)),
          ),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.accent, required this.hub});

  final Color accent;
  final Color hub;

  @override
  void paint(Canvas canvas, Size size) {
    final unit = size.width / 64;
    final center = size.center(Offset.zero);
    canvas
      ..drawCircle(center, 30 * unit, Paint()..color = accent)
      ..drawCircle(center, 15 * unit, Paint()..color = hub);
    final slotPaint = Paint()..color = hub;
    for (var i = 0; i < 3; i++) {
      canvas
        ..save()
        ..translate(center.dx, center.dy)
        ..rotate(i * 2 * pi / 3);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(0, -22.75 * unit), width: 8 * unit, height: 4.5 * unit),
          Radius.circular(2.25 * unit),
        ),
        slotPaint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) => old.accent != accent || old.hub != hub;
}
