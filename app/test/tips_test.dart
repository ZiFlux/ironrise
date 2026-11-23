import 'package:ironrise/state/tips_state.dart';
import 'package:ironrise/game/game_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/tips.dart';

void main() {
  final day = DateTime(2026, 11, 12);

  test('у каждого совета корректный вопрос и существующие упражнения', () {
    final ids = <String>{};
    for (final tip in tipLibrary) {
      expect(ids.add(tip.id), isTrue, reason: 'повтор id ${tip.id}');
      expect(tip.question.options.length, 3);
      expect(tip.question.correct, inInclusiveRange(0, 2));
      for (final id in tip.exerciseIds) {
        expect(() => ExerciseCatalog.byId(id), returnsNormally, reason: id);
      }
    }
  });

  test('в день отдыха — совет про отдых', () {
    final tip = TipPicker.pick(
      day: day,
      isTrainingDay: false,
      planExerciseIds: const [],
      lagging: null,
      recentTipIds: const [],
    );
    expect(tip.moment, TipMoment.rest);
  });

  test('отстающая часть тела — совет про неё', () {
    final tip = TipPicker.pick(
      day: day,
      isTrainingDay: false,
      planExerciseIds: const [],
      lagging: BodyPart.legs,
      recentTipIds: const [],
    );
    expect(tip.part == BodyPart.legs || tip.moment == TipMoment.rest, isTrue);
  });

  test('недавние советы не повторяются', () {
    final all = tipLibrary.map((t) => t.id).toList();
    final recent = all.where((id) => id != 'sleep').toList();
    final tip = TipPicker.pick(
      day: day,
      isTrainingDay: true,
      planExerciseIds: const ['bench_press'],
      lagging: null,
      recentTipIds: recent,
    );
    expect(tip.id, 'sleep');
  });

  test('совет стабилен в течение дня', () {
    final a = TipPicker.pick(
      day: day,
      isTrainingDay: true,
      planExerciseIds: const ['bench_press'],
      lagging: null,
      recentTipIds: const [],
    );
    final b = TipPicker.pick(
      day: DateTime(2026, 11, 12, 23),
      isTrainingDay: true,
      planExerciseIds: const ['bench_press'],
      lagging: null,
      recentTipIds: const [],
    );
    expect(a.id, b.id);
  });

  test('подборка дня: разные советы нужного размера, по делу — первыми', () {
    final set = TipPicker.pickSet(
      day: DateTime(2026, 11, 13),
      isTrainingDay: true,
      planExerciseIds: const ['goblet_squat'],
      lagging: null,
      recentTipIds: const [],
      count: 5,
    );
    expect(set.length, 5);
    expect(set.map((t) => t.id).toSet().length, 5);
    expect(
      set.first.exerciseIds.contains('goblet_squat') ||
          set.first.moment == TipMoment.training,
      isTrue,
    );
  });

  test('id советов уникальны, у вопросов верный вариант в списке', () {
    final ids = tipLibrary.map((t) => t.id).toList();
    expect(ids.toSet().length, ids.length);
    for (final t in tipLibrary) {
      expect(
        t.question.correct,
        lessThan(t.question.options.length),
        reason: t.id,
      );
    }
  });

  test('монеты за опрос: за ответы и бонус за все верные', () {
    expect(
      tipQuizCoins(5, 5),
      5 * GameConfig.tipCoinsPerAnswer + GameConfig.tipQuizBonus,
    );
    expect(tipQuizCoins(3, 5), 3 * GameConfig.tipCoinsPerAnswer);
    expect(tipQuizCoins(0, 3), 0);
  });

  test('две недели по 5 советов — без повторов, каждый день есть факты', () {
    var recent = <String>[];
    final seen = <String>{};
    for (var d = 0; d < 14; d++) {
      final set = TipPicker.pickSet(
        day: DateTime(2026, 11, 23).add(Duration(days: d)),
        isTrainingDay: d.isEven,
        planExerciseIds: const ['barbell_squat', 'bench_press'],
        lagging: null,
        recentTipIds: recent,
        count: 5,
      );
      expect(set.length, 5);
      expect(
        set.where((t) => t.kind == TipKind.fact).length,
        greaterThanOrEqualTo(TipPicker.factsPerDay),
      );
      for (final t in set) {
        expect(seen.add(t.id), isTrue, reason: 'повтор ${t.id} на день $d');
      }
      recent = [for (final t in set) t.id, ...recent].take(75).toList();
    }
  });

  test('у фактов есть источник и цифра', () {
    for (final t in tipLibrary.where((t) => t.kind == TipKind.fact)) {
      expect(t.source, isNotNull, reason: t.id);
      expect(t.figure, isNotNull, reason: t.id);
    }
    expect(tipLibrary.length, greaterThanOrEqualTo(100));
  });
}
