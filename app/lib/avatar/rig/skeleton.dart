/// Скелет героя (REDESIGN, этап 2.1): 22 точки, 21 кость. Вид спереди, холст
/// 200 × 400 (как у аватара), центр тела x = 100, подошвы y = 390.
///
/// Пропорции — героические ~8 голов. Кость задана направлением и длиной в покое;
/// поза — повороты костей. Поворот родителя несёт за собой всех потомков
/// (прямая кинематика), поэтому части тела всегда сидят в своих суставах.
///
/// Углы позы — «от тела наружу» (отведение): одно и то же число для левой и
/// правой стороны даёт симметричную позу. Для костей по центру (поясница, грудь,
/// шея, голова) плюс — наклон к правой стороне экрана.
library;

import 'dart:math';
import 'dart:ui';

/// Точки скелета. R/L — правая и левая сторона ЭКРАНА (у героя наоборот).
enum Joint {
  pelvis,
  waist,
  chest,
  neck,
  head,
  headTop,
  shoulderR,
  elbowR,
  wristR,
  handR,
  shoulderL,
  elbowL,
  wristL,
  handL,
  hipR,
  kneeR,
  ankleR,
  toeR,
  hipL,
  kneeL,
  ankleL,
  toeL,
}

/// Сторона кости: +1 — правая на экране, −1 — левая, 0 — по центру.
enum Side {
  center(0),
  right(1),
  left(-1);

  const Side(this.sign);
  final int sign;
}

/// Кость: из какого сустава в какой, сторона и пределы поворота (градусы).
enum Bone {
  spine(Joint.pelvis, Joint.waist, Side.center, -25, 25),
  chest(Joint.waist, Joint.chest, Side.center, -20, 20),
  neck(Joint.chest, Joint.neck, Side.center, -25, 25),
  head(Joint.neck, Joint.head, Side.center, -30, 30),
  crown(Joint.head, Joint.headTop, Side.center, 0, 0),
  clavicleR(Joint.neck, Joint.shoulderR, Side.right, -12, 20),
  upperArmR(Joint.shoulderR, Joint.elbowR, Side.right, -30, 180),
  forearmR(Joint.elbowR, Joint.wristR, Side.right, -150, 150),
  handR(Joint.wristR, Joint.handR, Side.right, -70, 70),
  clavicleL(Joint.neck, Joint.shoulderL, Side.left, -12, 20),
  upperArmL(Joint.shoulderL, Joint.elbowL, Side.left, -30, 180),
  forearmL(Joint.elbowL, Joint.wristL, Side.left, -150, 150),
  handL(Joint.wristL, Joint.handL, Side.left, -70, 70),
  pelvisR(Joint.pelvis, Joint.hipR, Side.right, 0, 0),
  thighR(Joint.hipR, Joint.kneeR, Side.right, -20, 60),
  shinR(Joint.kneeR, Joint.ankleR, Side.right, -40, 40),
  footR(Joint.ankleR, Joint.toeR, Side.right, -30, 30),
  pelvisL(Joint.pelvis, Joint.hipL, Side.left, 0, 0),
  thighL(Joint.hipL, Joint.kneeL, Side.left, -20, 60),
  shinL(Joint.kneeL, Joint.ankleL, Side.left, -40, 40),
  footL(Joint.ankleL, Joint.toeL, Side.left, -30, 30);

  const Bone(this.from, this.to, this.side, this.minDeg, this.maxDeg);

  final Joint from;
  final Joint to;
  final Side side;
  final double minDeg;
  final double maxDeg;

  /// Кость-родитель: та, что приходит в наш начальный сустав.
  Bone? get parent => _parentOf[from];

  /// Зеркальная кость другой стороны (для центральных — она сама).
  Bone get mirror => switch (side) {
    Side.center => this,
    Side.right => Bone.values.byName(name.replaceFirst(RegExp(r'R$'), 'L')),
    Side.left => Bone.values.byName(name.replaceFirst(RegExp(r'L$'), 'R')),
  };
}

final _parentOf = {for (final b in Bone.values) b.to: b};

