import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/schedule.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/widgets/schedule_picker.dart';

void main() {
  test('первая смена графика — сразу, следующая — через неделю', () {
    final now = DateTime(2026, 11, 12, 12);
    expect(canChangeSchedule(null, now), isTrue);
    expect(canChangeSchedule(now.add(const Duration(days: 3)), now), isFalse);
    expect(
      canChangeSchedule(now.subtract(const Duration(minutes: 1)), now),
      isTrue,
    );
  });

  test('стиль не зависит от числа дней (TRAINING_SYSTEM.md 14)', () {
    // Фулбоди Пн/Ср/Пт: Пт → Сб — тренировок всё ещё 3.
    final moved = toggleTrainingDay(TrainingFormat.fullBody, {0, 2}, 5, true);
    expect(moved.format, TrainingFormat.fullBody);
    final more = toggleTrainingDay(TrainingFormat.fullBody, {0, 2, 4}, 6, true);
    expect(more.format, TrainingFormat.fullBody);
    expect(more.days, {0, 2, 4, 6});
  });

  test('дата следующей смены графика сохраняется в герое', () {
    final next = DateTime.utc(2026, 11, 19, 10);
    final hero =
        HeroProfile.create(
          nickname: 'Тест',
          goal: Goal.strength,
          format: TrainingFormat.fullBody,
          trainingDays: const [0, 2, 4],
          body: const BodyStats(),
          avatarSex: AvatarSex.male,
        ).copyWith(
          format: TrainingFormat.upperLower,
          trainingDays: const [0, 1, 3, 4],
          nextScheduleChangeAt: next,
        );
    final back = HeroProfile.decode(hero.encode());
    expect(back.format, TrainingFormat.upperLower);
    expect(back.trainingDays, [0, 1, 3, 4]);
    expect(back.nextScheduleChangeAt, next);
    expect(
      back.copyWith(scheduleChangeAllowed: true).nextScheduleChangeAt,
      isNull,
    );
  });
}
