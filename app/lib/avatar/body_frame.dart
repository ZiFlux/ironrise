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

/// Рука как ось от плеча к запястью. Положительная ширина смотрит к центру тела.
class ArmGeometry {
  ArmGeometry({required this.start, required this.wrist, required int side})
    : _axis = (wrist - start) / (wrist - start).distance,
      _length = (wrist - start).distance,
      _side = side.toDouble();

  final Offset start;
  final Offset wrist;
  final Offset _axis;
  final double _length;
  final double _side;

  Offset get _inward => Offset(-_axis.dy * _side, _axis.dx * _side);

  Offset at(double t, double width) =>
      start + _axis * (_length * t) + _inward * width;

  Offset get handCenter => wrist + _axis * 9;

  /// Контур по станциям (t, полуширина): вниз по одной стороне, вверх по другой.
  Path outline(List<(double, double)> stations) => smoothClosedPath([
    for (final (t, w) in stations) at(t, w),
    for (final (t, w) in stations.reversed) at(t, -w),
  ]);
}

/// Все размеры тела, посчитанные из уровней и пола.
class BodyFrame {
  factory BodyFrame(
    Map<BodyPart, num> levels,
    AvatarSex sex, [
    BodyBuild build = BodyBuild.average,
    MusclePoints muscles = const {},
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
  }) {
    rightArm = _armFor(1);
    leftArm = _armFor(-1);
  }

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

  late final double neck = _pick(8.5, 6.5) + traps * 2 + fat * 3;
  late final double shoulder =
      _pick(34, 29) + (lats + traps) / 2 * _pick(14, 7) + chest * _pick(4, 2);
  late final double lat = _pick(28, 24) + lats * _pick(12, 5) + fat * 6;
  late final double waist =
      _pick(26, 21) -
      cardio * 4 -
      core +
      chest * _pick(1, 0) +
      fat * _pick(15, 11);
  late final double ribs = _lerp(lat, waist, 0.6);
  late final double hip =
      _pick(26, 31) + glutes * _pick(2, 4) + fat * _pick(9, 10);
  late final double thigh = _pick(25, 30) + thighs * _pick(9, 6) + fat * 7;
  late final double knee = _pick(17, 16) + legs * 2;
  late final double calf = _pick(18, 17) + calves * _pick(6, 4) + fat * 3;
  late final double ankle = _pick(10, 9);
  late final double shin = _lerp(calf, ankle, 0.6);
  late final double waistband = _lerp(waist, hip, 0.7);
  late final double trapX = _lerp(neck, shoulder, 0.55);

  late final double deltSize =
      _pick(11, 8.6) + (delts + traps) / 2 * _pick(7, 3);
  late final double deltWidth = _pick(10.5, 8.5) + delts * _pick(5, 2.5) + lats;
  late final double bicepWidth =
      _pick(8, 6.6) +
      upperArm * _pick(6.5, 3) +
      // Перекачанный бицепс выпирает сильнее, чем растёт обычный.
      max(0.0, upperArm - 1) * _pick(6, 3) +
      fat * 3.5;
  late final double elbowWidth =
      _pick(6.2, 5.2) + (upperArm + forearms) / 2 * 2;
  late final double forearmWidth =
      _pick(6.8, 5.8) + forearms * _pick(3.6, 2) + fat * 2;
  late final double wristWidth = _pick(4.1, 3.4);

  late final double headRx = _pick(16, 15);
  late final double headRy = _pick(20, 19);
  static const headCenter = Offset(_centerX, 30);

  ArmGeometry _armFor(int side) => ArmGeometry(
    start: Offset(_centerX + side * (shoulder - deltWidth + 1.5), 84),
    wrist: Offset(_centerX + side * (shoulder + 7 + arms * 4), 206),
    side: side,
  );

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
    Offset(neck - 0.5, 48),
    Offset(neck, 62),
    Offset(trapX, 70),
    Offset(shoulder - deltSize * 0.45, 81),
    Offset(lat + 1 + chest * _pick(4, 2), 112),
    Offset(lat, 124),
    Offset(ribs, 150),
    Offset(waist, 172),
    Offset(hip, 200),
    Offset(thigh, 224),
    Offset(thigh - 3, 254),
    Offset(knee + 1, 290),
    Offset(calf, 318),
    Offset(shin, 350),
    Offset(ankle, 372),
    Offset(ankle + 4, 384),
    Offset(ankle + 2, 389),
    const Offset(4, 389),
    const Offset(4.5, 370),
    Offset(calf * 0.35, 330),
    const Offset(4.5, 292),
    const Offset(5, 254),
    const Offset(1.5, 228),
  ]);

  /// Дельта: округлый колпак на верхушке руки. grow расширяет его под рукав.
  Path deltCap(ArmGeometry arm, {double grow = 0}) => smoothClosedPath([
    arm.at(-0.07, -(deltSize * 0.15 + grow)),
    arm.at(-0.01, -(deltSize * 0.9 + grow)),
    arm.at(0.09, -(deltSize * 1.14 + grow)),
    arm.at(0.19, -(deltSize * 0.92 + grow)),
    arm.at(0.27, -(deltSize * 0.3 + grow)),
    arm.at(0.2, deltSize * 0.3 + grow),
    arm.at(0.08, deltSize * 0.6 + grow),
    arm.at(-0.03, deltSize * 0.42 + grow),
  ]);

  double headHalfWidthAt(double y) =>
      headRx * sqrt(max(0, 1 - pow((y - headCenter.dy) / headRy, 2)));
}
