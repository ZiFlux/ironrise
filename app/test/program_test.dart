import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/workout.dart';

const squat = PlannedExercise('barbell_squat', sets: 2, repsMin: 10, repsMax: 12, repsInReserve: 3);
const bench = PlannedExercise('bench_press', sets: 2, repsMin: 10, repsMax: 12, repsInReserve: 3);
const pushUps = PlannedExercise('push_up', sets: 2, repsMin: 10, repsMax: 12, repsInReserve: 3);

List<SetRecord> sets(double weight, List<int> reps) =>
    [for (final r in reps) SetRecord(weight: weight, reps: r)];

ProgressChange step(PlannedExercise plan, ExerciseProgress current, List<SetRecord> done, {bool reserve = true}) =>
    DoubleProgression.next(plan: plan, current: current, sets: done, hadReserve: reserve);

void main() {
  group('двойная прогрессия', () {
    test('первая тренировка задаёт рабочий вес', () {
      final c = step(squat, const ExerciseProgress(), sets(30, [12, 12]));
      expect(c.kind, ProgressKind.calibrated);
      expect(c.after.workingWeight, 30);
    });

    test('верх диапазона с запасом — вес растёт: ноги до 40 кг на 2,5', () {
      final c = step(squat, const ExerciseProgress(workingWeight: 30), sets(30, [12, 12]));
      expect(c.kind, ProgressKind.increase);
      expect(c.after.workingWeight, 32.5);
    });

    test('ноги от 40 кг — на 5, жимы — на 2,5', () {
      expect(step(squat, const ExerciseProgress(workingWeight: 40), sets(40, [12, 12])).after.workingWeight, 45);
      expect(step(bench, const ExerciseProgress(workingWeight: 40), sets(40, [12, 12])).after.workingWeight, 42.5);
    });

    test('впритык — вес не растёт', () {
      final c = step(squat, const ExerciseProgress(workingWeight: 30), sets(30, [12, 12]), reserve: false);
      expect(c.kind, ProgressKind.hold);
      expect(c.after.workingWeight, 30);
    });

    test('в диапазоне — вес тот же, недоборы сбрасываются', () {
      final c = step(squat, const ExerciseProgress(workingWeight: 30, misses: 2), sets(30, [11, 10]));
      expect(c.kind, ProgressKind.hold);
      expect(c.after.misses, 0);
    });

    test('третий недобор подряд — откат на 10%', () {
      final c = step(squat, const ExerciseProgress(workingWeight: 50, misses: 2), sets(50, [9, 8]));
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

  group('программа «Старт»', () {
    test('два дня по 4 упражнения в зале и дома', () {
      for (final equipment in Equipment.values) {
        final days = StartProgram.days(equipment);
        expect(days.map((d) => d.id), ['A', 'B']);
        expect(days.every((d) => d.exercises.length == 4), isTrue);
        // Все упражнения есть в справочнике.
        for (final e in days.expand((d) => d.exercises)) {
          expect(() => e.exercise, returnsNormally);
        }
      }
    });

    test('тренировка около 30–40 минут', () {
      final minutes = StartProgram.days(Equipment.gym).first.estimatedDuration.inMinutes;
      expect(minutes, inInclusiveRange(30, 40));
    });
  });

  test('расчётный максимум по Эпли', () {
    expect(estimatedOneRepMax(const SetRecord(weight: 60, reps: 10)), closeTo(80, 1e-9));
    expect(estimatedOneRepMax(const SetRecord(weight: 60, reps: 15)), isNull);
    expect(estimatedOneRepMax(const SetRecord(weight: 0, reps: 10)), isNull);
  });

  group('тренировка по плану', () {
    final day = StartProgram.days(Equipment.gym).first;
    WorkoutSession planned(int setsEach) => WorkoutSession(
      startedAt: DateTime(2026, 11, 12, 19),
      planDayId: day.id,
      entries: [
        for (final plan in day.exercises)
          ExerciseEntry(exercise: plan.exercise, plan: plan, sets: sets(20, List.filled(setsEach, 12))),
      ],
    );

    test('план выполнен, только если все упражнения в запланированных подходах', () {
      expect(planned(2).planCompleted, isTrue);
      expect(planned(1).planCompleted, isFalse);
    });

    test('свободная тренировка — не план', () {
      expect(WorkoutSession(startedAt: DateTime(2026), entries: planned(2).entries).planCompleted, isFalse);
    });

    test('план и ответ «был запас» сохраняются без потерь', () {
      final session = planned(2);
      final withAnswer = session.copyWith(entries: [session.entries.first.withReserve(false), ...session.entries.skip(1)]);
      final restored = WorkoutSession.fromJson(withAnswer.toJson());
      expect(restored.planDayId, 'A');
      expect(restored.entries.first.plan?.repsMax, 12);
      expect(restored.entries.first.hadReserve, isFalse);
      expect(restored.planCompleted, isTrue);
    });
  });

  group('фаза «База»', () {
    test('переход после 12 тренировок по плану', () {
      expect(ProgramPhase.after(11), ProgramPhase.start);
      expect(ProgramPhase.after(12), ProgramPhase.base);
    });

    test('дни по формату: 3 — фулбоди, 4 — верх/низ, 5 — плюс день отстающей части', () {
      expect(BaseProgram.days(Equipment.gym, 3).map((d) => d.id), ['A', 'B']);
      expect(BaseProgram.days(Equipment.gym, 4).map((d) => d.id), ['U1', 'L1', 'U2', 'L2']);
      expect(BaseProgram.days(Equipment.gym, 5).map((d) => d.id), ['U1', 'L1', 'U2', 'L2', 'F']);
    });

    test('3 подхода × 8–12, 2 в запасе', () {
      final squat = BaseProgram.days(Equipment.gym, 3).first.exercises.first;
      expect((squat.sets, squat.repsMin, squat.repsMax, squat.repsInReserve), (3, 8, 12, 2));
    });

    test('точечное упражнение на отстающую часть в конце, без повторов', () {
      final day = BaseProgram.days(Equipment.gym, 3).first;
      final withLegs = BaseProgram.withAccessories(day, BodyPart.legs, Equipment.gym);
      expect(withLegs.exercises.length, day.exercises.length + 1);
      final extra = withLegs.exercises.last;
      expect(extra.exercise.shares.containsKey(BodyPart.legs), isTrue);
      expect(withLegs.exercises.where((e) => e.exerciseId == extra.exerciseId).length, 1);
    });

    test('день отстающей части — три упражнения на неё, без отставания — всё тело', () {
      final focus = BaseProgram.days(Equipment.gym, 5).last;
      expect(BaseProgram.withAccessories(focus, BodyPart.back, Equipment.gym).exercises.length, 3);
      expect(BaseProgram.withAccessories(focus, null, Equipment.gym).exercises, isNotEmpty);
    });

    test('кардио не добавляется точечным упражнением', () {
      final day = BaseProgram.days(Equipment.gym, 3).first;
      expect(BaseProgram.withAccessories(day, BodyPart.cardio, Equipment.gym).exercises.length, day.exercises.length);
    });

    test('дома с гантелями — только доступные упражнения и без повторов', () {
      for (final sessions in [3, 4, 5]) {
        for (final day in BaseProgram.days(Equipment.dumbbells, sessions)) {
          final ids = [for (final e in day.exercises) e.exerciseId];
          expect(ids.every((id) => isAvailable(id, Equipment.dumbbells)), isTrue, reason: '${day.id}: $ids');
          expect(ids.toSet().length, ids.length, reason: '${day.id}: $ids');
        }
      }
    });
  });
}
