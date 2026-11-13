import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/muscles.dart';
import 'package:ironrise/game/session_builder.dart';
import 'package:ironrise/game/training_analysis.dart';
import 'package:ironrise/game/workout.dart';
import 'package:ironrise/state/training_log.dart';

LoggedWorkout bench(DateTime at, double kg, {int sets = 3}) => LoggedWorkout(
  at: at,
  kind: WorkoutKind.strength,
  duration: const Duration(minutes: 50),
  xp: 10,
  coins: 5,
  verified: true,
  exercises: [
    (
      id: 'bench_press',
      sets: [for (var i = 0; i < sets; i++) SetRecord(weight: kg, reps: 8)],
    ),
  ],
);

void main() {
  final now = DateTime(2026, 11, 13, 20);

  test('рост виден, прогноз не выше потолка уровня', () {
    // Жим растёт по 5 кг в неделю — быстрее, чем бывает; прогноз срезан.
    final log = [
      for (var w = 0; w < 5; w++)
        bench(now.subtract(Duration(days: 7 * (4 - w))), 50 + 5.0 * w),
    ].reversed.toList();
    for (final level in TrainingLevel.values) {
      final f = TrainingAnalysis(
        log,
        level: level,
        now: now,
      ).forecast('bench_press')!;
      expect(f.trend, LiftTrend.growing);
      expect(f.weeklyPct, closeTo(TrainingAnalysis.maxWeeklyGain(level), 1e-9));
      expect(f.in12Weeks, greaterThan(f.in4Weeks));
    }
  });

  test('плато: вес стоит — тренд «на месте» и подсказка', () {
    final log = [
      for (var w = 0; w < 5; w++)
        bench(now.subtract(Duration(days: 7 * (4 - w))), 60),
    ].reversed.toList();
    final a = TrainingAnalysis(
      log,
      level: TrainingLevel.intermediate,
      now: now,
    );
    expect(a.forecast('bench_press')!.trend, LiftTrend.plateau);
    expect(a.insights(plannedPerWeek: 3).join(), contains('не растёт'));
  });

  test('мало данных — прогноза нет', () {
    final log = [
      bench(now, 60),
      bench(now.subtract(const Duration(days: 3)), 60),
    ];
    expect(
      TrainingAnalysis(
        log,
        level: TrainingLevel.novice,
        now: now,
      ).forecast('bench_press'),
      isNull,
    );
  });

  test('подходы на мышцы за неделю: жим — грудь целиком, трицепс частично', () {
    final a = TrainingAnalysis(
      [bench(now, 60, sets: 4)],
      level: TrainingLevel.novice,
      now: now,
    );
    final sets = a.muscleSets();
    expect(sets[Muscle.pecs], 4);
    expect(sets[Muscle.triceps], closeTo(2, 1e-9));
  });
}
