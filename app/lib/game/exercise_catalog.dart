import 'body_part.dart';
import 'exercise_data.dart';

enum ExerciseUnit { reps, seconds }

/// Что нужно для упражнения. Зал включает гантели, гантели — упражнения без инвентаря.
enum ExerciseGear {
  none('Без инвентаря'),
  dumbbells('Гантели'),
  gym('Зал');

  const ExerciseGear(this.label);
  final String label;
}

/// Сложность в базе знаний и в подборе: новичку — 1, дальше по результатам.
const difficultyLabels = ['', 'Новичок', 'Средний', 'Опытный'];

/// Упражнение из справочника: доли нагрузки по частям тела (ТЗ 4.1).
/// Данные — shared/exercises.json (tools/gen_exercises.py).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.shares,
    this.pattern = '',
    this.difficulty = 1,
    this.gear = ExerciseGear.none,
    this.usesWeight = true,
    this.unit = ExerciseUnit.reps,
    this.defaultWeight = 20,
    this.defaultReps = 10,
    this.joints = const {},
  });

  final String id;
  final String name;
  final Map<BodyPart, double> shares;

  /// Движение (squat, push_h…): внутри него упражнения усложняются по [difficulty].
  final String pattern;
  final int difficulty;
  final ExerciseGear gear;
  final bool usesWeight;
  final ExerciseUnit unit;
  final double defaultWeight;
  final int defaultReps;

  /// Какие суставы нагружает (PainZone.name): при боли упражнение заменяется.
  final Set<String> joints;

  /// Часть тела с наибольшей долей нагрузки.
  BodyPart get mainPart =>
      shares.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Упражнение разминки: опыта не даёт, подбирается под части тела тренировки.
class WarmupMove {
  const WarmupMove({
    required this.id,
    required this.name,
    required this.gear,
    required this.amount,
    required this.targets,
    this.seconds = false,
  });

  final String id;
  final String name;
  final ExerciseGear gear;

  /// Повторы или секунды.
  final int amount;
  final bool seconds;
  final Set<BodyPart> targets;

  bool get isCardio => targets.contains(BodyPart.cardio);
}

/// Справочник силовых упражнений. Кардио приходит с часов, поэтому здесь его нет.
class ExerciseCatalog {
  const ExerciseCatalog._();

  static const all = generatedExercises;
  static const warmups = generatedWarmups;

  static final _byId = {for (final e in all) e.id: e};

  static Exercise byId(String id) => _byId[id]!;

  static Exercise? tryById(String id) => _byId[id];

  static List<Exercise> forPart(BodyPart part) =>
      all.where((e) => (e.shares[part] ?? 0) > 0).toList()..sort((a, b) {
        // Сначала самые нагружающие часть, при равенстве — попроще.
        final byShare = (b.shares[part] ?? 0).compareTo(a.shares[part] ?? 0);
        return byShare != 0 ? byShare : a.difficulty.compareTo(b.difficulty);
      });
}
