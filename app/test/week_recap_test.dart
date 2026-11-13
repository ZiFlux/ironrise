import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/training_log.dart';
import 'package:ironrise/widgets/week_recap.dart';

void main() {
  test('итог недели: тренировки, опыт по частям, новые уровни', () {
    final hero =
        HeroProfile.create(
          nickname: 'Тест',
          goal: Goal.strength,
          format: TrainingFormat.fullBody,
          trainingDays: const [0, 2, 4],
          body: const BodyStats(),
          avatarSex: AvatarSex.male,
        ).copyWith(
          xp: {
            for (final p in BodyPart.values) p: p == BodyPart.chest ? 150 : 0,
          },
        );
    final monday = DateTime(2026, 11, 9);
    final log = [
      LoggedWorkout(
        at: monday.add(const Duration(days: 2, hours: 18)),
        kind: WorkoutKind.strength,
        duration: const Duration(minutes: 40),
        xp: 120,
        coins: 20,
        verified: true,
        gains: const {BodyPart.chest: 120},
      ),
    ];
    final r = WeekRecap.of(log, hero, monday, DateTime(2026, 11, 16, 9));
    expect(r.workouts, 1);
    expect(r.planned, 3);
    expect(r.gains[BodyPart.chest], 120);
    expect(r.levelUps[BodyPart.chest], 1);
    expect(r.powerAfter, greaterThanOrEqualTo(r.powerBefore));
    expect(WeekRecap.weekFor(DateTime(2026, 11, 16, 9)), monday);
    expect(WeekRecap.weekFor(DateTime(2026, 11, 15, 20)), monday);
  });
}
