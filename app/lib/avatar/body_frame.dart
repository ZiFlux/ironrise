import 'dart:math';
import 'dart:ui';

import '../game/body_part.dart';
import 'avatar_look.dart';

/// Холст аватара: 200 × 400, центр тела по x = 100.
const double avatarCanvasWidth = 200;
const double avatarCanvasHeight = 400;
const double _centerX = 100;

/// Рост части тела: заметен на первых уровнях и замедляется к 40+.
double growthOf(int level) => 1 - exp(-(level - 1) / 15);

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

  Offset at(double t, double width) => start + _axis * (_length * t) + _inward * width;

  Offset get handCenter => wrist + _axis * 9;

  /// Контур по станциям (t, полуширина): вниз по одной стороне, вверх по другой.
  Path outline(List<(double, double)> stations) => smoothClosedPath([
        for (final (t, w) in stations) at(t, w),
        for (final (t, w) in stations.reversed) at(t, -w),
      ]);
}

/// Все размеры тела, посчитанные из уровней и пола.
class BodyFrame {
  factory BodyFrame(Map<BodyPart, int> levels, AvatarSex sex) {
    double g(BodyPart p) => growthOf(levels[p] ?? 1);
    return BodyFrame._(
      isFemale: sex == AvatarSex.female,
      chest: g(BodyPart.chest),
      back: g(BodyPart.back),
      arms: g(BodyPart.arms),
      legs: g(BodyPart.legs),
      core: g(BodyPart.core),
      cardio: g(BodyPart.cardio),
    );
  }

  BodyFrame._({
    required this.isFemale,
    required this.chest,
    required this.back,
    required this.arms,
    required this.legs,
    required this.core,
    required this.cardio,
  }) {
    rightArm = _armFor(1);
    leftArm = _armFor(-1);
  }

  final bool isFemale;
  final double chest, back, arms, legs, core, cardio;
  late final ArmGeometry rightArm;
  late final ArmGeometry leftArm;

  double _pick(double male, double female) => isFemale ? female : male;

  late final double neck = _pick(8.5, 6.5) + back * 2;
  late final double shoulder = _pick(34, 29) + back * _pick(14, 7) + chest * _pick(4, 2);
  late final double lat = _pick(28, 24) + back * _pick(12, 5);
  late final double waist = _pick(26, 21) - cardio * 4 - core + chest * _pick(1, 0);
  late final double ribs = _lerp(lat, waist, 0.6);
  late final double hip = _pick(26, 31) + legs * 2;
  late final double thigh = _pick(25, 30) + legs * _pick(9, 6);
  late final double knee = _pick(17, 16) + legs * 2;
  late final double calf = _pick(18, 17) + legs * _pick(6, 4);
  late final double ankle = _pick(10, 9);
  late final double shin = _lerp(calf, ankle, 0.6);
  late final double waistband = _lerp(waist, hip, 0.7);
  late final double trapX = _lerp(neck, shoulder, 0.55);

  late final double deltSize = _pick(11, 8.6) + (arms + back) / 2 * _pick(7, 3);
  late final double deltWidth = _pick(10.5, 8.5) + arms * _pick(5, 2.5) + back;
  late final double bicepWidth = _pick(8, 6.6) + arms * _pick(6.5, 3);
  late final double elbowWidth = _pick(6.2, 5.2) + arms * 2;
  late final double forearmWidth = _pick(6.8, 5.8) + arms * _pick(3.6, 2);
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
        Offset(neck - 0.5, 48), Offset(neck, 62), Offset(trapX, 70),
        Offset(shoulder - deltSize * 0.45, 81), Offset(lat + 1, 112), Offset(lat, 124),
        Offset(ribs, 150), Offset(waist, 172), Offset(hip, 200), Offset(thigh, 224),
        Offset(thigh - 3, 254), Offset(knee + 1, 290), Offset(calf, 318), Offset(shin, 350),
        Offset(ankle, 372), Offset(ankle + 4, 384), Offset(ankle + 2, 389), const Offset(4, 389),
        const Offset(4.5, 370), Offset(calf * 0.35, 330), const Offset(4.5, 292),
        const Offset(5, 254), const Offset(1.5, 228),
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
