import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';
import 'package:ironrise/game/workout.dart';
import 'package:ironrise/game/workout_variant.dart';

void main() {
  List<WorkoutVariant> rhythm(TrainingLevel level, {bool trial = false}) => [
    for (var i = 0; i < 20; i++)
      Periodization.planned(
        level: level,
        trial: trial,
        completedWorkouts: i,
        sessionsPerWeek: 4,
      ),
  ];

  test('новичку — только обычные, среднему — по желанию', () {
    expect(rhythm(TrainingLevel.novice).toSet(), {WorkoutVariant.regular});
    expect(rhythm(TrainingLevel.intermediate).toSet(), {
      WorkoutVariant.regular,
    });
    expect(
      rhythm(TrainingLevel.intermediate, trial: true),
      contains(WorkoutVariant.deload),
    );
  });

  test('опытный: каждая 3-я силовая, после 3 недель — неделя разгрузки', () {
    final r = rhythm(TrainingLevel.advanced);
    expect(r[2], WorkoutVariant.strength);
    expect(r[5], WorkoutVariant.strength);
    expect(r.sublist(12, 16).toSet(), {WorkoutVariant.deload});
    expect(r[16], WorkoutVariant.regular); // новый блок
    expect(
      Periodization.untilDeload(
        level: TrainingLevel.advanced,
        completedWorkouts: 10,
        sessionsPerWeek: 4,
      ),
      2,
    );
  });

  final day = SessionBuilder.days(
    level: TrainingLevel.advanced,
    sessionsPerWeek: 4,
    equipment: Equipment.gym,
    stepOf: (_) => 3,
  ).first;

  test(
    'силовая: меньше упражнений и подходов, базовые 3–6 с весом тяжелее',
    () {
      final s = Periodization.apply(
        day,
        WorkoutVariant.strength,
        TrainingLevel.advanced,
      );
      expect(s.exercises.length, day.exercises.length - 3);
      int total(ProgramDay d) => d.exercises.fold(0, (a, e) => a + e.sets);
      expect(total(s), lessThan(total(day)));
      final first = s.exercises.first;
      expect((first.repsMin, first.repsMax, first.weightFactor), (3, 6, 1.15));
    },
  );

  test('разгрузочная: те же упражнения, половина подходов, вес ×0,7', () {
    final d = Periodization.apply(
      day,
      WorkoutVariant.deload,
      TrainingLevel.advanced,
    );
    expect(
      d.exercises.map((e) => e.exerciseId),
      day.exercises.map((e) => e.exerciseId),
    );
    expect(
      d.exercises.every((e) => e.sets <= 2 && e.repsInReserve == 4),
      isTrue,
    );
    const progress = ExerciseProgress(workingWeight: 100);
    expect(
      d.exercises
          .firstWhere((e) => e.exercise.usesWeight)
          .suggestedWeight(progress),
      70,
    );
  });

  test('силовая и разгрузочная рабочий вес не меняют', () {
    const plan = PlannedExercise(
      'bench_press',
      sets: 3,
      repsMin: 3,
      repsMax: 6,
      repsInReserve: 1,
      weightFactor: 1.15,
    );
    final change = DoubleProgression.next(
      plan: plan,
      current: const ExerciseProgress(workingWeight: 80),
      sets: const [
        SetRecord(weight: 92, reps: 6),
        SetRecord(weight: 92, reps: 6),
        SetRecord(weight: 92, reps: 6),
      ],
      hadReserve: true,
    );
    expect(change.after.workingWeight, 80);
    // Первый подбор на силовой — пересчёт к обычному весу.
    final first = DoubleProgression.next(
      plan: plan,
      current: const ExerciseProgress(),
      sets: const [SetRecord(weight: 92, reps: 5)],
      hadReserve: true,
    );
    expect(first.after.workingWeight, 80);
  });

  test('план с множителем веса сохраняется', () {
    const plan = PlannedExercise(
      'deadlift',
      sets: 2,
      repsMin: 8,
      repsMax: 12,
      repsInReserve: 4,
      weightFactor: 0.7,
    );
    expect(PlannedExercise.fromJson(plan.toJson()).weightFactor, 0.7);
  });
}
