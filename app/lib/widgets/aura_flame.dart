import 'dart:math';

import 'package:flutter/material.dart';

import '../game/aura.dart';

/// Пламя ауры за героем: языки огня поднимаются по силуэту выше головы и мерцают.
/// Ставится в Stack ПЕРЕД героем, чтобы фигура оставалась видна.
/// [burst] — разовая вспышка (скорость, фокус): ярко загорается и гаснет.
class AuraFlame extends StatefulWidget {
  const AuraFlame({super.key, required this.kind, this.burst = false});

  final AuraKind kind;
  final bool burst;

  @override
  State<AuraFlame> createState() => _AuraFlameState();
}

class _AuraFlameState extends State<AuraFlame>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: widget.burst
        ? const Duration(milliseconds: 650)
        : const Duration(milliseconds: 1400),
  );

  @override
  void initState() {
    super.initState();
    widget.burst ? _c.forward() : _c.repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) => CustomPaint(
        painter: _FlamePainter(
          kind: widget.kind,
          t: _c.value,
          burst: widget.burst,
        ),
      ),
    ),
  );
}

class _FlamePainter extends CustomPainter {
  _FlamePainter({required this.kind, required this.t, required this.burst});

  final AuraKind kind;
  final double t;
  final bool burst;

  /// Языки пламени вокруг силуэта: смещение по ширине, где начинается
  /// (доля высоты снизу вверх), длина (доля высоты), фаза колыхания.
  static const _tongues = [
    (-0.30, 0.02, 0.70, 0.0),
    (0.30, 0.02, 0.70, 0.5),
    (-0.34, 0.25, 0.62, 0.3),
    (0.34, 0.25, 0.62, 0.8),
    (-0.30, 0.48, 0.52, 0.6),
    (0.30, 0.48, 0.52, 0.1),
    (-0.18, 0.66, 0.40, 0.9),
    (0.18, 0.66, 0.40, 0.4),
    (0.0, 0.74, 0.30, 0.2),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Вспышка: быстро разгорается и гаснет; длительная — ровно мерцает.
    final strength = burst ? sin(t * pi) : 0.8 + 0.2 * sin(t * 2 * pi);
    if (strength <= 0.01) return;
    final cx = size.width / 2;
    final h = size.height;

    // Свечение вокруг силуэта.
    final glowRect = Rect.fromCenter(
      center: Offset(cx, h * 0.5),
      width: size.width * 0.9,
      height: h * 1.0,
    );
    canvas.drawOval(
      glowRect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            kind.color.withValues(alpha: 0.38 * strength),
            kind.color.withValues(alpha: 0),
          ],
        ).createShader(glowRect),
    );

    // Узкие языки — по контуру тела, вверх и выше головы (за героем).
    for (final (dx, from, len, phase) in _tongues) {
      final wave = sin((t + phase) * 2 * pi);
      final grow = burst ? 0.7 + 0.3 * t : 1.0;
      final x = cx + dx * size.width;
      final base = h * (0.99 - from);
      final top = base - h * len * grow * (0.88 + 0.12 * wave);
      final w = size.width * 0.085;
      final sway = wave * size.width * 0.035;
      final path = Path()
        ..moveTo(x - w, base)
        ..cubicTo(
          x - w * 1.2,
          base - (base - top) * 0.4,
          x - w * 0.15 + sway,
          top + (base - top) * 0.3,
          x + sway * 1.8,
          top,
        )
        ..cubicTo(
          x + w * 0.15 + sway,
          top + (base - top) * 0.3,
          x + w * 1.2,
          base - (base - top) * 0.4,
          x + w,
          base,
        )
        ..close();
      final rect = Rect.fromLTRB(x - w, top, x + w, base);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.bottomCenter,
            end: Alignment.topCenter,
            // Основание растворяется — без резкой кромки у языков с середины тела.
            colors: [
              kind.glow.withValues(alpha: 0),
              kind.glow.withValues(alpha: 0.85 * strength),
              kind.color.withValues(alpha: 0.75 * strength),
              kind.color.withValues(alpha: 0),
            ],
            stops: const [0, 0.18, 0.55, 1],
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_FlamePainter old) => old.t != t || old.kind != kind;
}
