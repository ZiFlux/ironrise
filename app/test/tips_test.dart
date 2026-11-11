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
    final tip = TipPicker.pick(day: day, isTrainingDay: false, planExerciseIds: const [], lagging: null, recentTipIds: const []);
    expect(tip.moment, TipMoment.rest);
  });

  test('отстающая часть тела — совет про неё', () {
    final tip = TipPicker.pick(day: day, isTrainingDay: false, planExerciseIds: const [], lagging: BodyPart.legs, recentTipIds: const []);
    expect(tip.part == BodyPart.legs || tip.moment == TipMoment.rest, isTrue);
  });

  test('недавние советы не повторяются', () {
    final all = tipLibrary.map((t) => t.id).toList();
    final recent = all.where((id) => id != 'sleep').toList();
    final tip = TipPicker.pick(day: day, isTrainingDay: true, planExerciseIds: const ['bench_press'], lagging: null, recentTipIds: recent);
    expect(tip.id, 'sleep');
  });

  test('совет стабилен в течение дня', () {
    final a = TipPicker.pick(day: day, isTrainingDay: true, planExerciseIds: const ['bench_press'], lagging: null, recentTipIds: const []);
    final b = TipPicker.pick(day: DateTime(2026, 11, 12, 23), isTrainingDay: true, planExerciseIds: const ['bench_press'], lagging: null, recentTipIds: const []);
    expect(a.id, b.id);
  });
}
