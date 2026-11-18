import 'dart:math';
import 'dart:ui';

import '../game/body_part.dart';
import '../game/muscles.dart';
import 'avatar_look.dart';

/// Холст аватара: 200 × 400, центр тела по x = 100.
const double avatarCanvasWidth = 200;
const double avatarCanvasHeight = 400;
const double _centerX = 100;

/// Рост части тела: заметен на первых уровнях и замедляется к 40+.
double growthOf(num level) => 1 - exp(-(level - 1) / 15);

double _lerp(double a, double b, double t) => a + (b - a) * t;

/// Замкнутая гладкая кривая через точки (Catmull-Rom).
Path smoothClosedPath(List<Offset> points) {
  final n = points.length;
  final path = Path()..moveTo(points[0].dx, points[0].dy);
  for (var i = 0; i < n; i++) {
    final p0 = points[(i - 1 + n) % n];
    final p1 = points[i];
    final p2 = points[(i + 1) % n];
    final p3 = points[(i + 2) % n];
    final c1 = p1 + (p2 - p0) / 6;
    final c2 = p2 - (p3 - p1) / 6;
    path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
  }
  return path..close();
}

/// Правая половина контура зеркалится в левую: точки заданы как (отступ от центра, y).
Path mirroredPath(List<Offset> rightHalf) => smoothClosedPath([
  for (final p in rightHalf) Offset(_centerX + p.dx, p.dy),
  for (final p in rightHalf.reversed) Offset(_centerX - p.dx, p.dy),
]);

Path polygonPath(List<Offset> points) => Path()..addPolygon(points, true);

/// Рука как ось плечо → локоть → запястье. Положительная ширина смотрит к центру
/// тела. Прямая рука — локоть на линии; в позах (AvatarPose) рука сгибается.
class ArmGeometry {
  ArmGeometry({
    required this.start,
    required this.wrist,
    required int side,
    Offset? elbow,
  }) : elbow = elbow ?? Offset.lerp(start, wrist, elbowT)!,
       _side = side.toDouble() {
    _upper = _unit(this.elbow - start);
    _fore = _unit(wrist - this.elbow);
  }

  /// Доля длины руки до локтя (станция локтя в armStations).
  static const elbowT = 0.52;

  /// Вокруг локтя направление плавно переходит с плеча на предплечье.
  static const _blend = 0.1;

  final Offset start;
  final Offset elbow;
  final Offset wrist;
  final double _side;
  late final Offset _upper;
  late final Offset _fore;

  static Offset _unit(Offset v) =>
      v.distance == 0 ? const Offset(0, 1) : v / v.distance;

  Offset _dirAt(double t) {
    final k = ((t - (elbowT - _blend)) / (2 * _blend)).clamp(0.0, 1.0);
    return _unit(Offset.lerp(_upper, _fore, k)!);
  }

  Offset at(double t, double width) {
    final p = t <= elbowT
        ? start + (elbow - start) * (t / elbowT)
        : elbow + (wrist - elbow) * ((t - elbowT) / (1 - elbowT));
    final d = _dirAt(t);
    return p + Offset(-d.dy * _side, d.dx * _side) * width;
  }

  Offset get handCenter => wrist + _fore * 9;

  /// Кисть: от запястья вдоль предплечья — шире у ладони, скруглённый край.
  /// Поворачивается вместе с рукой (овал не поворачивался и висел «ракеткой»).
  Path hand(double wristHalf, double length) {
    final d = _fore;
    // Сторона руки: у левой и правой кисти большой палец к телу (раньше обе
    // были «правыми»).
    final n = Offset(-d.dy, d.dx) * _side;
    Offset p(double along, double across) => wrist + d * along + n * across;
    // Большой палец — со стороны тела, у основания ладони.
    return smoothClosedPath([
      p(-1.5, wristHalf + 0.3),
      p(length * 0.22, wristHalf + 2.4),
      p(length * 0.42, wristHalf + 3.1),
      p(length * 0.55, wristHalf + 1.6),
      p(length * 0.8, wristHalf + 1.2),
      p(length, 0.3),
      p(length * 0.92, -wristHalf - 0.6),
      p(length * 0.62, -wristHalf - 1.7),
      p(length * 0.3, -wristHalf - 1.6),
      p(-1.5, -wristHalf - 0.3),
    ]);
  }

  /// Контур по станциям (t, полуширина): вниз по одной стороне, вверх по другой.
  Path outline(List<(double, double)> stations) => smoothClosedPath([
    for (final (t, w) in stations) at(t, w),
    for (final (t, w) in stations.reversed) at(t, -w),
  ]);
}

/// Позы героя на главном экране (п. 31 бэклога): показывают сильные мышцы.
enum AvatarPose { relaxed, doubleBiceps, latSpread, handsBehindHead, victory }

