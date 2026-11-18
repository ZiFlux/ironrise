import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/rig/skeleton.dart';

void main() {
  for (final (name, p) in [
    ('мужской', Proportions.male),
    ('женский', Proportions.female),
  ]) {
    final rest = RestSkeleton(p);

    test('$name: скелет в холсте: запас над головой, подошвы внизу', () {
      // Сверху запас под руки в позах, но не больше 1,2 головы.
      expect(rest[Joint.headTop].dy, inInclusiveRange(20, p.unit * 1.2));
      expect(rest[Joint.toeR].dy, rigSoleY);
      for (final j in Joint.values) {
        expect(rest[j].dx, inInclusiveRange(0, 200), reason: j.name);
      }
    });

    test('$name: в покое скелет симметричен', () {
      for (final b in Bone.values.where((b) => b.side == Side.right)) {
        final r = rest[b.to], l = rest[b.mirror.to];
        expect(r.dy, closeTo(l.dy, 1e-9), reason: b.name);
        expect(r.dx - rigCenterX, closeTo(rigCenterX - l.dx, 1e-9));
      }
    });

    for (final (poseName, pose) in [
      ('стойка', RigPoses.relaxed),
      ('бицепс', RigPoses.doubleBiceps),
      ('широчайшие', RigPoses.latSpread),
      ('руки за головой', RigPoses.handsBehindHead),
      ('победа', RigPoses.victory),
    ]) {
      test(
        '$name, $poseName: длины костей — с учётом ракурса, поза симметрична, всё в холсте',
        () {
          final s = PosedSkeleton(rest, pose);
          for (final b in Bone.values) {
            expect(
              (s[b.to] - s[b.from]).distance,
              closeTo(rest.vector(b).distance * s.depth(b), 1e-6),
              reason: b.name,
            );
          }
          // Ни одна точка не уходит за холст 200 × 400.
          for (final j in Joint.values) {
            expect(s[j].dy, inInclusiveRange(2, 400), reason: '${j.name} y');
            expect(s[j].dx, inInclusiveRange(2, 198), reason: '${j.name} x');
          }
          for (final b in Bone.values.where((b) => b.side == Side.right)) {
            expect(
              s[b.to].dx - rigCenterX,
              closeTo(rigCenterX - s[b.mirror.to].dx, 1e-6),
              reason: b.name,
            );
          }
        },
      );
    }

    test('$name: позы ставят руки куда задумано', () {
      final biceps = PosedSkeleton(rest, RigPoses.doubleBiceps);
      // Плечо горизонтально, кулак выше плеча и у головы.
      expect(
        (biceps[Joint.elbowR].dy - biceps[Joint.shoulderR].dy).abs(),
        lessThan(8),
      );
      expect(biceps[Joint.wristR].dy, lessThan(biceps[Joint.shoulderR].dy));
      final lats = PosedSkeleton(rest, RigPoses.latSpread);
      // Кулак на поясе: между грудью и тазом, ближе к телу, чем локоть.
      expect(
        lats[Joint.wristR].dy,
        inInclusiveRange(rest[Joint.chest].dy, rest[Joint.pelvis].dy),
      );
      expect(lats[Joint.wristR].dx, lessThan(lats[Joint.elbowR].dx));
      final behind = PosedSkeleton(rest, RigPoses.handsBehindHead);
      // Кисти у затылка: выше шеи, близко к центру.
      expect(behind[Joint.wristR].dy, lessThan(rest[Joint.neck].dy));
      expect(
        (behind[Joint.handR].dx - rigCenterX).abs(),
        lessThan(p.unit * 0.6),
      );
      final v = PosedSkeleton(rest, RigPoses.victory);
      expect(v[Joint.handR].dy, lessThan(v[Joint.headTop].dy));
      expect(v[Joint.handR].dx, greaterThan(v[Joint.shoulderR].dx));
    });
  }

  test('пределы суставов: локоть не выгибается за 150°', () {
    final s = RigPose({Bone.forearmR: 400}).clamped();
    expect(s[Bone.forearmR], 150);
    expect(s[Bone.forearmL], 150);
  });

  test('в переходах из стойки рука не вылетает за холст', () {
    for (final p in [Proportions.male, Proportions.female]) {
      final rest = RestSkeleton(p);
      for (final target in [
        RigPoses.doubleBiceps,
        RigPoses.latSpread,
        RigPoses.handsBehindHead,
        RigPoses.victory,
      ]) {
        for (var i = 0; i <= 20; i++) {
          final s = PosedSkeleton(
            rest,
            RigPose.blend(RigPoses.relaxed, target, i / 20),
          );
          // Посреди перехода кисть может на миг выйти за край на пару
          // пикселей — заметно только больше 6.
          for (final j in Joint.values) {
            expect(s[j].dx, inInclusiveRange(-6, 206), reason: '${j.name} $i');
            expect(s[j].dy, inInclusiveRange(-6, 400), reason: '${j.name} $i');
          }
        }
      }
    }
  });

  test('переход между позами плавный: середина между крайними', () {
    final rest = RestSkeleton(Proportions.male);
    final a = PosedSkeleton(rest, RigPoses.relaxed);
    final b = PosedSkeleton(rest, RigPoses.victory);
    final mid = PosedSkeleton(
      rest,
      RigPose.lerp(RigPoses.relaxed, RigPoses.victory, 0.5),
    );
    final y = mid[Joint.elbowR].dy;
    expect(y, lessThan(a[Joint.elbowR].dy));
    expect(y, greaterThan(b[Joint.elbowR].dy));
  });
}
