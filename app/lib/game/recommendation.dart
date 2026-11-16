import 'body_part.dart';
import 'exercise_catalog.dart';

/// Рекомендация «что подкачать» (PLAN.md, 4.2): упражнение из справочника
/// с наибольшей долей нагрузки на отстающую часть.
class Recommendation {
  const Recommendation({required this.part, this.exercise});

  final BodyPart part;

  /// null, если в справочнике нет подходящего упражнения (например, кардио).
  final Exercise? exercise;

  /// Текст для карточки: «Приседания 3 × 15».
  String get text {
    final e = exercise;
    if (e == null) return part.beginnerExercise;
    final unit = e.unit == ExerciseUnit.seconds ? ' с' : '';
    return '${e.name} 3 × ${e.defaultReps}$unit';
  }

  static Recommendation? forLagging(List<BodyPart> lagging) {
    if (lagging.isEmpty) return null;
    final part = lagging.first;
    // Финишеры «на дыхалку» (п. 117) — не замена кардио-тренировке: для кардио — совет.
    final options = ExerciseCatalog.forPart(part)
        .where((e) => e.pattern != 'conditioning')
        .toList();
    return Recommendation(
      part: part,
      exercise: options.isEmpty ? null : options.first,
    );
  }
}
