import 'body_part.dart';

enum ExerciseUnit { reps, seconds }

/// Упражнение из справочника: доли нагрузки по частям тела (ТЗ 4.1).
class Exercise {
  const Exercise({
    required this.id,
    required this.name,
    required this.shares,
    this.usesWeight = true,
    this.unit = ExerciseUnit.reps,
    this.defaultWeight = 20,
    this.defaultReps = 10,
  });

  final String id;
  final String name;
  final Map<BodyPart, double> shares;
  final bool usesWeight;
  final ExerciseUnit unit;
  final double defaultWeight;
  final int defaultReps;

  /// Часть тела с наибольшей долей нагрузки.
  BodyPart get mainPart =>
      shares.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
}

/// Стартовый справочник: базовые упражнения для новичка.
/// Кардио приходит с часов, поэтому здесь его нет.
class ExerciseCatalog {
  const ExerciseCatalog._();

  static const all = <Exercise>[
    Exercise(id: 'push_up', name: 'Отжимания', usesWeight: false,
        shares: {BodyPart.chest: 0.7, BodyPart.arms: 0.2, BodyPart.core: 0.1}),
    Exercise(id: 'bench_press', name: 'Жим штанги лёжа', defaultWeight: 30, defaultReps: 8,
        shares: {BodyPart.chest: 0.7, BodyPart.arms: 0.3}),
    Exercise(id: 'db_bench_press', name: 'Жим гантелей лёжа', defaultWeight: 10,
        shares: {BodyPart.chest: 0.7, BodyPart.arms: 0.3}),
    Exercise(id: 'dips', name: 'Отжимания на брусьях', usesWeight: false, defaultReps: 8,
        shares: {BodyPart.chest: 0.4, BodyPart.arms: 0.6}),
    Exercise(id: 'lat_pulldown', name: 'Тяга верхнего блока', defaultWeight: 30,
        shares: {BodyPart.back: 0.75, BodyPart.arms: 0.25}),
    Exercise(id: 'db_row', name: 'Тяга гантели в наклоне', defaultWeight: 12,
        shares: {BodyPart.back: 0.7, BodyPart.arms: 0.3}),
    Exercise(id: 'pull_up', name: 'Подтягивания', usesWeight: false, defaultReps: 5,
        shares: {BodyPart.back: 0.7, BodyPart.arms: 0.3}),
    Exercise(id: 'back_extension', name: 'Гиперэкстензия', usesWeight: false, defaultReps: 12,
        shares: {BodyPart.back: 0.7, BodyPart.legs: 0.3}),
    Exercise(id: 'bodyweight_squat', name: 'Приседания', usesWeight: false, defaultReps: 15,
        shares: {BodyPart.legs: 0.85, BodyPart.core: 0.15}),
    Exercise(id: 'barbell_squat', name: 'Приседания со штангой', defaultWeight: 30, defaultReps: 8,
        shares: {BodyPart.legs: 0.8, BodyPart.back: 0.1, BodyPart.core: 0.1}),
    Exercise(id: 'lunges', name: 'Выпады', usesWeight: false, defaultReps: 10,
        shares: {BodyPart.legs: 0.9, BodyPart.core: 0.1}),
    Exercise(id: 'leg_press', name: 'Жим ногами', defaultWeight: 60, defaultReps: 12,
        shares: {BodyPart.legs: 1}),
    Exercise(id: 'romanian_deadlift', name: 'Румынская тяга', defaultWeight: 30,
        shares: {BodyPart.legs: 0.6, BodyPart.back: 0.4}),
    Exercise(id: 'db_shoulder_press', name: 'Жим гантелей сидя', defaultWeight: 8,
        shares: {BodyPart.arms: 0.5, BodyPart.back: 0.3, BodyPart.chest: 0.2}),
    Exercise(id: 'db_curl', name: 'Сгибания с гантелями', defaultWeight: 8, defaultReps: 12,
        shares: {BodyPart.arms: 1}),
    Exercise(id: 'french_press', name: 'Французский жим', defaultWeight: 15,
        shares: {BodyPart.arms: 1}),
    Exercise(id: 'plank', name: 'Планка', usesWeight: false, unit: ExerciseUnit.seconds,
        defaultReps: 30, shares: {BodyPart.core: 1}),
    Exercise(id: 'crunches', name: 'Скручивания', usesWeight: false, defaultReps: 15,
        shares: {BodyPart.core: 1}),
    Exercise(id: 'hanging_leg_raise', name: 'Подъём ног в висе', usesWeight: false, defaultReps: 8,
        shares: {BodyPart.core: 0.8, BodyPart.arms: 0.2}),
  ];

  static Exercise byId(String id) => all.firstWhere((e) => e.id == id);

  static List<Exercise> forPart(BodyPart part) =>
      all.where((e) => (e.shares[part] ?? 0) > 0).toList()
        ..sort((a, b) => (b.shares[part] ?? 0).compareTo(a.shares[part] ?? 0));
}