/// Все размеры тела, посчитанные из уровней и пола.
class BodyFrame {
  factory BodyFrame(
    Map<BodyPart, num> levels,
    AvatarSex sex, [
    BodyBuild build = BodyBuild.average,
    MusclePoints muscles = const {},
    AvatarPose pose = AvatarPose.relaxed,
    double poseT = 0,
  ]) {
    double g(BodyPart p) => growthOf(levels[p] ?? 1);
    // Мышца растёт вместе со своей частью тела, но пропорционально тренировкам:
    // перекачанная — крупнее, забытая — мельче, гротескная — заметно раздута.
    final balance = MuscleMath.balance(muscles);
    final grotesque = MuscleMath.grotesque(muscles);
    // Гротеск — прибавка сверху, а не множитель: иначе на низких уровнях его не видно.
    double mg(Muscle m) =>
        g(m.part) * balance[m]! +
        (m == grotesque ? MuscleMath.grotesqueBoost : 0);
    final burn = (g(BodyPart.cardio) + g(BodyPart.core)) / 2;
    final muscle =
        (g(BodyPart.chest) +
            g(BodyPart.back) +
            g(BodyPart.arms) +
            g(BodyPart.legs)) /
        4;
    return BodyFrame._(
      isFemale: sex == AvatarSex.female,
      // Лишнее уходит с кардио и прессом, худоба — с ростом мышц, но не до нуля сразу.
      fat: switch (build) {
        BodyBuild.slim => -1 + muscle * 0.8,
        BodyBuild.average => 0,
        BodyBuild.solid => 0.5 * (1 - burn * 0.8),
        BodyBuild.heavy => 1.0 * (1 - burn * 0.8),
      },
      chest: mg(Muscle.pecs),
      back: g(BodyPart.back),
      arms: g(BodyPart.arms),
      legs: g(BodyPart.legs),
      core: mg(Muscle.abs),
      cardio: g(BodyPart.cardio),
      lats: mg(Muscle.lats),
      traps: mg(Muscle.traps),
      delts: mg(Muscle.delts),
      // Спереди виден бицепс, поэтому он весит больше трицепса.
      upperArm: mg(Muscle.biceps) * 0.65 + mg(Muscle.triceps) * 0.35,
      forearms: mg(Muscle.forearms),
      thighs: mg(Muscle.quads) * 0.7 + mg(Muscle.hamstrings) * 0.3,
      glutes: mg(Muscle.glutes),
      calves: mg(Muscle.calves),
      pose: pose,
      poseT: poseT,
    );
  }

  BodyFrame._({
    required this.isFemale,
    required this.fat,
    required this.chest,
    required this.back,
    required this.arms,
    required this.legs,
    required this.core,
    required this.cardio,
    required this.lats,
    required this.traps,
    required this.delts,
    required this.upperArm,
    required this.forearms,
    required this.thighs,
    required this.glutes,
    required this.calves,
    this.pose = AvatarPose.relaxed,
    this.poseT = 0,
  }) {
    rightArm = _armFor(1);
    leftArm = _armFor(-1);
  }

  /// Поза и насколько в неё вошли (0 — стойка, 1 — поза).
  final AvatarPose pose;
  final double poseT;

  final bool isFemale;

  /// Телосложение: −1 худощавое … 0 среднее … 1 крупное (с поправкой на прогресс).
  final double fat;

  /// Рост частей тела 0…1; chest и core — уже с учётом мышц (грудные, пресс).
  final double chest, back, arms, legs, core, cardio;

  /// Рост отдельных мышц: часть тела × баланс тренировок (может быть больше 1).
  final double lats, traps, delts, upperArm, forearms, thighs, glutes, calves;
  late final ArmGeometry rightArm;
  late final ArmGeometry leftArm;

  double _pick(double male, double female) => isFemale ? female : male;

