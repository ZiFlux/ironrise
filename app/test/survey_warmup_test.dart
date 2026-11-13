import 'package:flutter_test/flutter_test.dart';

import 'support/days.dart';

import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/game_config.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/warmup.dart';
import 'package:ironrise/game/wellbeing.dart';

void main() {
  final gymA = gymDayA;

  test('«легко» дважды — на подход больше, но не больше лимита', () {
    final d = Wellbeing.adapt(gymA, ease: false, avoid: const {}, boost: true);
    expect(d.boosted, isTrue);
    for (final (i, e) in d.day.exercises.indexed) {
      expect(e.sets, gymA.exercises[i].sets + 1);
      expect(e.sets, lessThanOrEqualTo(GameConfig.maxSetsPerExercise));
    }
  });

  test('«не зашло» — замена похожим из той же части тела', () {
    final d = Wellbeing.adapt(
      gymA,
      ease: false,
      avoid: const {},
      disliked: const {'bench_press'},
    );
    final adj = d.adjustments.single;
    expect(adj.reason, AdjustReason.dislike);
    final replacement = ExerciseCatalog.byId(adj.replacementId!);
    expect(replacement.mainPart, BodyPart.chest);
    expect(replacement.pattern, 'push_h');
  });

  test('нагрузка на суставы — из базы: новые упражнения тоже учтены', () {
    expect(Wellbeing.loadedBy(PainZone.knee), contains('goblet_squat'));
    expect(Wellbeing.loadedBy(PainZone.shoulder), contains('overhead_press'));
  });

  test('разминка: кардио первым и все части тела дня покрыты', () {
    final exercises = [for (final e in gymA.exercises) e.exercise];
    final moves = Warmup.forExercises(exercises, Equipment.gym);
    expect(moves.first.isCardio, isTrue);
    expect(moves.first.gear, ExerciseGear.gym);
    final covered = {for (final m in moves) ...m.targets};
    expect(covered.containsAll(Warmup.partsOf(exercises)), isTrue);
    expect(moves.length, lessThanOrEqualTo(Warmup.maxMoves + 1));
  });

  test('разминка дома — без тренажёров', () {
    final moves = Warmup.forExercises(const [], Equipment.dumbbells);
    expect(moves.every((m) => m.gear != ExerciseGear.gym), isTrue);
    expect(moves.first.isCardio, isTrue);
  });
}
