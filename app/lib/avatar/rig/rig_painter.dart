import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../avatar_look.dart';
import 'body.dart';
import 'skeleton.dart';

/// Герой в стиле «тёмное фэнтези» (REDESIGN, этап 2): свет сверху слева,
/// три тона светотени на каждой части, мышцы — формами тени и блика,
/// мягкая тень каждой части на ту, что под ней (стык читается объёмом,
/// а не швом), контровой свет цветом стиля справа.
class RigPainter extends CustomPainter {
  RigPainter(this.body, this.skin, {required this.accent});

  final RigBody body;
  final SkinTone skin;

  /// Цвет контрового света — акцент выбранного стиля.
  final Color accent;

  /// Направление на свет (вверх-влево).
  static const _light = Offset(-0.6, -0.8);

  late final Color _hi = Color.lerp(skin.lit, Colors.white, 0.14)!;
  late final Color _mid = Color.lerp(skin.lit, skin.shade, 0.22)!;
  late final Color _lo = Color.lerp(skin.lit, skin.shade, 0.72)!;
  late final Color _deep = Color.lerp(skin.shade, Colors.black, 0.45)!;

  RigBody get b => body;
  PosedSkeleton get s => body.s;
  double get u => body.u;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 200, size.height / 400);
    _groundShadow(canvas);

    final handsBehind =
        s[Joint.wristR].dy < s[Joint.neck].dy &&
        (s[Joint.handR].dx - s[Joint.head].dx).abs() < u * 0.7;

    // Порядок: ноги, шея, торс, (руки за головой), голова, руки.
    final drawn = Path();
    void part(Path p, Shader shader, {bool shadow = true}) {
      if (shadow) _castShadow(canvas, p, drawn);
      canvas.drawPath(p, Paint()..shader = shader);
      drawn.addPath(p, Offset.zero);
    }

    for (final side in [Side.right, Side.left]) {
      final leg = side == Side.right ? b.legR : b.legL;
      final j = _legJoints(side);
      part(leg[0], _limbShader(j.hip, j.knee, 0.46));
      part(leg[1], _limbShader(j.knee, j.ankle, 0.28));
      part(leg[2], _limbShader(j.ankle, j.toe, 0.16));
    }
    part(b.neck, _limbShader(s[Joint.neck], s[Joint.head], 0.3));
    // Тень торса на бёдра закрыли бы шорты — без неё нет «зубцов» у паха.
    part(b.torso, _torsoShader(), shadow: false);
    _torsoMuscles(canvas);
    _legMuscles(canvas);

    void arms() {
      for (final side in [Side.right, Side.left]) {
        final arm = side == Side.right ? b.armR : b.armL;
        final j = _armJoints(side);
        part(arm[0], _limbShader(j.shoulder, j.elbow, 0.34));
        _upperArmMuscles(canvas, side, arm[0]);
        part(arm[1], _limbShader(j.elbow, j.wrist, 0.24));
        _forearmMuscles(canvas, side, arm[1]);
        part(arm[2], _limbShader(j.wrist, j.hand, 0.16));
        part(arm[3], _limbShader(j.shoulder, j.elbow, 0.42, shift: -0.05));
        _deltMuscles(canvas, side, arm[3]);
      }
    }

    if (handsBehind) arms();
    part(b.head, _limbShader(s[Joint.head], s[Joint.headTop], 0.38));
    _face(canvas);
    if (!handsBehind) arms();

    _clothes(canvas);
    _rimLight(canvas);
  }

  // ── Свет ──────────────────────────────────────────────────────────────

  /// Цилиндр вдоль кости: освещённый край, середина, тень, глубокая тень.
  Shader _limbShader(Offset a, Offset z, double halfK, {double shift = 0}) {
    final d = _unit(z - a);
    var n = Offset(-d.dy, d.dx);
    // Нормаль — в сторону света.
    if (n.dx * _light.dx + n.dy * _light.dy < 0) n = -n;
    final c = Offset.lerp(a, z, 0.5)! + n * shift * u;
    final w = halfK * u;
    return ui.Gradient.linear(
      c + n * w,
      c - n * w,
      [_hi, _hi, _mid, _mid, _lo, _lo, _deep],
      [0.0, 0.16, 0.26, 0.58, 0.68, 0.88, 1.0],
    );
  }

  Shader _torsoShader() {
    final c = s[Joint.chest];
    final a = b.acrossChest;
    final w = b.latHalf;
    return ui.Gradient.linear(
      c - a * w,
      c + a * w,
      [_lo, _mid, _hi, _hi, _mid, _mid, _lo, _deep],
      [0.0, 0.08, 0.2, 0.38, 0.48, 0.66, 0.8, 1.0],
    );
  }

  /// Мягкая тень части на то, что уже нарисовано под ней.
  void _castShadow(Canvas canvas, Path p, Path under) {
    canvas.save();
    canvas.clipPath(under);
    canvas.drawPath(
      p.shift(Offset(u * 0.035, u * 0.05)),
      Paint()
        ..color = _deep.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.05),
    );
    canvas.restore();
  }

  void _rimLight(Canvas canvas) {
    final sil = b.silhouette;
    // Справа — контровой цвет стиля, слева сверху — тонкий блик.
    final rim = Path.combine(
      PathOperation.difference,
      sil,
      sil.shift(Offset(-u * 0.04, u * 0.012)),
    );
    canvas.drawPath(
      rim,
      Paint()
        ..color = accent.withValues(alpha: 0.85)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.008),
    );
    final top = Path.combine(
      PathOperation.difference,
      sil,
      sil.shift(Offset(u * 0.02, u * 0.03)),
    );
    canvas.drawPath(top, Paint()..color = _hi.withValues(alpha: 0.35));
    canvas.drawPath(
      sil,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..color = Colors.black.withValues(alpha: 0.55),
    );
  }

  void _groundShadow(Canvas canvas) {
    final y = rigSoleY + 1;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(rigCenterX, y),
        width: u * 2.6,
        height: u * 0.32,
      ),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.55)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.08),
    );
  }

  // ── Мышцы ─────────────────────────────────────────────────────────────

  Paint _shadow(double alpha) => Paint()
    ..color = _deep.withValues(alpha: alpha.clamp(0.0, 0.8))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.018);

  Paint _gloss(double alpha) => Paint()
    ..color = _hi.withValues(alpha: alpha.clamp(0.0, 0.7))
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, u * 0.03);

  /// Серп: между кривой по точкам и той же кривой, сдвинутой на thick (доли
  /// головы) в сторону normal — так рисуются борозды между мышцами.
  Path _crescent(List<Offset> pts, Offset normal, double thick) {
    final path = Path()..moveTo(pts.first.dx, pts.first.dy);
    for (var i = 1; i < pts.length; i++) {
      final mid = Offset.lerp(pts[i - 1], pts[i], 0.5)!;
      path.quadraticBezierTo(pts[i - 1].dx, pts[i - 1].dy, mid.dx, mid.dy);
    }
    path.lineTo(pts.last.dx, pts.last.dy);
    final n = pts.length;
    for (var i = n - 1; i >= 0; i--) {
      // Толще в середине, на концах — сходит на нет.
      final k = sin(pi * i / (n - 1));
      final p = pts[i] + normal * thick * u * k;
      path.lineTo(p.dx, p.dy);
    }
    return path..close();
  }

  void _torsoMuscles(Canvas canvas) {
    final c = s[Joint.chest], w = s[Joint.waist], p = s[Joint.pelvis];
    final aC = b.acrossChest, uC = b.upChest, aS = b.acrossSpine;
    final uS = b.upSpine;
    final chest = b.g(b.m.chest), core = b.g(b.m.core), lats = b.g(b.m.lats);
    final lean = (1 - b.fat.clamp(0.0, 1.0) * 0.8);
    canvas.save();
    canvas.clipPath(b.torso);
    Offset at(Offset o, Offset a, Offset up, double x, double y) =>
        o + a * x * u + up * y * u;

    for (final sign in [1.0, -1.0]) {
      Offset ch(double x, double y) => at(c, aC, uC, x * sign, y);
      if (!b.female) {
        // Нижний край грудной: серп тени под мышцей.
        final drop = 0.42 + chest * 0.1;
        canvas.drawPath(
          _crescent(
            [
              ch(0.05, -drop - 0.02),
              ch(0.35, -drop - 0.04),
              ch(0.62, -drop + 0.08),
              ch(0.78, -0.12),
            ],
            -uC,
            0.06 + chest * 0.07,
          ),
          _shadow(0.35 + chest * 0.35),
        );
        // Блик на верхней части грудной (сторона к свету ярче).
        canvas.drawOval(
          Rect.fromCenter(
            center: ch(0.36, -0.12),
            width: u * (0.42 + chest * 0.1),
            height: u * 0.22,
          ),
          _gloss(sign < 0 ? 0.35 : 0.15),
        );
      } else {
        // Грудь: округлая форма с тенью снизу (под спортивным топом).
        final bc = ch(0.34, -0.36);
        canvas.drawPath(
          _crescent(
            [ch(0.1, -0.52), ch(0.3, -0.6), ch(0.52, -0.52), ch(0.62, -0.32)],
            -uC,
            0.08,
          ),
          _shadow(0.45),
        );
        canvas.drawOval(
          Rect.fromCenter(
            center: bc - uC * u * 0.04,
            width: u * 0.32,
            height: u * 0.2,
          ),
          _gloss(sign < 0 ? 0.3 : 0.12),
        );
      }
      // Ключица: тонкий блик.
      canvas.drawPath(
        _crescent([ch(0.12, 0.42), ch(0.42, 0.4), ch(0.72, 0.46)], uC, 0.035),
        _gloss(0.4),
      );
      // Зубчатая и косые: «пальцы» тени по бокам.
      final serr = 0.15 + lats * 0.4;
      for (var i = 0; i < 3; i++) {
        final y = -0.62 - i * 0.16;
        canvas.drawPath(
          _crescent(
            [ch(0.72 - i * 0.03, y + 0.04), ch(0.58 - i * 0.02, y - 0.04)],
            -uC,
            0.05,
          ),
          _shadow(serr * lean),
        );
      }
      // Косая над тазом.
      Offset sp(double x, double y) => at(w, aS, uS, x * sign, y);
      canvas.drawPath(
        _crescent(
          [sp(0.5, 0.12), sp(0.46, -0.12), sp(0.36, -0.36)],
          aS * -sign,
          0.06,
        ),
        _shadow((0.25 + core * 0.3) * lean),
      );
      // Паховая линия («V» к тазу).
      Offset pl(double x, double y) => at(p, aS, uS, x * sign, y);
      canvas.drawPath(
        _crescent(
          [pl(0.5, 0.3), pl(0.32, 0.06), pl(0.14, -0.14)],
          uS * -1,
          0.05,
        ),
        _shadow((0.2 + core * 0.4) * lean),
      );
    }
    // Пресс: белая линия и три перемычки; виден тем сильнее, чем меньше жира.
    final abs = ((0.12 + core * 0.55) * lean).clamp(0.0, 0.7);
    Offset ab(double x, double y) => at(c, aC, uC, x, y);
    canvas.drawPath(
      _crescent([ab(0, -0.5), ab(0.01, -0.95), ab(0, -1.42)], aC, 0.035),
      _shadow(abs),
    );
    for (final y in [-0.72, -0.98, -1.22]) {
      for (final sign in [1.0, -1.0]) {
        canvas.drawPath(
          _crescent(
            [
              ab(0.04 * sign, y),
              ab(0.17 * sign, y - 0.03),
              ab(0.3 * sign, y + 0.01),
            ],
            -uC,
            0.04,
          ),
          _shadow(abs * 0.85),
        );
        // Кубики светлее сверху слева.
        canvas.drawOval(
          Rect.fromCenter(
            center: ab(0.16 * sign, y + 0.1),
            width: u * 0.2,
            height: u * 0.1,
          ),
          _gloss(abs * (sign < 0 ? 0.6 : 0.25)),
        );
      }
    }
    // Пупок.
    canvas.drawOval(
      Rect.fromCenter(center: ab(0, -1.5), width: u * 0.05, height: u * 0.07),
      _shadow(0.6),
    );
    canvas.restore();
  }

  void _upperArmMuscles(Canvas canvas, Side side, Path arm) {
    final j = _armJoints(side);
    final bi = b.g(b.m.upperArm);
    canvas.save();
    canvas.clipPath(arm);
    // Борозда между бицепсом и трицепсом снаружи.
    Offset at(double t, double x) =>
        b.along(j.shoulder, j.elbow, t, x, side.sign);
    canvas.drawPath(
      _crescent(
        [at(0.32, 0.06), at(0.55, 0.04), at(0.82, 0.02)],
        _outN(j.shoulder, j.elbow, side),
        0.04,
      ),
      _shadow(0.25 + bi * 0.4),
    );
    // Блик на брюшке бицепса.
    canvas.drawOval(
      Rect.fromCenter(
        center: at(0.48, -0.08),
        width: u * 0.16,
        height: u * 0.32,
      ),
      _gloss(0.25 + bi * 0.2),
    );
    canvas.restore();
  }

  void _forearmMuscles(Canvas canvas, Side side, Path fore) {
    final j = _armJoints(side);
    canvas.save();
    canvas.clipPath(fore);
    Offset at(double t, double x) => b.along(j.elbow, j.wrist, t, x, side.sign);
    canvas.drawPath(
      _crescent(
        [at(0.08, 0.0), at(0.3, 0.02), at(0.55, -0.02)],
        _outN(j.elbow, j.wrist, side),
        0.035,
      ),
      _shadow(0.3 + b.g(b.m.forearms) * 0.3),
    );
    canvas.restore();
  }

  void _deltMuscles(Canvas canvas, Side side, Path delt) {
    final j = _armJoints(side);
    canvas.save();
    canvas.clipPath(delt);
    Offset at(double t, double x) =>
        b.along(j.shoulder, j.elbow, t, x, side.sign);
    // Передний и средний пучок: лёгкая борозда, блик сверху.
    canvas.drawPath(
      _crescent(
        [at(-0.08, 0.08), at(0.1, 0.06), at(0.26, 0.02)],
        -_outN(j.shoulder, j.elbow, side),
        0.03,
      ),
      _shadow(0.2 + b.g(b.m.delts) * 0.35),
    );
    canvas.drawOval(
      Rect.fromCenter(center: at(0.0, 0.14), width: u * 0.24, height: u * 0.18),
      _gloss(0.35),
    );
    canvas.restore();
  }

  void _legMuscles(Canvas canvas) {
    for (final side in [Side.right, Side.left]) {
      final leg = side == Side.right ? b.legR : b.legL;
      final j = _legJoints(side);
      final q = b.g(b.m.thighs), c = b.g(b.m.calves);
      canvas.save();
      canvas.clipPath(leg[0]);
      Offset th(double t, double x) => b.along(j.hip, j.knee, t, x, side.sign);
      final out = _outN(j.hip, j.knee, side);
      // Граница прямой и наружной мышц бедра.
      canvas.drawPath(
        _crescent(
          [th(0.08, 0.12), th(0.4, 0.14), th(0.72, 0.06), th(0.9, -0.04)],
          out,
          0.05,
        ),
        _shadow(0.2 + q * 0.35),
      );
      // «Капля» над коленом изнутри.
      canvas.drawPath(
        _crescent([th(0.66, -0.1), th(0.8, -0.2), th(0.94, -0.12)], -out, 0.05),
        _shadow(0.25 + q * 0.3),
      );
      // Блик на передней поверхности бедра.
      canvas.drawOval(
        Rect.fromCenter(
          center: th(0.38, -0.02),
          width: u * 0.24,
          height: u * 0.62,
        ),
        _gloss(0.22 + q * 0.15),
      );
      canvas.restore();
      canvas.save();
      canvas.clipPath(leg[1]);
      Offset sh(double t, double x) =>
          b.along(j.knee, j.ankle, t, x, side.sign);
      // Коленная чашечка: блик и тень под ней.
      canvas.drawOval(
        Rect.fromCenter(
          center: sh(-0.01, 0.0),
          width: u * 0.22,
          height: u * 0.2,
        ),
        _gloss(0.3),
      );
      canvas.drawPath(
        _crescent(
          [sh(0.06, 0.1), sh(0.1, 0.0), sh(0.06, -0.1)],
          _unit(j.ankle - j.knee),
          0.04,
        ),
        _shadow(0.35),
      );
      // Икра: внутренняя головка, блик снаружи.
      canvas.drawPath(
        _crescent(
          [sh(0.22, -0.2), sh(0.4, -0.16), sh(0.58, -0.08)],
          -_outN(j.knee, j.ankle, side),
          0.05,
        ),
        _shadow(0.2 + c * 0.35),
      );
      canvas.drawOval(
        Rect.fromCenter(
          center: sh(0.3, 0.12),
          width: u * 0.14,
          height: u * 0.36,
        ),
        _gloss(0.18 + c * 0.15),
      );
      canvas.restore();
    }
  }

  // ── Голова ────────────────────────────────────────────────────────────

  void _face(Canvas canvas) {
    final hc = s[Joint.head];
    final up = _unit(s[Joint.headTop] - hc);
    final side = Offset(-up.dy, up.dx);
    Offset f(double x, double y) => hc + side * x * u + up * y * u;
    canvas.save();
    canvas.clipPath(b.head);
    // Надбровья: глубокая тень глазниц — суровый взгляд.
    for (final sign in [1.0, -1.0]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: f(0.14 * sign, 0.02),
          width: u * 0.2,
          height: u * 0.1,
        ),
        _shadow(0.75),
      );
      // Блик в глазу.
      canvas.drawCircle(
        f(0.13 * sign, 0.01),
        u * 0.016,
        Paint()..color = Colors.white.withValues(alpha: 0.75),
      );
    }
    canvas.drawPath(
      _crescent([f(-0.24, 0.1), f(0, 0.12), f(0.24, 0.1)], up, 0.03),
      _gloss(0.35),
    );
    // Нос: тень справа и снизу.
    canvas.drawPath(
      _crescent([f(0.02, 0.0), f(0.05, -0.12), f(0.0, -0.2)], side, 0.035),
      _shadow(0.5),
    );
    // Рот и тень под нижней губой.
    canvas.drawPath(
      _crescent([f(-0.1, -0.31), f(0, -0.3), f(0.1, -0.31)], -up, 0.018),
      _shadow(0.8),
    );
    // Скула и челюсть справа в тени.
    canvas.drawPath(
      _crescent([f(0.3, -0.05), f(0.28, -0.26), f(0.14, -0.44)], -side, 0.06),
      _shadow(0.4),
    );
    canvas.restore();
  }

  // ── Одежда (заглушка до этапа 2.5) ────────────────────────────────────

  void _clothes(Canvas canvas) {
    final p = s[Joint.pelvis], aS = b.acrossSpine, uS = b.upSpine;
    const cloth = Color(0xFF1B171B), clothHi = Color(0xFF3A3036);
    Shader fabric(Offset from, Offset to) => ui.Gradient.linear(
      from,
      to,
      [clothHi, cloth, cloth, Colors.black],
      [0.0, 0.35, 0.7, 1.0],
    );

    // Шорты: от пояса до середины бедра, край штанины — поперёк бедра.
    final far = u * 3;
    final cutR = _legCut(Side.right, 0.36), cutL = _legCut(Side.left, 0.36);
    final region = Path()
      ..addPolygon([
        p + uS * u * 0.5 - aS * far,
        p + uS * u * 0.5 + aS * far,
        Offset(p.dx + far, cutR.$1.dy),
        cutR.$1,
        cutR.$2,
        // Пах — на линии края штанин, а не ниже: иначе «зубцы» на бёдрах.
        Offset.lerp(cutR.$2, cutL.$2, 0.5)! + uS * u * 0.06,
        cutL.$2,
        cutL.$1,
        Offset(p.dx - far, cutL.$1.dy),
      ], true);
    final lower = Path.combine(
      PathOperation.union,
      b.torso,
      Path.combine(PathOperation.union, b.legR[0], b.legL[0]),
    );
    final shorts = Path.combine(PathOperation.intersect, region, lower);
    canvas.drawPath(
      shorts,
      Paint()..shader = fabric(p - aS * b.hipHalf, p + aS * b.hipHalf),
    );
    canvas.save();
    canvas.clipPath(shorts);
    // Пояс и складка между штанинами.
    canvas.drawLine(
      p + uS * u * 0.44 - aS * far,
      p + uS * u * 0.44 + aS * far,
      Paint()
        ..color = clothHi
        ..strokeWidth = u * 0.07,
    );
    canvas.drawPath(
      _crescent([p - uS * u * 0.2, p - uS * u * 0.55], aS, 0.04),
      Paint()..color = Colors.black.withValues(alpha: 0.6),
    );
    canvas.restore();

    if (b.female) {
      // Спортивный топ: вырез посередине, низ под грудью, бретели к плечам.
      final c = s[Joint.chest], aC = b.acrossChest, uC = b.upChest;
      Offset at(double x, double y) => c + aC * x * u + uC * y * u;
      final top = Path()
        ..moveTo(at(-3, 0.3).dx, at(-3, 0.3).dy)
        ..lineTo(at(-0.55, 0.3).dx, at(-0.55, 0.3).dy)
        ..quadraticBezierTo(
          at(-0.2, 0.28).dx,
          at(-0.2, 0.28).dy,
          at(0, -0.06).dx,
          at(0, -0.06).dy,
        )
        ..quadraticBezierTo(
          at(0.2, 0.28).dx,
          at(0.2, 0.28).dy,
          at(0.55, 0.3).dx,
          at(0.55, 0.3).dy,
        )
        ..lineTo(at(3, 0.3).dx, at(3, 0.3).dy)
        ..lineTo(at(3, -0.62).dx, at(3, -0.62).dy)
        ..quadraticBezierTo(
          at(0, -0.74).dx,
          at(0, -0.74).dy,
          at(-3, -0.62).dx,
          at(-3, -0.62).dy,
        )
        ..close();
      final bra = Path.combine(PathOperation.intersect, top, b.torso);
      canvas.drawPath(
        bra,
        Paint()..shader = fabric(c - aC * b.latHalf, c + aC * b.latHalf),
      );
      for (final sign in [1.0, -1.0]) {
        final sh = s[sign > 0 ? Joint.shoulderR : Joint.shoulderL];
        canvas.drawLine(
          at(0.5 * sign, 0.26),
          Offset.lerp(s[Joint.neck], sh, 0.55)! + uC * u * 0.1,
          Paint()
            ..color = cloth
            ..strokeWidth = u * 0.07
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.save();
      canvas.clipPath(bra);
      // Нижняя резинка топа.
      canvas.drawPath(
        _crescent([at(-1.2, -0.6), at(0, -0.7), at(1.2, -0.6)], uC, 0.06),
        Paint()..color = clothHi,
      );
      canvas.restore();
    }
  }

  /// Край штанины: две точки поперёк бедра на доле t (снаружи, изнутри),
  /// с запасом за контур ноги.
  (Offset, Offset) _legCut(Side side, double t) {
    final j = _legJoints(side);
    return (
      b.along(j.hip, j.knee, t, 0.9, side.sign),
      b.along(j.hip, j.knee, t, -0.9, side.sign),
    );
  }

  // ── Вспомогательное ───────────────────────────────────────────────────

  ({Offset shoulder, Offset elbow, Offset wrist, Offset hand}) _armJoints(
    Side side,
  ) {
    final r = side == Side.right;
    return (
      shoulder: s[r ? Joint.shoulderR : Joint.shoulderL],
      elbow: s[r ? Joint.elbowR : Joint.elbowL],
      wrist: s[r ? Joint.wristR : Joint.wristL],
      hand: s[r ? Joint.handR : Joint.handL],
    );
  }

  ({Offset hip, Offset knee, Offset ankle, Offset toe}) _legJoints(Side side) {
    final r = side == Side.right;
    return (
      hip: s[r ? Joint.hipR : Joint.hipL],
      knee: s[r ? Joint.kneeR : Joint.kneeL],
      ankle: s[r ? Joint.ankleR : Joint.ankleL],
      toe: s[r ? Joint.toeR : Joint.toeL],
    );
  }

  /// Нормаль «наружу» для сегмента a→b стороны side.
  Offset _outN(Offset a, Offset z, Side side) {
    final d = _unit(z - a);
    return Offset(d.dy, -d.dx) * side.sign.toDouble();
  }

  static Offset _unit(Offset v) =>
      v.distance == 0 ? const Offset(0, 1) : v / v.distance;

  @override
  bool shouldRepaint(RigPainter old) => true;
}