  late final double neck = _pick(9.6, 7.2) + traps * 2 + fat * 3;
  late final double shoulder =
      _pick(34, 29) + (lats + traps) / 2 * _pick(14, 7) + chest * _pick(4, 2);
  late final double lat =
      _pick(28, 24) +
      lats * _pick(12, 5) +
      fat * 6 +
      (pose == AvatarPose.latSpread ? poseT * 3 : 0);
  late final double waist = max(
    // Даже у худых талия не «осиная»: не уже этого минимума.
    _pick(19, 20),
    _pick(26, 24.5) -
        cardio * _pick(4, 2.5) -
        core * _pick(1, 0.6) +
        chest * _pick(1, 0) +
        fat * _pick(15, 11),
  );
  late final double ribs = _lerp(lat, waist, isFemale ? 0.5 : 0.6);
  late final double hip =
      _pick(26, 31) + glutes * _pick(2, 4) + fat * _pick(9, 10);
  late final double thigh = _pick(26, 32) + thighs * _pick(9, 6) + fat * 7;
  late final double knee = max(
    _pick(18.5, 18.5) + legs * 2 + fat * 4,
    // Колено не уже икры на 1,5 и не глубже бедра на 9 — нога ровная, без перехвата.
    min(calf - 1.5, thigh - 9),
  );
  late final double calf = _pick(20, 20.5) + calves * _pick(6, 4.5) + fat * 5;
  late final double ankle = _pick(10.5, 10) + max(fat, 0.0) * 2;
  late final double shin = _lerp(calf, ankle, 0.6);
  late final double waistband = _lerp(waist, hip, 0.7);
  late final double trapX = _lerp(neck, shoulder, 0.5);

  /// Стойка: ноги на ширине плеч — каждая половина ниже таза повёрнута
  /// вокруг своего тазобедренного сустава на этот угол (радианы).
  late final double stanceAngle = _pick(0.075, 0.045);

  /// Ниже этой линии рисуются ноги в стойке; таз — точка поворота.
  static const stanceTop = 204.0;
  late final double hipJointX = hip * 0.45;

  late final double deltSize =
      _pick(11, 8.6) + (delts + traps) / 2 * _pick(7, 3);
  late final double deltWidth = _pick(10.5, 8.5) + delts * _pick(5, 2.5) + lats;
  late final double bicepWidth =
      _pick(8, 6.6) +
      upperArm * _pick(6.5, 3) +
      // Перекачанный бицепс выпирает сильнее, чем растёт обычный.
      max(0.0, upperArm - 1) * _pick(6, 3) +
      max(fat, -0.4) * 3.5;
  late final double elbowWidth =
      _pick(6.2, 5.2) + (upperArm + forearms) / 2 * 2;
  late final double forearmWidth =
      _pick(6.8, 5.8) + forearms * _pick(3.6, 2) + max(fat, -0.4) * 2;
  late final double wristWidth = _pick(4.6, 3.9);

  // Голова крупнее (~8 голов роста вместо 9,5): герой читается на телефоне.
  late final double headRx = _pick(18, 16.2);
  late final double headRy = _pick(22, 21);
  static const headCenter = Offset(_centerX, 30);

  ArmGeometry _armFor(int side) {
    final start = Offset(_centerX + side * (shoulder - deltWidth + 1.5), 84);
    final wrist = Offset(
      _centerX + side * (shoulder + _pick(13, 10) + arms * 4 + fat * 3),
      204,
    );
    // В покое рука не висит палкой вдоль тела: локоть чуть отведён наружу.
    final relaxedElbow =
        Offset.lerp(start, wrist, ArmGeometry.elbowT)! +
        Offset(side * _pick(4, 3), 0);
    final target = _poseTarget(side);
    if (target == null || poseT <= 0) {
      return ArmGeometry(
        start: start,
        elbow: relaxedElbow,
        wrist: wrist,
        side: side,
      );
    }
    final t = poseT.clamp(0.0, 1.0);
    return ArmGeometry(
      start: start,
      elbow: Offset.lerp(relaxedElbow, target.elbow, t),
      wrist: Offset.lerp(wrist, target.wrist, t)!,
      side: side,
    );
  }

  /// Куда в позе идут локоть и запястье (холст 200×400). null — стойка.
  ({Offset elbow, Offset wrist})? _poseTarget(int side) {
    double x(double dx) => _centerX + side * dx;
    return switch (pose) {
      AvatarPose.relaxed => null,
      // Плечо в сторону на уровне плеч, предплечье вверх: кулаки у висков.
      AvatarPose.doubleBiceps => (
        elbow: Offset(x(shoulder + 30 + arms * 4), 96),
        wrist: Offset(x(shoulder + 22), 44),
      ),
      // Кулаки на поясе, локти в стороны: широчайшие раскрываются.
      AvatarPose.latSpread => (
        elbow: Offset(x(shoulder + 22 + arms * 3), 138),
        wrist: Offset(x(waist + 2), 170),
      ),
      // Руки за головой: видно пресс и бёдра.
      AvatarPose.handsBehindHead => (
        elbow: Offset(x(shoulder + 18), 42),
        wrist: Offset(x(10), 18),
      ),
      // Поза победы (веха героя 5): руки вверх буквой V.
      AvatarPose.victory => (
        elbow: Offset(x(shoulder + 14), 46),
        wrist: Offset(x(shoulder + 24), 6),
      ),
    };
  }