/// Размеры скелета в покое. Всё в долях высоты головы [unit].
class Proportions {
  const Proportions({
    required this.unit,
    required this.shoulderHalf,
    required this.hipHalf,
    required this.upperArm,
    required this.forearm,
    required this.hand,
    required this.thigh,
    required this.shin,
  });

  /// Мужские: плечи шире, таз уже. Голова 45 → рост 8 голов, сверху запас
  /// под руки в позах «бицепс» и «победа».
  static const male = Proportions(
    unit: 44,
    // Сустав плеча внутри дельты: сама дельта шире на мышцу.
    shoulderHalf: 0.92,
    hipHalf: 0.42,
    upperArm: 1.45,
    forearm: 1.2,
    hand: 0.72,
    thigh: 2.0,
    shin: 1.75,
  );

  /// Женские: плечи уже, таз шире, голова чуть меньше — рост ~8,2 головы.
  static const female = Proportions(
    unit: 42.5,
    shoulderHalf: 0.8,
    hipHalf: 0.5,
    upperArm: 1.4,
    forearm: 1.15,
    hand: 0.68,
    thigh: 2.05,
    shin: 1.8,
  );

  final double unit;
  final double shoulderHalf, hipHalf;
  final double upperArm, forearm, hand, thigh, shin;
}

/// Холст аватара и подошвы.
const double rigCenterX = 100;
const double rigSoleY = 390;

/// Скелет в покое: где каждая точка (стойка «руки вдоль тела, ноги вместе»).
class RestSkeleton {
  RestSkeleton(this.p) {
    final u = p.unit;
    // Снизу вверх от подошв: голеностоп, колено, тазобедренный.
    final ankleY = rigSoleY - 0.32 * u;
    final kneeY = ankleY - p.shin * u;
    final hipY = kneeY - p.thigh * u;
    final pelvisY = hipY - 0.12 * u;
    final waistY = pelvisY - 0.9 * u;
    final chestY = waistY - 1.1 * u;
    final neckY = chestY - 0.62 * u;
    final headY = neckY - 0.72 * u;
    final topY = headY - 0.55 * u;
    final shoulderY = neckY + 0.2 * u;
    Offset c(double y) => Offset(rigCenterX, y);
    Offset s(Side side, double dx, double y) =>
        Offset(rigCenterX + side.sign * dx, y);

    _rest[Joint.pelvis] = c(pelvisY);
    _rest[Joint.waist] = c(waistY);
    _rest[Joint.chest] = c(chestY);
    _rest[Joint.neck] = c(neckY);
    _rest[Joint.head] = c(headY);
    _rest[Joint.headTop] = c(topY);
    for (final side in [Side.right, Side.left]) {
      final r = side == Side.right;
      final sx = p.shoulderHalf * u;
      final elbowY = shoulderY + p.upperArm * u;
      final wristY = elbowY + p.forearm * u;
      _rest[r ? Joint.shoulderR : Joint.shoulderL] = s(side, sx, shoulderY);
      _rest[r ? Joint.elbowR : Joint.elbowL] = s(side, sx, elbowY);
      _rest[r ? Joint.wristR : Joint.wristL] = s(side, sx, wristY);
      _rest[r ? Joint.handR : Joint.handL] = s(side, sx, wristY + p.hand * u);
      final hx = p.hipHalf * u;
      _rest[r ? Joint.hipR : Joint.hipL] = s(side, hx, hipY);
      _rest[r ? Joint.kneeR : Joint.kneeL] = s(side, hx, kneeY);
      _rest[r ? Joint.ankleR : Joint.ankleL] = s(side, hx, ankleY);
      // Стопа спереди: носок чуть наружу и вниз, до подошвы.
      _rest[r ? Joint.toeR : Joint.toeL] = s(side, hx + 0.12 * u, rigSoleY);
    }
  }

  final Proportions p;
  final _rest = <Joint, Offset>{};

  Offset operator [](Joint j) => _rest[j]!;

  /// Вектор кости в покое (от начала к концу).
  Offset vector(Bone b) => this[b.to] - this[b.from];
}

/// Поза: поворот каждой кости относительно родителя, в градусах «наружу».
/// Кости, которых нет в карте, не повёрнуты.
class RigPose {
  const RigPose(
    this.angles, {
    this.mirrored = true,
    this.lift = 0,
    this.depth = const {},
  });

