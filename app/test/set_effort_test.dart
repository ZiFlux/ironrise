import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/anti_fraud.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/set_effort.dart';
import 'package:ironrise/game/workout.dart';

void main() {
  final t0 = DateTime(2026, 11, 12, 18);

  /// Пульс каждые 5 с: отдых 90, во время подходов (до отметок) — до [peak].
  List<PulseSample> pulse(List<(DateTime, int)> sets) => [
    for (var s = 0; s <= 900; s += 5)
      () {
        final at = t0.add(Duration(seconds: s));
        for (final (logged, peak) in sets) {
          final d = logged.difference(at).inSeconds;
          if (d >= 0 && d <= 40) return PulseSample(at, peak);
        }
        return PulseSample(at, 90);
      }(),
  ];

  WorkoutSession session(
    List<DateTime> squat,
    List<DateTime> curl,
  ) => WorkoutSession(
    startedAt: t0,
    entries: [
      ExerciseEntry(
        exercise: ExerciseCatalog.byId('barbell_squat'),
        sets: [for (final at in squat) SetRecord(weight: 60, reps: 8, at: at)],
      ),
      ExerciseEntry(
        exercise: ExerciseCatalog.byId('db_curl'),
        sets: [for (final at in curl) SetRecord(weight: 10, reps: 12, at: at)],
      ),
    ],
  );

  test('присед поднимает пульс сильнее сгибаний, тяжесть по резерву', () {
    final squat = [
      t0.add(const Duration(seconds: 120)),
      t0.add(const Duration(seconds: 300)),
    ];
    final curl = [
      t0.add(const Duration(seconds: 500)),
      t0.add(const Duration(seconds: 680)),
    ];
    final a = SetEffortAnalysis.of(
      session(squat, curl),
      pulse([for (final s in squat) (s, 160), for (final c in curl) (c, 115)]),
      restingHr: 60,
      maxHr: 190,
    )!;
    expect(a.sets.length, 4);
    expect(
      a.riseByExercise['barbell_squat']!,
      greaterThan(a.riseByExercise['db_curl']!),
    );
    expect(a.sets.first.level, EffortLevel.hard);
    expect(a.flatSets, isEmpty);
  });

  test('подход без подъёма пульса отмечается', () {
    final squat = [t0.add(const Duration(seconds: 120))];
    final curl = [t0.add(const Duration(seconds: 400))];
    final a = SetEffortAnalysis.of(
      session(squat, curl),
      pulse([(squat.first, 150)]),
      restingHr: 60,
      maxHr: 190,
    )!;
    expect(a.flatSets.single.exerciseId, 'db_curl');
  });

  test('без времени подходов анализа нет', () {
    final s = WorkoutSession(
      startedAt: t0,
      entries: [
        ExerciseEntry(
          exercise: ExerciseCatalog.byId('db_curl'),
          sets: const [SetRecord(weight: 10, reps: 12)],
        ),
      ],
    );
    expect(
      SetEffortAnalysis.of(s, pulse(const []), restingHr: 60, maxHr: 190),
      isNull,
    );
  });

  test('подсказка отдыха — в конце отдыха и при высоком пульсе', () {
    String? hint(int bpm, int left) => SetEffortAnalysis.restHint(
      bpm: bpm,
      left: Duration(seconds: left),
      restingHr: 60,
      maxHr: 190,
    );
    expect(hint(150, 10), isNotNull);
    expect(hint(150, 60), isNull);
    expect(hint(100, 5), isNull);
  });
}