  List<(double, double)> get armStations => [
    (0, deltWidth * 0.8),
    (0.06, deltWidth),
    (0.2, deltWidth * 0.92),
    (0.36, bicepWidth),
    (0.52, elbowWidth),
    (0.66, forearmWidth),
    (0.9, wristWidth),
    (1, wristWidth),
  ];

  /// Контур тела без рук. Плечо сужено: стык с рукой закрывает дельта.
  Path get bodyOutline => mirroredPath([
    // Верх шеи у тела — уже подбородка, иначе углы торчат под челюстью.
    Offset(min(neck * 0.78, headHalfWidthAt(47) * 0.85), 47),
    Offset(neck * 0.9, 58),
    Offset(trapX, 70),
    Offset(shoulder - deltSize * 0.5, 77),
    Offset(shoulder - deltSize * 0.08, 86),
    Offset(shoulder - deltSize * 0.22, 100),
    Offset(lat + 1 + chest * _pick(4, 2), 112),
    Offset(lat, 124),
    Offset(ribs, 150),
    Offset(waist, 172),
    Offset(hip, 200),
    Offset(thigh, 224),
    Offset(thigh - 3, 254),
    Offset(knee + 1, 290),
    Offset(calf, 314),
    Offset(shin, 348),
    Offset(ankle, 372),
    Offset(ankle + 4, 384),
    Offset(ankle + 2, 389),
    const Offset(4, 389),
    const Offset(4.5, 370),
    // Голень прямая: внутренняя головка икры чуть к центру, ниже — ровно.
    const Offset(4.6, 352),
    const Offset(3.4, 322),
    const Offset(4.5, 292),
    const Offset(5, 254),
    const Offset(1.5, 228),
  ]);

  /// Дельта: каплевидная мышца на верхушке руки — округлая сверху, книзу
  /// сходит клином в контур плеча (раньше обрывалась круглым краем — «шар»).
  /// grow расширяет её под рукав.
  Path deltCap(ArmGeometry arm, {double grow = 0}) {
    // Ширина руки снаружи там, где дельта сливается с плечом.
    final armAt = _lerp(deltWidth * 0.92, bicepWidth, 0.25);
    return smoothClosedPath([
      arm.at(-0.07, -(deltSize * 0.15 + grow)),
      arm.at(-0.01, -(deltSize * 0.86 + grow)),
      arm.at(0.08, -(deltSize * 1.08 + grow)),
      arm.at(0.18, -(max(deltSize * 0.9, armAt * 1.04) + grow)),
      arm.at(0.27, -(armAt * 1.02 + grow)),
      arm.at(0.34, -(armAt * 0.98 + grow)),
      arm.at(0.34, -(armAt * 0.6)),
      arm.at(0.24, deltSize * 0.1 + grow),
      arm.at(0.1, deltSize * 0.55 + grow),
      arm.at(-0.03, deltSize * 0.42 + grow),
    ]);
  }

  /// Голова по-мужски: черепная коробка, висок, скула, угол челюсти и
  /// широкий подбородок; у героини — мягче и уже книзу. Не просто овал.
  Path get headShape {
    final c = headCenter;
    Offset p(double x, double y) =>
        Offset(c.dx + x * headRx, c.dy + y * headRy);
    final half = isFemale
        ? const [
            Offset(0.6, -0.93),
            Offset(0.9, -0.64),
            Offset(1.0, -0.26),
            // Скулы выше, дальше — плавно к узкому подбородку.
            Offset(0.97, 0.04),
            Offset(0.84, 0.38),
            Offset(0.6, 0.7),
            Offset(0.32, 0.9),
            Offset(0.13, 0.98),
          ]
        : const [
            Offset(0.62, -0.92),
            Offset(0.92, -0.62),
            Offset(1.0, -0.22),
            // Скула.
            Offset(1.0, 0.1),
            // Угол челюсти.
            Offset(0.94, 0.46),
            Offset(0.84, 0.66),
            Offset(0.52, 0.9),
            // Широкий подбородок.
            Offset(0.27, 1.0),
          ];
    return smoothClosedPath([
      p(0, -1),
      for (final o in half) p(o.dx, o.dy),
      p(0, isFemale ? 0.99 : 1.03),
      for (final o in half.reversed) p(-o.dx, o.dy),
    ]);
  }

  /// Уши: по бокам головы на уровне скулы.
  List<Path> get ears => [
    for (final s in const [-1.0, 1.0])
      Path()..addOval(
        Rect.fromCenter(
          center: headCenter + Offset(s * headRx * 0.98, headRy * 0.02),
          width: 5.5,
          height: headRy * 0.46,
        ),
      ),
  ];

  double headHalfWidthAt(double y) =>
      headRx * sqrt(max(0, 1 - pow((y - headCenter.dy) / headRy, 2)));
}