  /// Углы; при [mirrored] заданные для правой стороны копируются на левую.
  final Map<Bone, double> angles;
  final bool mirrored;

  /// Ракурс: кость, вынесенная к зрителю или от него, видна короче
  /// (1 — в плоскости экрана, 0,7 — заметно вперёд). Так руки в позах
  /// «бицепс» и «победа» помещаются в холст, как у живого атлета.
  final Map<Bone, double> depth;

  double depthOf(Bone b) {
    final own = depth[b];
    if (own != null) return own;
    if (mirrored && b.side == Side.left) return depth[b.mirror] ?? 1;
    return 1;
  }

  /// Подъём всего тела (на носки, прыжок), в пикселях вверх.
  final double lift;

  double operator [](Bone b) {
    final own = angles[b];
    if (own != null) return own;
    if (mirrored && b.side == Side.left) return angles[b.mirror] ?? 0;
    return 0;
  }

  /// Все углы в пределах сустава — анатомия не ломается ни в одной позе.
  RigPose clamped() => RigPose(
    {
      for (final b in Bone.values)
        b: this[b].clamp(b.minDeg, b.maxDeg).toDouble(),
    },
    mirrored: false,
    lift: lift,
    depth: {for (final b in Bone.values) b: depthOf(b).clamp(0.3, 1.0)},
  );

  /// Естественный переход для анимации: каждая кость со своим сглаживанием,
  /// дальние звенья (предплечье, кисть, голень) опережают ближние — локоть
  /// сгибается раньше, чем поднимается плечо, и рука не «выстреливает» вбок.
  static RigPose blend(RigPose a, RigPose b, double t) {
    double ease(double x) {
      final c = x.clamp(0.0, 1.0);
      return c * c * (3 - 2 * c);
    }

    double timing(Bone bone) {
      final (start, end) = switch (bone) {
        Bone.forearmR ||
        Bone.forearmL ||
        Bone.shinR ||
        Bone.shinL => (0.0, 0.7),
        Bone.handR || Bone.handL || Bone.footR || Bone.footL => (0.05, 0.75),
        Bone.upperArmR ||
        Bone.upperArmL ||
        Bone.thighR ||
        Bone.thighL => (0.2, 1.0),
        _ => (0.1, 0.9),
      };
      return ease((t - start) / (end - start));
    }

    return RigPose(
      {
        for (final bone in Bone.values)
          bone: a[bone] + (b[bone] - a[bone]) * timing(bone),
      },
      mirrored: false,
      lift: a.lift + (b.lift - a.lift) * ease(t),
      depth: {
        for (final bone in Bone.values)
          bone:
              (a.depthOf(bone) +
                  (b.depthOf(bone) - a.depthOf(bone)) * timing(bone)) *
              _swing(bone, a, b, timing(bone)),
      },
    );
  }

  /// Поднимаясь, рука идёт чуть вперёд, к зрителю: в середине пути плечо,
  /// предплечье и кисть видны короче и не описывают дугу шире холста.
  /// Чем больше поворот, тем сильнее; в начале и конце — без изменений.
  static double _swing(Bone bone, RigPose a, RigPose b, double k) {
    final arm = switch (bone) {
      Bone.upperArmR ||
      Bone.upperArmL ||
      Bone.forearmR ||
      Bone.forearmL ||
      Bone.handR ||
      Bone.handL => true,
      _ => false,
    };
    if (!arm) return 1;
    final amount = ((b[bone] - a[bone]).abs() / 90).clamp(0.0, 1.0);
    return 1 - 0.75 * amount * sin(pi * k);
  }

  /// Плавный переход: углы смешиваются по каждой кости.
  static RigPose lerp(RigPose a, RigPose b, double t) => RigPose(
    {for (final bone in Bone.values) bone: a[bone] + (b[bone] - a[bone]) * t},
    mirrored: false,
    lift: a.lift + (b.lift - a.lift) * t,
    depth: {
      for (final bone in Bone.values)
        bone: a.depthOf(bone) + (b.depthOf(bone) - a.depthOf(bone)) * t,
    },
  );
}

