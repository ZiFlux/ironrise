import 'dart:math';
import 'dart:ui';

import '../body_frame.dart' show BodyFrame, smoothClosedPath;
import 'skeleton.dart';

/// Тело на костях (REDESIGN, этап 2.2): каждый сегмент — форма вокруг своей
/// кости, торс строится от позвоночника и гнётся вместе с ним. Части сидят в
/// суставах при любой позе: стыки (плечо, локоть, колено) совпадают по ширине.
///
/// Рост мышц и телосложение — из BodyFrame (те же уровни и баланс, что раньше),
/// размеры — в долях высоты головы, поэтому мужская и женская модели
/// пропорциональны своему скелету.
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

  /// Весь силуэт одним контуром — для обводки и контрового света.
  late final Path silhouette = [
    torso,
    neck,
    head,
    ...armR,
    ...armL,
    ...legR,
    ...legL,
  ].reduce((a, b) => Path.combine(PathOperation.union, a, b));

  /// Мышца или телосложение в пикселях: k долей головы × рост.
  double _w(double base, [double grow = 0]) => (base + grow) * u;

  double get _fat => max(m.fat, -0.5);

  /// Женская мускулатура растёт мягче: та же прокачка — меньше объёма.
  double _g(double v) => female ? v * 0.55 : v;

  void _build() {
    final g = _g;
    // Голова: овал по оси головы, челюсть уже лба, у мужчин — квадратнее.
    final hc = s[Joint.head];
    final up = _unit(s[Joint.headTop] - hc);
    final side = Offset(-up.dy, up.dx);
    final hw = _w(female ? 0.35 : 0.38);
    Offset hp(double across, double along) =>
        hc + side * across * hw + up * along * u;
    head = smoothClosedPath([
      hp(0, 0.52),
      hp(0.72, 0.45),
      hp(1, 0.16),
      hp(0.96, -0.12),
      hp(female ? 0.72 : 0.82, -0.36),
      hp(female ? 0.32 : 0.42, -0.5),
      hp(0, -0.54),
      hp(female ? -0.32 : -0.42, -0.5),
      hp(female ? -0.72 : -0.82, -0.36),
      hp(-0.96, -0.12),
      hp(-1, 0.16),
      hp(-0.72, 0.45),
    ]);

    // Шея: от трапеций до челюсти, толще с трапециями.
    final neckHalf = _w(female ? 0.19 : 0.24, g(m.traps) * 0.07 + _fat * 0.04);
    neck = _limb(s[Joint.neck] + const Offset(0, 4), hc, [
      (0, neckHalf * 1.25 / u, neckHalf * 1.25 / u),
      (0.35, neckHalf / u, neckHalf / u),
      (0.85, neckHalf * 0.92 / u, neckHalf * 0.92 / u),
    ], 1);

    torso = _torso();

    armR = _arm(Side.right);
    armL = _arm(Side.left);
    legR = _leg(Side.right);
    legL = _leg(Side.left);
  }

  /// Торс по уровням позвоночника: шея, плечи, грудь, широчайшие, талия, таз.
  Path _torso() {
    final g = _g;
    final n = s[Joint.neck], c = s[Joint.chest], w = s[Joint.waist];
    final p = s[Joint.pelvis];
    // Поперечная ось на каждом уровне — перпендикуляр к своей кости.
    Offset across(Bone b) {
      final d = s.direction(b);
      return Offset(-d.dy, d.dx);
    }

    final aChest = across(Bone.chest), aSpine = across(Bone.spine);
    // Кости позвоночника идут снизу вверх: их направление и есть «вверх».
    final upChest = s.direction(Bone.chest);
    final upSpine = s.direction(Bone.spine);

    // Широчайшие дают V-силуэт: растут сильнее всего.
    final latHalf = _w(
      female ? 0.7 : 0.84,
      g(m.lats) * 0.34 + g(m.chest) * 0.06 + _fat * 0.12,
    );
    final waistHalf = _w(
      female ? 0.53 : 0.6,
      _fat * (female ? 0.22 : 0.3) - g(m.core) * 0.03,
    );
    // Таз: у женщин шире плеч по костям, у мужчин уже широчайших.
    final hipHalf = _w(female ? 0.84 : 0.7, g(m.glutes) * 0.06 + _fat * 0.16);
    final neckHalf = _w(female ? 0.19 : 0.24, g(m.traps) * 0.08);

    List<Offset> half(double sign) {
      final sr = s[sign > 0 ? Joint.shoulderR : Joint.shoulderL];
      final outward = (sr - n) / (sr - n).distance;
      // Трапеция: от шеи к плечу, поднимается с ростом трапеций.
      final trap =
          Offset.lerp(n, sr, 0.45)! + upChest * _w(0.1, g(m.traps) * 0.14);
      // Плечевой угол торса прячется под дельтой (её рисует рука).
      return [
        n + upChest * _w(0.14) + aChest * sign * neckHalf,
        trap,
        sr + upChest * _w(0.08) - outward * _w(0.06),
        // Широчайшие шире всего у подмышки, дальше — ровный клин к талии
        // и плавный переход к тазу, без «корсета».
        c + aChest * sign * latHalf - upChest * _w(0.12),
        c +
            aChest * sign * (latHalf * 0.6 + waistHalf * 0.4) -
            upChest * _w(0.55),
        w + aSpine * sign * waistHalf,
        p +
            aSpine * sign * (waistHalf * 0.3 + hipHalf * 0.7) +
            upSpine * _w(0.42),
        p + aSpine * sign * hipHalf,
        p + aSpine * sign * hipHalf * 0.94 - upSpine * _w(0.16),
      ];
    }

    final right = half(1.0), left = half(-1.0);
    return smoothClosedPath([
      ...right,
      p + aSpine * _w(0.34) - upSpine * _w(0.36),
      p - upSpine * _w(0.44),
      p - aSpine * _w(0.34) - upSpine * _w(0.36),
      ...left.reversed,
    ]);
  }

  /// Дельта — округлая «шапка» вокруг плечевого сустава, по оси плеча.
  /// Закрывает стык руки и торса в любой позе.
  Path _delt(Side side) {
    final r = side == Side.right;
    final sh = s[r ? Joint.shoulderR : Joint.shoulderL];
    final el = s[r ? Joint.elbowR : Joint.elbowL];
    final d = _unit(el - sh);
    final out = Offset(d.dy, -d.dx) * side.sign.toDouble();
    final g = _g(m.delts);
    final k = female ? 0.72 : 1.0;
    final len = _w(0.5 + g * 0.12) * k;
    final wOut = _w(0.32 + g * 0.2 + _fat * 0.04) * k;
    final wIn = _w(0.24 + g * 0.08) * k;
    final c = sh + d * _w(0.04);
    Offset p(double along, double across) => c + d * along + out * across;
    return smoothClosedPath([
      p(-len * 0.42, 0),
      p(-len * 0.3, wOut * 0.75),
      p(len * 0.08, wOut),
      p(len * 0.5, wOut * 0.82),
      p(len * 0.86, wOut * 0.32),
      p(len * 0.9, -wIn * 0.3),
      p(len * 0.42, -wIn),
      p(-len * 0.12, -wIn * 0.85),
      p(-len * 0.36, -wIn * 0.45),
    ]);
  }

  List<Path> _arm(Side side) {
    final g = _g;
    final r = side == Side.right;
    final sh = s[r ? Joint.shoulderR : Joint.shoulderL];
    final el = s[r ? Joint.elbowR : Joint.elbowL];
    final wr = s[r ? Joint.wristR : Joint.wristL];
    final hd = s[r ? Joint.handR : Joint.handL];
    final d = g(m.delts), b = g(m.upperArm), f = g(m.forearms);
    final fat = _fat * 0.06;
    final k = female ? 0.82 : 1.0;
    // (t, наружу, внутрь) в долях головы. Дельта — верх плеча, шире торса.
    final upper = _limb(sh, el, [
      (0.02, (0.24 + d * 0.06 + fat) * k, (0.2 + fat) * k),
      (
        0.3,
        (0.24 + d * 0.04 + b * 0.06 + fat) * k,
        (0.24 + b * 0.12 + fat) * k,
      ),
      (0.68, (0.2 + b * 0.06 + fat) * k, (0.21 + b * 0.08 + fat) * k),
      (1.0, 0.16 * k, 0.15 * k),
    ], side.sign);
    final fore = _limb(el, wr, [
      (-0.04, 0.16 * k, 0.15 * k),
      (0.22, (0.21 + f * 0.07 + fat) * k, (0.18 + f * 0.04 + fat) * k),
      (0.6, (0.15 + f * 0.02) * k, (0.14 + f * 0.02) * k),
      (1.0, 0.11 * k, 0.105 * k),
    ], side.sign);
    final hand = _limb(wr, hd, [
      (-0.02, 0.11 * k, 0.105 * k),
      (0.42, 0.145 * k, 0.13 * k),
      (0.82, 0.125 * k, 0.1 * k),
      (1.0, 0.05 * k, 0.05 * k),
    ], side.sign);
    // Порядок рисования: плечо, предплечье, кисть, дельта сверху.
    return [upper, fore, hand, _delt(side)];
  }

  List<Path> _leg(Side side) {
    final g = _g;
    final r = side == Side.right;
    final hip = s[r ? Joint.hipR : Joint.hipL];
    final kn = s[r ? Joint.kneeR : Joint.kneeL];
    final an = s[r ? Joint.ankleR : Joint.ankleL];
    final toe = s[r ? Joint.toeR : Joint.toeL];
    final q = g(m.thighs), c = g(m.calves);
    final fat = _fat * 0.1;
    // Женское бедро шире снаружи у таза (вертел), внутри — как у мужского.
    final hipOut = female ? 0.1 : 0.0;
    final thigh = _limb(hip, kn, [
      (-0.22, 0.34 + hipOut + q * 0.06 + fat, 0.46),
      (0.04, 0.4 + hipOut + q * 0.08 + fat, 0.4 + q * 0.05 + fat),
      (0.3, 0.38 + hipOut * 0.6 + q * 0.11 + fat, 0.34 + q * 0.06 + fat),
      (0.66, 0.3 + q * 0.07 + fat * 0.8, 0.26 + q * 0.07 + fat * 0.8),
      (0.9, 0.23 + q * 0.02, 0.24 + q * 0.04),
      (1.0, female ? 0.19 : 0.21, female ? 0.18 : 0.2),
    ], side.sign);
    final ks = female ? 0.9 : 1.0;
    final shin = _limb(kn, an, [
      (-0.03, 0.21 * ks, 0.2 * ks),
      (
        0.26,
        (0.25 + c * 0.1 + fat * 0.5) * ks,
        (0.24 + c * 0.07 + fat * 0.5) * ks,
      ),
      (0.62, (0.17 + c * 0.02) * ks, (0.16 + c * 0.01) * ks),
      (1.0, 0.115 * ks, 0.115 * ks),
    ], side.sign);
    final foot = _limb(an, toe, [
      (-0.1, 0.12, 0.12),
      (0.55, 0.16, 0.13),
      (0.92, 0.11, 0.09),
      (1.0, 0.06, 0.05),
    ], side.sign);
    return [thigh, shin, foot];
  }

  /// Сегмент вдоль оси a→b: станции (t, наружу, внутрь) в долях головы.
  /// «Наружу» — от средней линии тела, когда конечность опущена.
  Path _limb(
    Offset a,
    Offset b,
    List<(double, double, double)> stations,
    int sign,
  ) {
    final d = _unit(b - a);
    final out = Offset(d.dy, -d.dx) * (sign == 0 ? 1 : sign.toDouble());
    Offset at(double t) => a + (b - a) * t;
    return smoothClosedPath([
      for (final (t, o, _) in stations) at(t) + out * o * u,
      for (final (t, _, i) in stations.reversed) at(t) - out * i * u,
    ]);
  }

  static Offset _unit(Offset v) =>
      v.distance == 0 ? const Offset(0, 1) : v / v.distance;
}
