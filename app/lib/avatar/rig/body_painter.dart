import 'package:flutter/material.dart';

import '../avatar_look.dart';
import 'body.dart';
import 'skeleton.dart';

/// Проверочный рисунок тела (этап 2.2): ровная заливка кожей, тонкая граница
/// каждой части (видно стыки) и общий контур. Свет и стиль — этап 2.4.
class RigBodyPainter extends CustomPainter {
  const RigBodyPainter(this.body, this.skin, {this.bones = false});

  final RigBody body;
  final SkinTone skin;

  /// Поверх — кости (проверить, что части сидят в суставах).
  final bool bones;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 400);
    final fill = Paint()..color = skin.lit;
    final edge = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 0.8
      ..color = skin.shade.withValues(alpha: 0.7);
    void part(Path p) {
      canvas.drawPath(p, fill);
      canvas.drawPath(p, edge);
    }

    final s = body.s;
    // Кисти выше шеи (руки за головой) — за головой, иначе руки поверх тела.
    final handsBehind =
        s[Joint.wristR].dy < s[Joint.neck].dy &&
        (s[Joint.handR].dx - s[Joint.head].dx).abs() < body.u * 0.6;
    for (final leg in [body.legR, body.legL]) {
      leg.forEach(part);
    }
    // Шея под торсом: её низ прячется под трапециями, без «воротника».
    part(body.neck);
    part(body.torso);
    if (handsBehind) {
      for (final arm in [body.armR, body.armL]) {
        arm.forEach(part);
      }
    }
    part(body.head);
    if (!handsBehind) {
      for (final arm in [body.armR, body.armL]) {
        arm.forEach(part);
      }
    }
    canvas.drawPath(
      body.silhouette,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.4
        ..color = const Color(0xFF0B0809),
    );
    if (bones) {
      final bone = Paint()
        ..color = const Color(0xFF3CC6B4)
        ..strokeWidth = 1;
      for (final b in Bone.values) {
        canvas.drawLine(s[b.from], s[b.to], bone);
      }
      for (final j in Joint.values) {
        canvas.drawCircle(s[j], 1.6, Paint()..color = Colors.white);
      }
    }
  }

  @override
  bool shouldRepaint(RigBodyPainter old) => true;
}