/// Скелет в позе: мировые координаты точек и углы костей.
class PosedSkeleton {
  PosedSkeleton(this.rest, RigPose pose) {
    final p = pose.clamped();
    final lift = Offset(0, -p.lift);
    _at[Joint.pelvis] = rest[Joint.pelvis] + lift;
    // Кости идут в порядке объявления: родитель всегда раньше потомка.
    for (final b in Bone.values) {
      final parentTurn = b.parent == null ? 0.0 : _turn[b.parent!]!;
      // Положительное «наружу» для правой стороны — поворот против часовой
      // на экране (y вниз), для левой — по часовой; центр — наклон вправо.
      final own = p[b] * pi / 180 * (b.side == Side.right ? -1 : 1);
      final turn = parentTurn + own;
      _turn[b] = turn;
      _depth[b] = p.depthOf(b);
      _at[b.to] = _at[b.from]! + _rotate(rest.vector(b) * _depth[b]!, turn);
    }
  }

  final RestSkeleton rest;
  final _at = <Joint, Offset>{};
  final _turn = <Bone, double>{};
  final _depth = <Bone, double>{};

  /// Ракурс кости в этой позе (1 — в плоскости экрана).
  double depth(Bone b) => _depth[b]!;

  Offset operator [](Joint j) => _at[j]!;

  /// Полный поворот кости от покоя, радианы (y вниз: плюс — по часовой).
  double turn(Bone b) => _turn[b]!;

  /// Направление кости (единичный вектор от начала к концу).
  Offset direction(Bone b) {
    final v = this[b.to] - this[b.from];
    return v / v.distance;
  }

  static Offset _rotate(Offset v, double a) =>
      Offset(v.dx * cos(a) - v.dy * sin(a), v.dx * sin(a) + v.dy * cos(a));
}

/// Позы героя (как AvatarPose) — теперь поворотами костей.
abstract final class RigPoses {
  /// Стойка: руки чуть в стороны и согнуты, ноги на ширине плеч.
  static const relaxed = RigPose({
    Bone.upperArmR: 9,
    Bone.forearmR: -6,
    Bone.handR: -4,
    Bone.thighR: 5,
    Bone.shinR: -3,
    Bone.footR: -2,
  });

  /// Двойной бицепс: плечо в сторону горизонтально, предплечье вверх, кулак у виска.
  static const doubleBiceps = RigPose(
    {
      Bone.clavicleR: 10,
      // Ключица уже подняла плечо на 10°: плечевая кость вместе с ней — горизонталь.
      Bone.upperArmR: 80,
      Bone.forearmR: 90,
      // Кулак: кисть согнута к голове.
      Bone.handR: 75,
      Bone.chest: 0,
      Bone.thighR: 7,
      Bone.shinR: -4,
    },
    depth: {Bone.upperArmR: 0.75, Bone.forearmR: 0.92, Bone.handR: 0.8},
  );

  /// Широчайшие: кулаки на поясе, локти в стороны.
  static const latSpread = RigPose({
    Bone.clavicleR: 6,
    Bone.upperArmR: 46,
    Bone.forearmR: -112,
    Bone.handR: -20,
    Bone.thighR: 7,
    Bone.shinR: -4,
  });

  /// Руки за головой: видно пресс и бёдра.
  static const handsBehindHead = RigPose(
    {
      Bone.clavicleR: 12,
      Bone.upperArmR: 112,
      Bone.forearmR: 128,
      Bone.handR: 25,
      Bone.thighR: 6,
      Bone.shinR: -3,
    },
    depth: {Bone.upperArmR: 0.8, Bone.forearmR: 0.72, Bone.handR: 0.7},
  );

  /// Победа: руки вверх буквой V.
  static const victory = RigPose(
    {
      Bone.clavicleR: 12,
      Bone.upperArmR: 146,
      Bone.forearmR: 14,
      // Кулаки сжаты: кисть загнута к голове.
      Bone.handR: 70,
      Bone.head: 0,
      Bone.thighR: 9,
      Bone.shinR: -5,
    },
    lift: 2,
    depth: {Bone.upperArmR: 0.66, Bone.forearmR: 0.66, Bone.handR: 0.7},
  );
}
