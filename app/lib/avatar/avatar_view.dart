import 'package:flutter/material.dart';

import '../game/body_part.dart';
import '../game/muscles.dart';
import 'avatar_look.dart';
import 'avatar_painter.dart';
import 'body_frame.dart';

/// Аватар героя. Пропорции из уровней, внешний вид из образа.
class AvatarView extends StatelessWidget {
  const AvatarView({
    super.key,
    required this.levels,
    required this.look,
    this.withLamp = false,
    this.muscles = const {},
    this.pose = AvatarPose.relaxed,
    this.poseT = 0,
  });

  /// Поза и доля входа в неё (avatar/posing_avatar.dart анимирует).
  final AvatarPose pose;
  final double poseT;

  final Map<BodyPart, num> levels;
  final AvatarLook look;

  /// Конус света сверху, как от лампы над помостом. Для главного экрана.
  final bool withLamp;

  /// Очки мышц героя (MuscleMath); у соперников и на «Старте» — пусто.
  final MusclePoints muscles;

  @override
  Widget build(BuildContext context) {
    // Свой слой: аватар не перерисовывается, когда меняется что-то рядом
    // (таймер, анимация кнопки, прокрутка соседнего списка).
    final avatar = RepaintBoundary(
      child: CustomPaint(
        painter: AvatarPainter(
          levels: levels,
          look: look,
          muscles: muscles,
          pose: pose,
          poseT: poseT,
        ),
        size: Size.infinite,
      ),
    );
    if (!withLamp) return avatar;
    return Stack(
      fit: StackFit.expand,
      children: [
        const RepaintBoundary(child: CustomPaint(painter: _LampPainter())),
        avatar,
      ],
    );
  }
}

class _LampPainter extends CustomPainter {
  const _LampPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cone = Path()
      ..moveTo(cx - size.width * 0.1, 0)
      ..lineTo(cx + size.width * 0.1, 0)
      ..lineTo(cx + size.width * 0.38, size.height)
      ..lineTo(cx - size.width * 0.38, size.height)
      ..close();
    canvas.drawPath(
      cone,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x12FFFFFF), Color(0x00FFFFFF)],
        ).createShader(Offset.zero & size),
    );
  }

  @override
  bool shouldRepaint(_LampPainter oldDelegate) => false;
}
