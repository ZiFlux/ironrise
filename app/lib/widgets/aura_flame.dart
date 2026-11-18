import 'dart:math';

import 'package:flutter/material.dart';

import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../game/aura.dart';

/// Иконка ауры по смыслу: ярость — пламя, стойкость — щит, скорость — молния,
/// фокус — глаз. Общий знак «аур» (без конкретной) — волшебная палочка.
IconData auraIcon(AuraKind? kind) => switch (kind) {
  AuraKind.fury => LucideIcons.flame,
  AuraKind.guard => LucideIcons.shield,
  AuraKind.haste => LucideIcons.zap,
  AuraKind.focus => LucideIcons.eye,
  null => LucideIcons.wandSparkles,
};

/// Герой с аурой: часть эффекта за фигурой (пламя, свечение, туман), часть —
/// поверх (молнии, кромка щита, руны). [burst] — разовая аура: вспыхивает ярче.
class AuraHero extends StatelessWidget {
  const AuraHero({
    super.key,
    required this.child,
    required this.kind,
    this.burst = false,
    this.level = 1,
  });

  final Widget child;
  final AuraKind? kind;
  final bool burst;

  /// Уровень ауры 1–5: чем выше, тем богаче эффект (больше пламени, рун, молний,
  /// искры и кольца на старших уровнях).
  final int level;

  @override
  Widget build(BuildContext context) {
    final k = kind;
    if (k == null) return child;
    return Stack(
      fit: StackFit.expand,
      children: [
        AuraFlame(kind: k, burst: burst, level: level),
        child,
        AuraFlame(kind: k, burst: burst, level: level, front: true),
      ],
    );
  }
}

/// Эффект ауры. Сзади: ярость — пламя, стойкость — свечение щита, скорость —
/// синее сияние, фокус — фиолетовый туман. Спереди ([front]): кромка щита
/// с сотами, молнии, кружащиеся руны.
class AuraFlame extends StatefulWidget {
  const AuraFlame({
    super.key,
    required this.kind,
    this.burst = false,
    this.front = false,
    this.level = 1,
  });

  final AuraKind kind;
  final bool burst;
  final bool front;
  final int level;

  @override
  State<AuraFlame> createState() => _AuraFlameState();
}

class _AuraFlameState extends State<AuraFlame>
    with SingleTickerProviderStateMixin {
  // Анимация идёт по кругу; вспышка лишь ярче в первые мгновения.
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat();
  final _born = DateTime.now();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: AnimatedBuilder(
      animation: _c,
      builder: (_, _) {
        final age = DateTime.now().difference(_born).inMilliseconds / 1000;
        return CustomPaint(
          painter: _AuraPainter(
            kind: widget.kind,
            t: _c.value,
            // Вспышка: первые 0,4 с ярче, дальше ровно горит до конца хода.
            flare: widget.burst ? (1 - age / 0.4).clamp(0.0, 1.0) : 0,
            front: widget.front,
            level: widget.level.clamp(1, 5),
          ),
        );
      },
    ),
  );
}

class _AuraPainter extends CustomPainter {
  _AuraPainter({
    required this.kind,
    required this.t,
    required this.flare,
    required this.front,
    this.level = 1,
  });

  final AuraKind kind;
  final double t;
  final double flare;
  final bool front;

  /// 1–5: насыщенность эффекта и новые слои на старших уровнях.
  final int level;

  /// Яркость растёт с уровнем: 1-й — сдержанно, 5-й — в полную силу.
  double get _lv => 0.7 + 0.075 * level;

  double get _pulse => (0.82 + 0.18 * sin(t * 2 * pi) + 0.35 * flare) * _lv;

  @override
  void paint(Canvas canvas, Size size) {
    switch (kind) {
      case AuraKind.fury:
        if (!front) _flames(canvas, size);
        // 5-й уровень: искры летят вверх перед героем.
        if (front && level >= 5) _motes(canvas, size, rise: true, count: 14);
      case AuraKind.guard:
        if (front) {
          _shieldRim(canvas, size);
          if (level >= 5) _motes(canvas, size, rise: false, count: 10);
        } else {
          _glow(canvas, size, 0.22);
          if (level >= 5) _groundRing(canvas, size);
        }
      case AuraKind.haste:
        if (front) {
          _lightning(canvas, size);
        } else {
          _glow(canvas, size, 0.4);
          if (level >= 5) _speedLines(canvas, size);
        }
      case AuraKind.focus:
        if (front) {
          _runes(canvas, size);
          if (level >= 5) _motes(canvas, size, rise: true, count: 10);
        } else {
          _mist(canvas, size);
        }
    }
  }

