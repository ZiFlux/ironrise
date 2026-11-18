import 'package:flutter/material.dart';

import 'skeleton.dart';

/// Отладочный рисунок скелета: кости — сужающиеся «спицы», суставы — точки.
/// Цвет по цепочке: позвоночник, руки, ноги. Нужен для листа рендеров и
/// проверки поз, в приложении не показывается.
class SkeletonPainter extends CustomPainter {
  const SkeletonPainter(this.skeleton, {this.ghost});

  final PosedSkeleton skeleton;

  /// Скелет в покое — бледной тенью под позой.
  final PosedSkeleton? ghost;

  static const _spine = Color(0xFFF3EAEC);
  static const _arm = Color(0xFFFF6B4A);
  static const _leg = Color(0xFF3CC6B4);

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 400);
    if (ghost != null) _draw(canvas, ghost!, 0.18);
    _draw(canvas, skeleton, 1);
  }

  void _draw(Canvas canvas, PosedSkeleton s, double alpha) {
    for (final b in Bone.values) {
      final a = s[b.from], z = s[b.to];
      final color = switch (b.name) {
        final n when n.contains('Arm') || n.contains('hand') => _arm,
        final n when n.contains('clavicle') || n.contains('forearm') => _arm,
        final n when n.contains('thigh') || n.contains('shin') => _leg,
        final n
            when n.contains('foot') ||
                n.contains('pelvis') && b.side != Side.center =>
          _leg,
        _ => _spine,
      }.withValues(alpha: alpha);
      final d = z - a;
      if (d.distance == 0) continue;
      final n = Offset(-d.dy, d.dx) / d.distance;
      final w = (d.distance * 0.08).clamp(1.5, 5.0);
      canvas.drawPath(
        Path()
          ..moveTo(a.dx + n.dx * w, a.dy + n.dy * w)
          ..lineTo(z.dx, z.dy)
          ..lineTo(a.dx - n.dx * w, a.dy - n.dy * w)
          ..close(),
        Paint()..color = color.withValues(alpha: alpha * 0.85),
      );
    }
    for (final j in Joint.values) {
      canvas.drawCircle(
        s[j],
        2.4,
        Paint()..color = Colors.white.withValues(alpha: alpha),
      );
    }
  }

  @override
  bool shouldRepaint(SkeletonPainter old) => true;
}
