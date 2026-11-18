import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/avatar/body_frame.dart';
import 'package:ironrise/avatar/rig/body.dart';
import 'package:ironrise/avatar/rig/skeleton.dart';
import 'package:ironrise/game/body_part.dart';

void main() {
  const poses = [
    RigPoses.relaxed,
    RigPoses.doubleBiceps,
    RigPoses.latSpread,
    RigPoses.handsBehindHead,
    RigPoses.victory,
  ];

  for (final (sex, p) in [
    (AvatarSex.male, Proportions.male),
    (AvatarSex.female, Proportions.female),
  ]) {
    test('${sex.name}: тело строится при любом уровне, сложении и позе '
        'и помещается в холст', () {
      final rest = RestSkeleton(p);
      for (final level in [1, 10, 25, 60]) {
        for (final build in BodyBuild.values) {
          for (final pose in poses) {
            final body = RigBody(
              PosedSkeleton(rest, pose),
              BodyFrame(
                {for (final b in BodyPart.values) b: level},
                sex,
                build,
              ),
            );
            final r = body.silhouette.getBounds();
            // Мышцы и одежда чуть выходят за холст — не больше 12 px.
            expect(r.left, greaterThan(-12), reason: '$level $build $pose');
            expect(r.right, lessThan(212), reason: '$level $build $pose');
            expect(r.top, greaterThan(-12), reason: '$level $build $pose');
            expect(r.bottom, lessThan(402), reason: '$level $build $pose');
          }
        }
      }
    });

    test('${sex.name}: с уровнем торс шире', () {
      final rest = RestSkeleton(p);
      double width(num level) => RigBody(
        PosedSkeleton(rest, RigPoses.doubleBiceps),
        BodyFrame({for (final b in BodyPart.values) b: level}, sex),
      ).torso.getBounds().width;
      // У женщин торс шире всего в тазу, а мышцы растут мягче — прибавка меньше.
      expect(
        width(60),
        greaterThan(width(1) + (sex == AvatarSex.male ? 6 : 2)),
      );
    });
  }
}
