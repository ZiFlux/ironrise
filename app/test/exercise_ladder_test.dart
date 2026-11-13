import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/exercise_ladder.dart';
import 'package:ironrise/game/program.dart';

void main() {
  final startA = StartProgram.days(Equipment.gym).first;

  test('новичку в зале — самые простые варианты движений', () {
    final day = ExerciseLadder.adapt(startA, (_) => 1, Equipment.gym);
    final ids = [for (final e in day.exercises) e.exerciseId];
    expect(ids, isNot(contains('barbell_squat')));
    expect(ids, isNot(contains('bench_press')));
    for (final e in day.exercises) {
      expect(e.exercise.difficulty, 1, reason: e.exerciseId);
    }
    expect(ids.toSet().length, ids.length, reason: 'без повторов в дне');
  });

  test('дома без зала — только доступное', () {
    final day = ExerciseLadder.adapt(
      StartProgram.days(Equipment.dumbbells).first,
      (_) => 1,
      Equipment.dumbbells,
    );
    for (final e in day.exercises) {
      expect(isAvailable(e.exerciseId, Equipment.dumbbells), isTrue);
    }
  });

  test('опытному — шаблон как есть, но не выше потолка', () {
    final day = ExerciseLadder.adapt(startA, (_) => 3, Equipment.gym);
    expect(day.exercises.first.exerciseId, 'barbell_squat');
  });

  test('прежний пользователь со штангой не откатывается к простому', () {
    final level = ExerciseLadder.levelOf(
      'squat',
      levels: const {},
      progress: const {'barbell_squat': ExerciseProgress(workingWeight: 60)},
      start: 1,
    );
    expect(level, 3);
  });

  test('освоил: вес относительно веса тела, без веса тела — по прибавкам', () {
    final press = ExerciseCatalog.byId('leg_press');
    expect(
      ExerciseLadder.mastered(
        press,
        const ExerciseProgress(workingWeight: 100),
        bodyweightKg: 80,
      ),
      isTrue,
    );
    expect(
      ExerciseLadder.mastered(
        press,
        const ExerciseProgress(workingWeight: 70),
        bodyweightKg: 80,
      ),
      isFalse,
    );
    expect(
      ExerciseLadder.mastered(
        press,
        const ExerciseProgress(workingWeight: 70, increases: 4),
      ),
      isTrue,
    );
    final knee = ExerciseCatalog.byId('knee_push_up');
    expect(
      ExerciseLadder.mastered(knee, const ExerciseProgress(repsBonus: 6)),
      isTrue,
    );
    expect(ExerciseLadder.harderThan(knee, Equipment.gym)!.id, 'push_up');
  });

  test('рост в прогрессии считает прибавки', () {
    final plan = PlannedExercise(
      'leg_press',
      sets: 2,
      repsMin: 10,
      repsMax: 12,
      repsInReserve: 3,
    );
    final change = DoubleProgression.next(
      plan: plan,
      current: const ExerciseProgress(workingWeight: 60, increases: 1),
      sets: const [],
      hadReserve: true,
    );
    expect(change.after.increases, 1);
  });
}
