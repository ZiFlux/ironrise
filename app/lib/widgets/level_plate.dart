import 'dart:math';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/body_part.dart';
import '../game/progression.dart';
import '../theme.dart';

/// Фирменная деталь: уровень части тела как блин штанги.
/// Кольцо прогресса из трёх сегментов, уровень в центре.
class LevelPlate extends StatelessWidget {
  const LevelPlate({
    super.key,
    required this.part,
    required this.xp,
    this.lagging = false,
    this.compact = false,
    this.onTap,
    this.hot = false,
  });

  /// Часть, которую сейчас качают чаще всего: огонёк и тёплое свечение кольца.
  final bool hot;

  final BodyPart part;
  final int xp;
  final bool lagging;

  /// Узкая плитка для строки из шести на главной.
  final bool compact;

  /// Нажатие — меню части тела (widgets/body_part_sheet.dart).
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final level = Progression.levelFromXp(xp);
    final progress = Progression.levelProgress(xp);
    return Semantics(
      button: onTap != null,
      label:
          '${part.label}, уровень $level, ${(progress * 100).round()} из 100 опыта'
          '${hot ? ', сейчас в фокусе' : ''}',
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Container(
          padding: compact
              ? const EdgeInsets.fromLTRB(0, 8, 0, 6)
              : const EdgeInsets.fromLTRB(0, 12, 0, 10),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.hairline),
          ),
          child: Column(
            children: [
              SizedBox.square(
                dimension: compact ? 40 : 56,
                child: _HotGlow(
                  hot: hot,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: progress),
                    duration: AppMotion.enter,
                    curve: AppMotion.curve,
                    builder: (_, value, _) => CustomPaint(
                      painter: _PlatePainter(
                        progress: value,
                        color: part.color,
                      ),
                      child: Center(
                        child: Text(
                          '$level',
                          style: compact
                              ? figureStyle(size: 15)
                              : figureStyle(),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SizedBox(height: compact ? 4 : 6),
              Text(
                part.label,
                maxLines: 1,
                overflow: TextOverflow.fade,
                softWrap: false,
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  color: lagging
                      ? AppColors.textPrimary
                      : AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlatePainter extends CustomPainter {
  const _PlatePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  // 7 px при плитке 56 px, на компактной тоньше.
  static const _strokeRatio = 0.125;
  static const _gripSlots = 3;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final strokeWidth = size.width * _strokeRatio;
    final radius = size.width / 2 - strokeWidth / 2 - 1;
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final bounds = Rect.fromCircle(center: center, radius: radius);
    // Объём: свет падает сверху — верх кольца светлее, низ темнее.
    final light = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        Color.lerp(AppColors.raised, Colors.white, 0.10)!,
        Color.lerp(AppColors.raised, Colors.black, 0.35)!,
      ],
    ).createShader(bounds.inflate(strokeWidth));
    // Тень под диском.
    canvas.drawCircle(
      center.translate(0, strokeWidth * 0.35),
      radius + strokeWidth / 2,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, strokeWidth * 0.6),
    );
    canvas.drawCircle(center, radius, ring..shader = light);
    if (progress > 0) {
      ring.shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Color.lerp(color, Colors.white, 0.25)!,
          Color.lerp(color, Colors.black, 0.25)!,
        ],
      ).createShader(bounds.inflate(strokeWidth));
      canvas.drawArc(bounds, -pi / 2, 2 * pi * progress, false, ring);
    }
    // Блик по внешнему краю сверху.
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius + strokeWidth * 0.32),
      -pi * 0.85,
      pi * 0.7,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth * 0.18
        ..strokeCap = StrokeCap.round
        ..color = Colors.white.withValues(alpha: 0.16),
    );
    _cutGripSlots(canvas, center, radius, strokeWidth);
  }

  /// Три прорези, как хваты у олимпийского диска.
  void _cutGripSlots(
    Canvas canvas,
    Offset center,
    double radius,
    double strokeWidth,
  ) {
    final slot = Paint()
      ..color = AppColors.surface
      ..strokeWidth = 2.5;
    for (var i = 0; i < _gripSlots; i++) {
      final angle = -pi / 2 + i * 2 * pi / _gripSlots;
      final direction = Offset(cos(angle), sin(angle));
      canvas.drawLine(
        center + direction * (radius - strokeWidth / 2 - 0.5),
        center + direction * (radius + strokeWidth / 2 + 0.5),
        slot,
      );
    }
  }

  @override
  bool shouldRepaint(_PlatePainter old) =>
      old.progress != progress || old.color != color;
}

const _flame = Color(0xFFFF8A3D);

/// Тёплое пульсирующее свечение и огонёк над кольцом «горящей» части тела.
class _HotGlow extends StatefulWidget {
  const _HotGlow({required this.hot, required this.child});

  final bool hot;
  final Widget child;

  @override
  State<_HotGlow> createState() => _HotGlowState();
}

class _HotGlowState extends State<_HotGlow>
    with SingleTickerProviderStateMixin {
  late final _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_HotGlow old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (widget.hot && !still) {
      if (!_anim.isAnimating) _anim.repeat(reverse: true);
    } else {
      _anim.stop();
    }
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.hot) return widget.child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(
          child: AnimatedBuilder(
            animation: _anim,
            builder: (_, _) => DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _flame.withValues(alpha: 0.25 + 0.3 * _anim.value),
                    blurRadius: 8 + 8 * _anim.value,
                    spreadRadius: 0.5 + 1.5 * _anim.value,
                  ),
                ],
              ),
            ),
          ),
        ),
        Positioned.fill(child: widget.child),
        const Positioned(
          right: -5,
          top: -6,
          child: Icon(LucideIcons.flame, size: 15, color: _flame),
        ),
      ],
    );
  }
}
