import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';
import 'package:ironrise/game/workout.dart';

const squat = PlannedExercise(
  'barbell_squat',
  sets: 2,
  repsMin: 10,
  repsMax: 12,
  repsInReserve: 3,
);
const bench = PlannedExercise(
  'bench_press',
  sets: 2,
  repsMin: 10,
  repsMax: 12,
  repsInReserve: 3,
);
const pushUps = PlannedExercise(
  'push_up',
  sets: 2,
  repsMin: 10,
  repsMax: 12,
  repsInReserve: 3,
);

List<SetRecord> sets(double weight, List<int> reps) => [
  for (final r in reps) SetRecord(weight: weight, reps: r),
];

ProgressChange step(
  PlannedExercise plan,
  ExerciseProgress current,
  List<SetRecord> done, {
  bool reserve = true,
}) => DoubleProgression.next(
  plan: plan,
  current: current,
  sets: done,
  hadReserve: reserve,
);

void main() {
  group('двойная прогрессия', () {
    test('первая тренировка задаёт рабочий вес', () {
      final c = step(squat, const ExerciseProgress(), sets(30, [12, 12]));
      expect(c.kind, ProgressKind.calibrated);
      expect(c.after.workingWeight, 30);
    });

    test('верх диапазона с запасом — вес растёт: ноги до 40 кг на 2,5', () {
      final c = step(
        squat,
        const ExerciseProgress(workingWeight: 30),
        sets(30, [12, 12]),
      );
      expect(c.kind, ProgressKind.increase);
      expect(c.after.workingWeight, 32.5);
    });

    test('ноги от 40 кг — на 5, жимы — на 2,5', () {
      expect(
        step(
          squat,
          const ExerciseProgress(workingWeight: 40),
          sets(40, [12, 12]),
        ).after.workingWeight,
        45,
      );
      expect(
        step(
          bench,
          const ExerciseProgress(workingWeight: 40),
          sets(40, [12, 12]),
        ).after.workingWeight,
        42.5,
      );
    });

    test('впритык — вес не растёт', () {
      final c = step(
        squat,
        const ExerciseProgress(workingWeight: 30),
        sets(30, [12, 12]),
        reserve: false,
      );
      expect(c.kind, ProgressKind.hold);
      expect(c.after.workingWeight, 30);
    });

    test('в диапазоне — вес тот же, недоборы сбрасываются', () {
      final c = step(
        squat,
        const ExerciseProgress(workingWeight: 30, misses: 2),
        sets(30, [11, 10]),
      );
      expect(c.kind, ProgressKind.hold);
      expect(c.after.misses, 0);
    });

    test('третий недобор подряд — откат на 10%', () {
      final c = step(
        squat,
        const ExerciseProgress(workingWeight: 50, misses: 2),
        sets(50, [9, 8]),
      );
      expect(c.kind, ProgressKind.deload);
      expect(c.after.workingWeight, 45);
      expect(c.after.misses, 0);
    });

    test('без веса цель растёт повторами', () {
      final c = step(pushUps, const ExerciseProgress(), sets(0, [12, 12]));
      expect(c.kind, ProgressKind.increase);
      expect(DoubleProgression.repsRange(pushUps, c.after), (min: 12, max: 14));
    });

    test('гантели растут по килограмму', () {
      final exercise = ExerciseCatalog.byId('db_row');
      expect(DoubleProgression.weightStep(exercise, 12), 1);
    });
  });

  test('расчётный максимум по Эпли', () {
    expect(
      estimatedOneRepMax(const SetRecord(weight: 60, reps: 10)),
      closeTo(80, 1e-9),
    );
    expect(estimatedOneRepMax(const SetRecord(weight: 60, reps: 15)), isNull);
    expect(estimatedOneRepMax(const SetRecord(weight: 0, reps: 10)), isNull);
  });

  group('тренировка по плану', () {
    final day = SessionBuilder.days(
      level: TrainingLevel.novice,
      sessionsPerWeek: 3,
      equipment: Equipment.gym,
      stepOf: (_) => 1,
      start: true,
    ).first;
    WorkoutSession planned(int setsEach) => WorkoutSession(
      startedAt: DateTime(2026, 11, 12, 19),
      planDayId: day.id,
      entries: [
        for (final plan in day.exercises)
          ExerciseEntry(
            exercise: plan.exercise,
            plan: plan,
            sets: sets(20, List.filled(setsEach, 12)),
          ),
      ],
    );

    test(
      'план выполнен, только если все упражнения в запланированных подходах',
      () {
        expect(planned(2).planCompleted, isTrue);
        expect(planned(1).planCompleted, isFalse);
      },
    );

    test('свободная тренировка — не план', () {
      expect(
        WorkoutSession(
          startedAt: DateTime(2026),
          entries: planned(2).entries,
        ).planCompleted,
        isFalse,
      );
    });

    test('план и ответ «был запас» сохраняются без потерь', () {
      final session = planned(2);
      final withAnswer = session.copyWith(
        entries: [
          session.entries.first.withReserve(false),
          ...session.entries.skip(1),
        ],
      );
      final restored = WorkoutSession.fromJson(withAnswer.toJson());
      expect(restored.planDayId, 'A');
      expect(restored.entries.first.plan?.repsMax, 12);
      expect(restored.entries.first.hadReserve, isFalse);
      expect(restored.planCompleted, isTrue);
    });
  });

  test('фаза «Старт» — 12 тренировок по плану', () {
    expect(ProgramPhase.after(11), ProgramPhase.start);
    expect(ProgramPhase.after(12), ProgramPhase.base);
  });
}
