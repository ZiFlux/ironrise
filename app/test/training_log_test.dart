import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/training_stats.dart';
import 'package:ironrise/game/workout.dart';
import 'package:ironrise/state/training_log.dart';

LoggedWorkout _w(DateTime at, WorkoutKind kind, {double weight = 50}) =>
    LoggedWorkout(
      at: at,
      kind: kind,
      duration: const Duration(minutes: 40),
      xp: 100,
      coins: 20,
      verified: true,
      exercises: kind == WorkoutKind.strength
          ? [
              (
                id: 'bench_press',
                sets: [
                  SetRecord(weight: weight, reps: 10),
                  SetRecord(weight: weight, reps: 8),
                ],
              ),
            ]
          : const [],
      gains: {BodyPart.chest: 70},
    );

void main() {
  final now = DateTime(2026, 11, 12, 18);

  test('лимит: одна силовая и одна кардио в день', () {
    final log = [_w(DateTime(2026, 11, 12, 9), WorkoutKind.strength)];
    expect(doneToday(log, WorkoutKind.strength, now), isTrue);
    expect(doneToday(log, WorkoutKind.cardio, now), isFalse);
    expect(
      doneToday(log, WorkoutKind.strength, DateTime(2026, 11, 13, 8)),
      isFalse,
    );
  });

  test('журнал переживает сохранение', () {
    final w = _w(now, WorkoutKind.strength);
    final back = LoggedWorkout.fromJson(w.toJson());
    expect(back.volume, w.volume);
    expect(back.gains, w.gains);
    expect(back.exercises.single.sets.length, 2);
  });

  test('статистика: объём по неделям и динамика упражнения', () {
    final stats = TrainingStats([
      _w(DateTime(2026, 11, 11), WorkoutKind.strength, weight: 60),
      _w(DateTime(2026, 11, 4), WorkoutKind.strength, weight: 50),
      _w(DateTime(2026, 11, 3), WorkoutKind.cardio),
    ]);
    final weeks = stats.weekly(now, weeks: 2);
    expect(weeks.last.volume, 60 * 18);
    expect(weeks.first.workouts, 2);
    final progress = stats.progressOf('bench_press');
    expect(progress.first.value, lessThan(progress.last.value));
    expect(stats.gainsInLastDays(30, now)[BodyPart.chest], 210);
  });
}
