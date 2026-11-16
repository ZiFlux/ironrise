import 'dart:math';

import 'package:flutter/material.dart';

import '../avatar/avatar_look.dart';
import '../avatar/avatar_painter.dart';
import '../avatar/body_frame.dart';
import '../game/body_part.dart';
import '../game/shop.dart';

/// Иконка товара — сама вещь на герое: кадр по месту, где она носится.
class ItemPreview extends StatelessWidget {
  const ItemPreview({
    super.key,
    required this.item,
    required this.base,
    this.size = 48,
  });

  final ShopItem item;

  /// Образ, на котором примеряем (нынешний образ игрока).
  final AvatarLook base;
  final double size;

  /// Ровные пропорции: превью одинаковое у всех, независимо от прокачки.
  static const _levels = {
    BodyPart.chest: 6,
    BodyPart.back: 6,
    BodyPart.arms: 6,
    BodyPart.legs: 6,
    BodyPart.core: 6,
    BodyPart.cardio: 6,
  };

  /// Участок холста 200×400 (body_frame.dart), где вещь видно.
  static Rect regionOf(ShopItem item) {
    const head = Rect.fromLTWH(62, 0, 76, 76);
    return switch (item.slot) {
      ShopSlot.hair || ShopSlot.hairColor || ShopSlot.skin => head,
      ShopSlot.top ||
      ShopSlot.topColor => const Rect.fromLTWH(38, 50, 124, 150),
      ShopSlot.bottom ||
      ShopSlot.bottomColor => const Rect.fromLTWH(48, 180, 104, 200),
      ShopSlot.sneakers ||
      ShopSlot.sneakersColor => const Rect.fromLTWH(58, 350, 84, 48),
      ShopSlot.accessory => switch (item.id) {
        'acc_gold_chain' => const Rect.fromLTWH(60, 40, 80, 80),
        'acc_wristbands' => const Rect.fromLTWH(18, 160, 164, 70),
        'acc_belt' => const Rect.fromLTWH(52, 160, 96, 70),
        'acc_knee_sleeves' => const Rect.fromLTWH(48, 260, 104, 72),
        _ => head,
      },
    };
  }

  @override
  Widget build(BuildContext context) {
    final look = item.apply(base);
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _CropPainter(
          AvatarPainter(levels: _levels, look: look),
          regionOf(item),
        ),
      ),
    );
  }
}

class _CropPainter extends CustomPainter {
  _CropPainter(this.inner, this.region);

  final AvatarPainter inner;
  final Rect region;

  @override
  void paint(Canvas canvas, Size size) {
    final s = min(size.width / region.width, size.height / region.height);
    canvas
      ..save()
      ..clipRect(Offset.zero & size)
      ..translate(
        (size.width - region.width * s) / 2,
        (size.height - region.height * s) / 2,
      )
      ..scale(s)
      ..translate(-region.left, -region.top);
    // Холст в натуральную величину: художник аватара рисует без своего масштаба.
    inner.paint(canvas, const Size(avatarCanvasWidth, avatarCanvasHeight));
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CropPainter old) =>
      old.region != region || old.inner.look != inner.look;
}
