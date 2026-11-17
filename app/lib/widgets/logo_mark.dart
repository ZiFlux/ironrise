import 'package:flutter/material.dart';

import '../theme.dart';

/// Знак IronRise (стиль «Кузня», 17.11.2026): шестигранная печать-гайка с
/// монограммой IR. Рисуется путями, без шрифта — одинаково в приложении и иконке.
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 64, this.filled = false});

  final double size;

  /// Залитая печать (как иконка приложения); иначе — контур акцентом.
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      label: 'IronRise',
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: LogoPainter(
            accent: scheme.primary,
            letters: filled ? scheme.onPrimary : AppColors.textPrimary,
            filled: filled,
          ),
        ),
      ),
    );
  }
}

/// Отрисовка знака в квадрате; общий для виджета и генерации иконок.
class LogoPainter extends CustomPainter {
  const LogoPainter({
    required this.accent,
    required this.letters,
    this.filled = false,
  });

  final Color accent;
  final Color letters;
  final bool filled;

  /// Шестигранник в координатах 64×64.
  static Path hexagon(double u) => Path()
    ..moveTo(32 * u, 4 * u)
    ..lineTo(57 * u, 18 * u)
    ..lineTo(57 * u, 46 * u)
    ..lineTo(32 * u, 60 * u)
    ..lineTo(7 * u, 46 * u)
    ..lineTo(7 * u, 18 * u)
    ..close();

  /// Монограмма IR: штамп I и R с «ногой» в координатах 64×64.
  static Path monogram(double u) => Path()
    // I — сплошная стойка.
    ..moveTo(21.5 * u, 22 * u)
    ..lineTo(21.5 * u, 43 * u)
    // R — своя стойка, чаша и нога.
    ..moveTo(30.5 * u, 43 * u)
    ..lineTo(30.5 * u, 22 * u)
    ..lineTo(38 * u, 22 * u)
    ..arcToPoint(Offset(38 * u, 33.5 * u), radius: Radius.circular(5.75 * u))
    ..lineTo(30.5 * u, 33.5 * u)
    ..moveTo(36 * u, 33.5 * u)
    ..lineTo(43 * u, 43 * u);

  @override
  void paint(Canvas canvas, Size size) {
    final u = size.width / 64;
    final hex = hexagon(u);
    if (filled) {
      canvas.drawPath(hex, Paint()..color = accent);
    } else {
      canvas.drawPath(
        hex,
        Paint()
          ..color = accent
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3.5 * u
          ..strokeJoin = StrokeJoin.round,
      );
    }
    canvas.drawPath(
      monogram(u),
      Paint()
        ..color = letters
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5 * u
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(LogoPainter old) =>
      old.accent != accent || old.letters != letters || old.filled != filled;
}
