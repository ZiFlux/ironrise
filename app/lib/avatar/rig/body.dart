import 'dart:math';
import 'dart:ui';

import '../body_frame.dart' show BodyFrame, smoothClosedPath;
import 'skeleton.dart';

/// Тело на костях (REDESIGN, этап 2.2): каждый сегмент — форма вокруг своей
/// кости по анатомическим опорам (дельта, бицепс, плечелучевая, наружная
/// мышца бедра, «капля» над коленом, две головки икры, щиколотки), торс
/// строится от позвоночника и гнётся вместе с ним. Стыки совпадают по ширине,
/// поэтому части сидят в суставах при любой позе.
///
/// Рост мышц и телосложение — из BodyFrame (те же уровни и баланс, что
/// раньше), размеры — в долях высоты головы [u].
class RigBody {
  RigBody(this.s, this.m) : u = s.rest.p.unit {
    _build();
  }

  final PosedSkeleton s;

  /// Рост мышц и запас жира (0…1, жир −1…1).
  final BodyFrame m;
  final double u;

  bool get female => m.isFemale;

  late final Path head;
  late final Path neck;
  late final Path torso;

  /// Сегменты рук и ног: [плечо, предплечье, кисть, дельта] /
  /// [бедро, голень, стопа].
  late final List<Path> armR, armL, legR, legL;

  /// Полуширины торса (пиксели) — для мышц и одежды.
  late final double neckHalf, latHalf, waistHalf, hipHalf;

  /// Весь силуэт одним контуром — для контрового света и тени.
  late final Path silhouette = [
    torso,
    neck,
    head,
    ...armR,
    ...armL,
    ...legR,
    ...legL,
  ].reduce((a, b) => Path.combine(PathOperation.union, a, b));

  /// Рост мышцы с учётом пола: женская мускулатура растёт мягче.
  double g(double v) => female ? v * 0.55 : v;

  double get fat => max(m.fat, -0.5);

  double _w(double base, [double grow = 0]) => (base + grow) * u;

  /// «Вверх» по кости груди и поясницы и поперёк них (вправо на экране).
  Offset get upChest => s.direction(Bone.chest);
  Offset get upSpine => s.direction(Bone.spine);
  Offset get acrossChest => Offset(-upChest.dy, upChest.dx);
  Offset get acrossSpine => Offset(-upSpine.dy, upSpine.dx);

  void _build() {
    neckHalf = _w(female ? 0.2 : 0.25, g(m.traps) * 0.08 + fat * 0.04);
    latHalf = _w(
      female ? 0.7 : 0.84,
      g(m.lats) * 0.26 + g(m.chest) * 0.06 + fat * 0.12,
    );
    waistHalf = _w(
      female ? 0.58 : 0.6,
      fat * (female ? 0.22 : 0.3) - g(m.core) * 0.03,
    );
    hipHalf = _w(female ? 0.84 : 0.7, g(m.glutes) * 0.06 + fat * 0.16);

    head = _head();
    final hc = s[Joint.head];
    // Шея: от трапеций до челюсти; грудино-ключичные мышцы сужают её кверху.
    neck = _limb(s[Joint.neck] + upChest * -_w(0.1), hc, [
      (0, neckHalf * 1.3 / u, neckHalf * 1.3 / u),
      (0.3, neckHalf / u, neckHalf / u),
      (0.7, neckHalf * 0.88 / u, neckHalf * 0.88 / u),
      (0.9, neckHalf * 0.9 / u, neckHalf * 0.9 / u),
    ], 1);
    torso = _torso();
    armR = _arm(Side.right);
    armL = _arm(Side.left);
    legR = _leg(Side.right);
    legL = _leg(Side.left);
  }

  /// Голова: череп, скулы, челюсть; у мужчин челюсть квадратнее.
  Path _head() {
    final hc = s[Joint.head];
    final up = _unit(s[Joint.headTop] - hc);
    final side = Offset(-up.dy, up.dx);
    final hw = _w(female ? 0.34 : 0.37);
    Offset hp(double across, double along) =>
        hc + side * across * hw + up * along * u;
    final jaw = female ? 0.66 : 0.8;
    final chin = female ? 0.3 : 0.4;
    return smoothClosedPath([
      hp(0, 0.5),
      hp(0.62, 0.45),
      hp(0.95, 0.24),
      hp(1, 0.02),
      // Скула и ухо.
      hp(1.04, -0.08),
      hp(0.94, -0.2),
      hp(jaw, -0.38),
      hp(chin, -0.5),
      hp(0, -0.53),
      hp(-chin, -0.5),
      hp(-jaw, -0.38),
      hp(-0.94, -0.2),
      hp(-1.04, -0.08),
      hp(-1, 0.02),
      hp(-0.95, 0.24),
      hp(-0.62, 0.45),
    ]);
  }

