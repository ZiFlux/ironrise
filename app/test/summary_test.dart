import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/avatar/avatar_look.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/state/hero.dart';
import 'package:ironrise/state/summary_publisher.dart';
import 'package:ironrise/state/training_log.dart';

LoggedWorkout done(WorkoutKind kind, DateTime at) => LoggedWorkout(
  at: at,
  kind: kind,
  duration: const Duration(minutes: 40),
  xp: 10,
  coins: 5,
  verified: true,
);

void main() {
  final hero = HeroProfile.create(
    nickname: 'Тест',
    goal: Goal.values.first,
    format: TrainingFormat.values.first,
    trainingDays: const [0, 2, 4], // пн, ср, пт
    body: const BodyStats(),
    avatarSex: AvatarSex.male,
  );
  final monday = DateTime(2026, 11, 9, 12);
  final tuesday = DateTime(2026, 11, 10, 12);

  test('что сегодня: тренировка, отдых, сделано', () {
    expect(summaryOf(hero, const [], 'Верх', monday).today, 'Сегодня: Верх');
    expect(summaryOf(hero, const [], 'Верх', tuesday).today, 'Сегодня отдых');
    expect(
      summaryOf(
        hero,
        [done(WorkoutKind.strength, monday)],
        'Верх',
        monday,
      ).today,
      'Силовая сделана',
    );
    expect(
      summaryOf(
        hero,
        [done(WorkoutKind.strength, monday), done(WorkoutKind.cardio, monday)],
        'Верх',
        monday,
      ).today,
      'На сегодня всё — отдых',
    );
    expect(
      summaryOf(hero, const [], 'Верх', monday).level,
      startsWith('Герой '),
    );
  });
}