  void _glow(Canvas canvas, Size size, double alpha) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.5),
      width: size.width * 0.95,
      height: size.height,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..shader = RadialGradient(
          colors: [
            kind.color.withValues(alpha: alpha * _pulse.clamp(0.0, 1.0)),
            kind.color.withValues(alpha: 0),
          ],
        ).createShader(rect),
    );
  }

  // ---------- Ярость: языки пламени за героем ----------

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

  void _flames(Canvas canvas, Size size) {
    _glow(canvas, size, 0.38);
    final cx = size.width / 2;
    final h = size.height;
    final strength = _pulse.clamp(0.0, 1.0);
    // 1-й уровень — 5 языков, каждый следующий добавляет пару, до всех 9.
    final tongues = _tongues.take((3 + 2 * level).clamp(5, _tongues.length));
    for (final (dx, from, len, phase) in tongues) {
      final wave = sin((t * 2 + phase) * 2 * pi);
      final x = cx + dx * size.width;
      final base = h * (0.99 - from);
      final top = base - h * len * (0.88 + 0.12 * wave) * (1 + 0.15 * flare);
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
            colors: [
              kind.glow.withValues(alpha: 0),
              kind.glow.withValues(alpha: 0.85 * strength),
              kind.color.withValues(alpha: 0.75 * strength),
              kind.color.withValues(alpha: 0),
            ],
            stops: const [0, 0.18, 0.55, 1],
          ).createShader(rect),
      );
      // 4-й уровень и выше: белое раскалённое ядро внутри языка.
      if (level >= 4) {
        final core = Rect.fromLTRB(
          x - w * 0.4,
          top + (base - top) * 0.3,
          x + w * 0.4,
          base,
        );
        canvas.drawOval(
          core,
          Paint()
            ..shader = LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Colors.white.withValues(alpha: 0),
                Colors.white.withValues(alpha: 0.45 * strength),
                kind.glow.withValues(alpha: 0),
              ],
            ).createShader(core),
        );
      }
    }
  }

  // ---------- Стойкость: щит-купол с сотами ----------

  void _shieldRim(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.52),
      width: size.width * 0.92,
      height: size.height * 0.98,
    );
    final dome = Path()..addOval(rect);
    final p = _pulse.clamp(0.0, 1.0);
    // Полупрозрачная заливка: у края плотнее, как у мыльного пузыря.
    canvas.drawPath(
      dome,
      Paint()
        ..shader = RadialGradient(
          colors: [
            kind.color.withValues(alpha: 0),
            kind.color.withValues(alpha: 0.2 * p),
          ],
          stops: const [0.75, 1],
        ).createShader(rect),
    );
    // Соты внутри купола медленно плывут вниз — со 2-го уровня.
    if (level >= 2) {
      canvas.save();
      canvas.clipPath(dome);
      final hexPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = kind.glow.withValues(alpha: 0.14 * p);
      final r = size.width * 0.13;
      final dy = r * sqrt(3);
      for (var row = -2; row * dy < size.height + dy; row++) {
        for (var col = -1; col * r * 1.5 < size.width + r; col++) {
          final c = Offset(
            col * r * 1.5,
            row * dy + (col.isOdd ? dy / 2 : 0) + t * dy,
          );
          final hex = Path();
          for (var i = 0; i < 6; i++) {
            final a = pi / 3 * i;
            final v = c + Offset(cos(a), sin(a)) * r;
            i == 0 ? hex.moveTo(v.dx, v.dy) : hex.lineTo(v.dx, v.dy);
          }
          canvas.drawPath(hex..close(), hexPaint);
        }
      }
      canvas.restore();
    }
    // 3-й уровень: вторая, внутренняя кромка.
    if (level >= 3) {
      canvas.drawOval(
        rect.deflate(size.width * 0.04),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = kind.glow.withValues(alpha: 0.35 * p),
      );
    }
    // 4-й уровень: огни бегут по краю купола.
    if (level >= 4) {
      for (var i = 0; i < 3; i++) {
        final a = t * 2 * pi + i * 2 * pi / 3;
        final o = Offset(
          rect.center.dx + cos(a) * rect.width / 2,
          rect.center.dy + sin(a) * rect.height / 2,
        );
        canvas.drawCircle(
          o,
          size.width * 0.06,
          Paint()
            ..shader =
                RadialGradient(
                  colors: [
                    Colors.white.withValues(alpha: 0.9 * p),
                    kind.glow.withValues(alpha: 0),
                  ],
                ).createShader(
                  Rect.fromCircle(center: o, radius: size.width * 0.06),
                ),
        );
      }
    }
    // Яркая кромка.
    canvas.drawPath(
      dome,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..color = kind.glow.withValues(alpha: 0.75 * p),
    );
  }

  // ---------- Скорость: синие молнии ----------

  void _lightning(Canvas canvas, Size size) {
    // Рисунок молний меняется ~8 раз в секунду.
    final frame = (t * 13).floor();
    final rnd = Random(frame * 7919 + 17);
    final bolt = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final count = 1 + level + (flare > 0 ? 3 : 0);
    final thick = level >= 4 ? 1.4 : 1.0;
    for (var b = 0; b < count; b++) {
      final side = b.isEven ? -1 : 1;
      final x0 = size.width * (0.5 + side * (0.24 + rnd.nextDouble() * 0.18));
      final y0 = size.height * (0.05 + rnd.nextDouble() * 0.6);
      final path = Path()..moveTo(x0, y0);
      var p = Offset(x0, y0);
      final steps = 5 + rnd.nextInt(3);
      for (var s = 0; s < steps; s++) {
        p += Offset(
          (rnd.nextDouble() - 0.5) * size.width * 0.12,
          size.height * (0.03 + rnd.nextDouble() * 0.04),
        );
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        bolt
          ..strokeWidth = 5 * thick
          ..color = kind.color.withValues(alpha: 0.4),
      );
      canvas.drawPath(
        path,
        bolt
          ..strokeWidth = 1.8 * thick
          ..color = kind.glow.withValues(alpha: 0.95),
      );
      // 4-й уровень: искра на конце молнии.
      if (level >= 4) {
        canvas.drawCircle(
          p,
          size.width * 0.025,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }
  }

  // ---------- Фокус: туман и руны ----------

  void _mist(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final p = _pulse.clamp(0.0, 1.0);
    for (var i = 0; i < 5; i++) {
      final a = t * 2 * pi + i * 2 * pi / 5;
      final c = Offset(
        cx + cos(a) * size.width * 0.22,
        size.height * (0.55 + 0.25 * sin(a * 0.7 + i)),
      );
      final r = size.width * (0.32 + 0.06 * sin(a * 2));
      final rect = Rect.fromCircle(center: c, radius: r);
      canvas.drawCircle(
        c,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              kind.color.withValues(alpha: 0.28 * p),
              kind.color.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }
  }

  /// Руны рисуются линиями — в шрифтах телефонов рунических знаков может не быть.
  void _rune(Canvas canvas, Offset c, double r, int kind, Paint paint) {
    final path = Path();
    switch (kind % 6) {
      case 0: // ромб с чертой
        path
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.7, c.dy)
          ..lineTo(c.dx, c.dy + r)
          ..lineTo(c.dx - r * 0.7, c.dy)
          ..close()
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx, c.dy + r);
      case 1: // стрела вверх
        path
          ..moveTo(c.dx, c.dy + r)
          ..lineTo(c.dx, c.dy - r)
          ..moveTo(c.dx - r * 0.6, c.dy - r * 0.3)
          ..lineTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.6, c.dy - r * 0.3);
      case 2: // треугольник
        path
          ..moveTo(c.dx, c.dy - r)
          ..lineTo(c.dx + r * 0.85, c.dy + r * 0.7)
          ..lineTo(c.dx - r * 0.85, c.dy + r * 0.7)
          ..close();
      case 3: // крест в круге
        path
          ..addOval(Rect.fromCircle(center: c, radius: r * 0.8))
          ..moveTo(c.dx - r * 0.8, c.dy)
          ..lineTo(c.dx + r * 0.8, c.dy)
          ..moveTo(c.dx, c.dy - r * 0.8)
          ..lineTo(c.dx, c.dy + r * 0.8);
      case 4: // «ᚠ»: ствол и две ветви
        path
          ..moveTo(c.dx - r * 0.3, c.dy + r)
          ..lineTo(c.dx - r * 0.3, c.dy - r)
          ..moveTo(c.dx - r * 0.3, c.dy - r * 0.6)
          ..lineTo(c.dx + r * 0.5, c.dy - r)
          ..moveTo(c.dx - r * 0.3, c.dy - r * 0.05)
          ..lineTo(c.dx + r * 0.5, c.dy - r * 0.45);
      default: // песочные часы
        path
          ..moveTo(c.dx - r * 0.6, c.dy - r)
          ..lineTo(c.dx + r * 0.6, c.dy - r)
          ..lineTo(c.dx - r * 0.6, c.dy + r)
          ..lineTo(c.dx + r * 0.6, c.dy + r)
          ..close();
    }
    canvas.drawPath(path, paint);
  }

  void _runes(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.48);
    final rx = size.width * 0.42;
    final ry = size.height * 0.16;
    // 1-й уровень — 4 руны, каждый следующий добавляет по одной (до 8).
    final runes = 3 + level;
    _runeRing(canvas, size, c, rx, ry, runes, t);
    // 4-й уровень: второе кольцо рун ниже и навстречу первому.
    if (level >= 4) {
      _runeRing(
        canvas,
        size,
        c + Offset(0, size.height * 0.2),
        rx * 0.8,
        ry * 0.8,
        runes - 2,
        -t,
      );
    }
    if (level < 2) return;
    _eye(canvas, size);
  }

  void _runeRing(
    Canvas canvas,
    Size size,
    Offset c,
    double rx,
    double ry,
    int n,
    double t,
  ) {
    for (var i = 0; i < n; i++) {
      final a = t * 2 * pi + i * 2 * pi / n;
      // Руны кружат по эллипсу; дальние — тусклее.
      final depth = (sin(a) + 1) / 2;
      final p = c + Offset(cos(a) * rx, sin(a) * ry);
      final r = size.width * 0.04;
      _rune(
        canvas,
        p,
        r,
        i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 4
          ..color = kind.color.withValues(alpha: 0.35 * (0.4 + 0.6 * depth)),
      );
      _rune(
        canvas,
        p,
        r,
        i,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.4
          ..strokeCap = StrokeCap.round
          ..color = kind.glow.withValues(alpha: 0.35 + 0.6 * depth),
      );
    }
  }

  /// «Глаз» над головой — знак фокуса (со 2-го уровня).
  void _eye(Canvas canvas, Size size) {
    final eye = Offset(size.width / 2, size.height * 0.03 + 6);
    final ew = size.width * 0.11;
    final eyePath = Path()
      ..moveTo(eye.dx - ew, eye.dy)
      ..quadraticBezierTo(eye.dx, eye.dy - ew * 0.7, eye.dx + ew, eye.dy)
      ..quadraticBezierTo(eye.dx, eye.dy + ew * 0.7, eye.dx - ew, eye.dy)
      ..close();
    canvas.drawPath(
      eyePath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..color = kind.glow.withValues(alpha: 0.85 * _pulse.clamp(0.0, 1.0)),
    );
    canvas.drawCircle(eye, ew * 0.25, Paint()..color = kind.glow);
  }

  // ---------- Старшие уровни: искры, кольцо у ног, линии скорости ----------

  /// Частицы: [rise] — летят вверх (искры, светлячки), иначе мерцают на месте.
  void _motes(
    Canvas canvas,
    Size size, {
    required bool rise,
    required int count,
  }) {
    for (var i = 0; i < count; i++) {
      final seed = i * 0.6180339;
      final phase = (t + seed) % 1;
      final x = size.width * (0.2 + 0.6 * ((seed * 7.13) % 1));
      final y = rise
          ? size.height * (0.95 - 0.9 * phase)
          : size.height * (0.15 + 0.7 * ((seed * 3.7) % 1));
      final fade = rise
          ? sin(phase * pi)
          : (0.5 + 0.5 * sin((t + seed) * 2 * pi));
      final r = size.width * (0.008 + 0.01 * ((seed * 5.3) % 1));
      canvas.drawCircle(
        Offset(x + sin((phase + seed) * 2 * pi) * size.width * 0.02, y),
        r,
        Paint()..color = kind.glow.withValues(alpha: 0.9 * fade),
      );
    }
  }

  /// Светящееся кольцо у ног (стойкость, 5-й уровень).
  void _groundRing(Canvas canvas, Size size) {
    final rect = Rect.fromCenter(
      center: Offset(size.width / 2, size.height * 0.97),
      width: size.width * (0.7 + 0.05 * sin(t * 2 * pi)),
      height: size.height * 0.06,
    );
    canvas.drawOval(
      rect,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = kind.glow.withValues(alpha: 0.7 * _pulse.clamp(0.0, 1.0)),
    );
  }

  /// Линии скорости за героем (скорость, 5-й уровень).
  void _speedLines(Canvas canvas, Size size) {
    final paint = Paint()
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.5;
    for (var i = 0; i < 8; i++) {
      final y = size.height * (0.1 + 0.1 * i);
      final shift = ((t * 2 + i * 0.37) % 1);
      final len = size.width * (0.15 + 0.1 * ((i * 0.53) % 1));
      final x = size.width * (1.1 - 1.2 * shift);
      paint.color = kind.glow.withValues(alpha: 0.5 * sin(shift * pi));
      canvas.drawLine(Offset(x, y), Offset(x + len, y), paint);
    }
  }

  @override
  bool shouldRepaint(_AuraPainter old) =>
      old.t != t ||
      old.kind != kind ||
      old.flare != flare ||
      old.level != level;
}