  /// Торс: трапеции, плечи, широчайшие клином к талии, косые над тазом.
  Path _torso() {
    final n = s[Joint.neck], c = s[Joint.chest], w = s[Joint.waist];
    final p = s[Joint.pelvis];
    final aC = acrossChest, aS = acrossSpine, uC = upChest, uS = upSpine;

    List<Offset> half(double sign) {
      final sh = s[sign > 0 ? Joint.shoulderR : Joint.shoulderL];
      final outward = _unit(sh - n);
      final trapRise = _w(0.08, g(m.traps) * 0.16);
      return [
        n + uC * _w(0.16) + aC * sign * neckHalf * 0.95,
        // Трапеция — покатый склон от шеи к плечу.
        Offset.lerp(n, sh, 0.42)! + uC * trapRise,
        Offset.lerp(n, sh, 0.8)! + uC * (trapRise * 0.55 + _w(0.04)),
        sh + uC * _w(0.06) - outward * _w(0.06),
        // Подмышка — впадина под плечевым суставом (видна, когда рука поднята),
        // ниже широчайшие расходятся «крыльями» и клином идут к талии.
        sh - uC * _w(0.42) - outward * _w(0.1),
        c + aC * sign * latHalf - uC * _w(0.6),
        c + aC * sign * (latHalf * 0.55 + waistHalf * 0.45) - uC * _w(0.84),
        w + aS * sign * waistHalf + uS * _w(0.12),
        // Косые мышцы чуть нависают над тазом.
        w + aS * sign * (waistHalf * 1.03 + _w(0.02)) - uS * _w(0.26),
        p + aS * sign * hipHalf * 0.93 + uS * _w(0.18),
        p + aS * sign * hipHalf - uS * _w(0.08),
      ];
    }

    final right = half(1), left = half(-1);
    return smoothClosedPath([
      ...right,
      p + aS * hipHalf * 0.55 - uS * _w(0.34),
      p - uS * _w(0.44),
      p - aS * hipHalf * 0.55 - uS * _w(0.34),
      ...left.reversed,
    ]);
  }

  List<Path> _arm(Side side) {
    final r = side == Side.right;
    final sh = s[r ? Joint.shoulderR : Joint.shoulderL];
    final el = s[r ? Joint.elbowR : Joint.elbowL];
    final wr = s[r ? Joint.wristR : Joint.wristL];
    final hd = s[r ? Joint.handR : Joint.handL];
    final d = g(m.delts), b = g(m.upperArm), f = g(m.forearms);
    final fa = fat * 0.05;
    final k = female ? 0.82 : 1.0;
    // (t, наружу, внутрь), доли головы: снаружи — дельта и трицепс,
    // изнутри — бицепс.
    final upper = _limb(sh, el, [
      (0.04, (0.26 + d * 0.05 + fa) * k, (0.21 + fa) * k),
      (0.22, (0.27 + d * 0.05 + fa) * k, (0.23 + b * 0.05 + fa) * k),
      (0.4, (0.24 + d * 0.03 + b * 0.03 + fa) * k, (0.25 + b * 0.12 + fa) * k),
      (0.58, (0.23 + b * 0.07 + fa) * k, (0.24 + b * 0.1 + fa) * k),
      (0.8, (0.2 + b * 0.03) * k, (0.19 + b * 0.05) * k),
      (0.96, 0.165 * k, 0.155 * k),
      (1.04, 0.16 * k, 0.15 * k),
    ], side.sign);
    final fore = _limb(el, wr, [
      (-0.04, 0.16 * k, 0.15 * k),
      (0.12, (0.2 + f * 0.08 + fa) * k, (0.19 + f * 0.05 + fa) * k),
      (0.3, (0.19 + f * 0.05 + fa) * k, (0.18 + f * 0.04 + fa) * k),
      (0.56, (0.15 + f * 0.02) * k, (0.145 + f * 0.02) * k),
      (0.86, 0.12 * k, 0.115 * k),
      (1.02, 0.115 * k, 0.11 * k),
    ], side.sign);
    // Кисть: ладонь, большой палец изнутри, пальцы.
    final hand = _limb(wr, hd, [
      (-0.02, 0.115 * k, 0.11 * k),
      (0.2, 0.13 * k, 0.15 * k),
      (0.4, 0.14 * k, 0.16 * k),
      (0.55, 0.135 * k, 0.12 * k),
      (0.82, 0.12 * k, 0.1 * k),
      (1.0, 0.05 * k, 0.05 * k),
    ], side.sign);
    return [upper, fore, hand, _delt(side)];
  }

  /// Дельта — округлая «шапка» вокруг плечевого сустава, по оси плеча.
  /// Закрывает стык руки и торса в любой позе.
  Path _delt(Side side) {
    final r = side == Side.right;
    final sh = s[r ? Joint.shoulderR : Joint.shoulderL];
    final el = s[r ? Joint.elbowR : Joint.elbowL];
    final d = _unit(el - sh);
    final out = Offset(d.dy, -d.dx) * side.sign.toDouble();
    final gd = g(m.delts);
    final k = female ? 0.8 : 1.0;
    // Длина — до места прикрепления на плече (~40 % его длины).
    final len = (el - sh).distance * 0.44;
    final wOut = _w(0.3 + gd * 0.11 + fat * 0.04) * k;
    final wIn = _w(0.22 + gd * 0.05) * k;
    // Ширина плеча снаружи там, где дельта сходит на нет.
    final armOut = _w(0.25 + gd * 0.04 + fat * 0.05) * k;
    final c = sh + d * _w(0.02);
    Offset p(double along, double across) => c + d * along + out * across;
    // Каплевидная: широкая сверху, сходит клином в контур плеча — без ступеньки.
    return smoothClosedPath([
      p(-len * 0.3, -wIn * 0.15),
      p(-len * 0.24, wOut * 0.7),
      p(len * 0.06, wOut),
      p(len * 0.4, (wOut + armOut) / 2 * 1.04),
      p(len * 0.75, armOut * 1.01),
      p(len * 1.0, armOut * 0.96),
      p(len * 1.0, armOut * 0.6),
      p(len * 0.62, -wIn * 0.45),
      p(len * 0.2, -wIn * 0.92),
      p(-len * 0.16, -wIn * 0.78),
    ]);
  }

  List<Path> _leg(Side side) {
    final r = side == Side.right;
    final hip = s[r ? Joint.hipR : Joint.hipL];
    final kn = s[r ? Joint.kneeR : Joint.kneeL];
    final an = s[r ? Joint.ankleR : Joint.ankleL];
    final toe = s[r ? Joint.toeR : Joint.toeL];
    final q = g(m.thighs), c = g(m.calves);
    final fa = fat * 0.1;
    // Женское бедро шире снаружи у таза (вертел).
    final hipOut = female ? 0.09 : 0.0;
    final ks = female ? 0.9 : 1.0;
    final thigh = _limb(hip, kn, [
      (-0.24, 0.32 + hipOut + fa, 0.48),
      (0.0, 0.4 + hipOut + q * 0.06 + fa, 0.42 + fa),
      // Наружная широкая мышца — «размах» бедра.
      (0.2, 0.43 + hipOut * 0.8 + q * 0.11 + fa, 0.38 + q * 0.07 + fa),
      (0.46, 0.38 + hipOut * 0.3 + q * 0.1 + fa, 0.3 + q * 0.05 + fa),
      // «Капля» над коленом изнутри.
      (0.74, 0.3 + q * 0.05 + fa * 0.8, 0.27 + q * 0.09 + fa * 0.8),
      (0.9, 0.24 + q * 0.02, 0.26 + q * 0.06),
      (1.02, 0.21 * ks, 0.2 * ks),
    ], side.sign);
    final shin = _limb(kn, an, [
      (-0.03, 0.21 * ks, 0.2 * ks),
      (0.12, (0.23 + c * 0.05) * ks, (0.22 + c * 0.04) * ks),
      // Икра: наружная головка выше, внутренняя ниже и полнее.
      (
        0.27,
        (0.26 + c * 0.1 + fa * 0.5) * ks,
        (0.25 + c * 0.07 + fa * 0.5) * ks,
      ),
      (
        0.42,
        (0.22 + c * 0.05 + fa * 0.4) * ks,
        (0.26 + c * 0.09 + fa * 0.4) * ks,
      ),
      (0.64, (0.165 + c * 0.02) * ks, (0.18 + c * 0.03) * ks),
      (0.86, 0.125 * ks, 0.13 * ks),
      // Щиколотки: внутренняя выше наружной.
      (0.95, 0.13 * ks, 0.125 * ks),
      (1.02, 0.12 * ks, 0.12 * ks),
    ], side.sign);
    final foot = _limb(an, toe, [
      (-0.12, 0.12 * ks, 0.12 * ks),
      (0.4, 0.15 * ks, 0.14 * ks),
      (0.75, 0.15 * ks, 0.12 * ks),
      (0.95, 0.1 * ks, 0.08 * ks),
      (1.0, 0.05 * ks, 0.04 * ks),
    ], side.sign);
    return [thigh, shin, foot];
  }

  /// Точка на оси a→b со сдвигом наружу (+) или внутрь (−), доли головы.
  Offset along(Offset a, Offset b, double t, double across, int sign) {
    final d = _unit(b - a);
    final out = Offset(d.dy, -d.dx) * (sign == 0 ? 1 : sign.toDouble());
    return a + (b - a) * t + out * across * u;
  }

  /// Сегмент вдоль оси a→b: станции (t, наружу, внутрь) в долях головы.
  /// «Наружу» — от средней линии тела, когда конечность опущена.
  Path _limb(
    Offset a,
    Offset b,
    List<(double, double, double)> stations,
    int sign,
  ) => smoothClosedPath([
    for (final (t, o, _) in stations) along(a, b, t, o, sign),
    for (final (t, _, i) in stations.reversed) along(a, b, t, -i, sign),
  ]);

  static Offset _unit(Offset v) =>
      v.distance == 0 ? const Offset(0, 1) : v / v.distance;
}
