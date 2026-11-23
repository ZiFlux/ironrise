import 'body_part.dart';
import 'exercise_catalog.dart';
import 'workout.dart';

/// Система тренировок для новичков (docs/TRAINING_SYSTEM.md).
/// Чистая логика: программа фазы «Старт», двойная прогрессия, расчётный максимум.

enum Equipment {
  gym('Зал'),
  dumbbells('Дома с гантелями');

  const Equipment(this.label);
  final String label;
}

/// Роль упражнения в отработке того, что не получается (skill_practice.dart).
enum SkillRole {
  /// Замена на сегодня: те же мышцы, проще.
  alternative('замена'),

  /// Подводящее: учит движению, которое не получается.
  drill('подводящее'),

  /// Проверка через две недели: получается ли теперь.
  check('проверка');

  const SkillRole(this.label);
  final String label;
}

/// Упражнение в плане: подходы, диапазон повторов и сколько повторов оставить в запасе.
class PlannedExercise {
  const PlannedExercise(
    this.exerciseId, {
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.repsInReserve,
    this.weightFactor = 1,
    this.skillFor,
    this.skillRole,
  });

  final String exerciseId;

  /// Отработка: какому упражнению учимся и в какой роли это упражнение.
  final String? skillFor;
  final SkillRole? skillRole;
  final int sets;
  final int repsMin;
  final int repsMax;
  final int repsInReserve;

  /// Вес от рабочего: силовая ×1,15, разгрузочная ×0,7 (workout_variant.dart).
  /// Такие тренировки рабочий вес не меняют.
  final double weightFactor;

  PlannedExercise copyWith({
    String? exerciseId,
    int? sets,
    int? repsMin,
    int? repsMax,
    int? repsInReserve,
    double? weightFactor,
    String? skillFor,
    SkillRole? skillRole,
  }) => PlannedExercise(
    exerciseId ?? this.exerciseId,
    sets: sets ?? this.sets,
    repsMin: repsMin ?? this.repsMin,
    repsMax: repsMax ?? this.repsMax,
    repsInReserve: repsInReserve ?? this.repsInReserve,
    weightFactor: weightFactor ?? this.weightFactor,
    skillFor: skillFor ?? this.skillFor,
    skillRole: skillRole ?? this.skillRole,
  );

  /// Предлагаемый вес: рабочий × множитель вида тренировки, до 0,5 кг.
  double suggestedWeight(ExerciseProgress progress) {
    final base = progress.workingWeight ?? exercise.defaultWeight;
    if (progress.workingWeight == null || weightFactor == 1) return base;
    return (base * weightFactor * 2).round() / 2;
  }

  Exercise get exercise => ExerciseCatalog.byId(exerciseId);

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'repsMin': repsMin,
    'repsMax': repsMax,
    'repsInReserve': repsInReserve,
    if (weightFactor != 1) 'weightFactor': weightFactor,
    if (skillFor != null) 'skillFor': skillFor,
    if (skillRole != null) 'skillRole': skillRole!.name,
  };

  factory PlannedExercise.fromJson(Map<String, dynamic> j) => PlannedExercise(
    j['exerciseId'],
    sets: j['sets'],
    repsMin: j['repsMin'],
    repsMax: j['repsMax'],
    repsInReserve: j['repsInReserve'],
    weightFactor: (j['weightFactor'] as num?)?.toDouble() ?? 1,
    skillFor: j['skillFor'] as String?,
    skillRole: switch (j['skillRole']) {
      final String name => SkillRole.values.asNameMap()[name],
      _ => null,
    },
  );
}

class ProgramDay {
  const ProgramDay(this.id, this.title, this.exercises);

  final String id;
  final String title;
  final List<PlannedExercise> exercises;

  /// Подход с отдыхом ≈ 2,5 минуты, плюс разминка.
  Duration get estimatedDuration => Duration(
    minutes: 8 + (exercises.fold(0, (n, e) => n + e.sets) * 2.5).round(),
  );
}

/// Дома с гантелями недоступно то, что требует зала.
bool isAvailable(String exerciseId, Equipment equipment) =>
    equipment == Equipment.gym ||
    ExerciseCatalog.byId(exerciseId).gear != ExerciseGear.gym;

enum ProgramPhase {
  start('Старт'),
  base('База');

  const ProgramPhase(this.label);
  final String label;

  /// Столько тренировок по плану длится «Старт» (≈ 4 недели по 3 тренировки).
  static const startWorkouts = 12;

  static ProgramPhase after(int completedPlanWorkouts) =>
      completedPlanWorkouts < startWorkouts
      ? ProgramPhase.start
      : ProgramPhase.base;
}

/// Прогресс в упражнении: рабочий вес (или цель повторов без веса) и недоборы подряд.
class ExerciseProgress {
  const ExerciseProgress({
    this.workingWeight,
    this.repsBonus = 0,
    this.misses = 0,
    this.increases = 0,
  });

  /// null — вес ещё не подобран (калибровка).
  final double? workingWeight;

  /// Для упражнений без веса цель растёт повторами.
  final int repsBonus;
  final int misses;

  /// Сколько раз рабочий вес прибавлялся — для перехода на ступень выше.
  final int increases;

  bool get isCalibrating => workingWeight == null;

  Map<String, dynamic> toJson() => {
    'workingWeight': workingWeight,
    'repsBonus': repsBonus,
    'misses': misses,
    'increases': increases,
  };

  factory ExerciseProgress.fromJson(Map<String, dynamic> j) => ExerciseProgress(
    workingWeight: (j['workingWeight'] as num?)?.toDouble(),
    repsBonus: j['repsBonus'] ?? 0,
    misses: j['misses'] ?? 0,
    increases: j['increases'] ?? 0,
  );
}

enum ProgressKind { calibrated, increase, hold, deload }

class ProgressChange {
  const ProgressChange({
    required this.plan,
    required this.before,
    required this.after,
    required this.kind,
  });

  final PlannedExercise plan;
  final ExerciseProgress before;
  final ExerciseProgress after;
  final ProgressKind kind;
}

/// Двойная прогрессия (docs/TRAINING_SYSTEM.md, раздел 5).
class DoubleProgression {
  const DoubleProgression._();

  /// После стольких недоборов подряд — откат веса.
  static const missesBeforeDeload = 3;
  static const deloadFactor = 0.9;
  static const bodyweightRepsStep = 2;

  static ProgressChange next({
    required PlannedExercise plan,
    required ExerciseProgress current,
    required List<SetRecord> sets,
    required bool hadReserve,
  }) {
    ProgressChange change(ExerciseProgress after, ProgressKind kind) =>
        ProgressChange(plan: plan, before: current, after: after, kind: kind);

    if (sets.isEmpty) return change(current, ProgressKind.hold);
    final exercise = plan.exercise;
    // Силовая и разгрузочная рабочий вес не двигают; первый подбор веса —
    // пересчитываем к обычному.
    if (plan.weightFactor != 1) {
      if (exercise.usesWeight && current.isCalibrating) {
        return change(
          ExerciseProgress(
            workingWeight: _round(_lastWeight(sets) / plan.weightFactor),
          ),
          ProgressKind.calibrated,
        );
      }
      return change(current, ProgressKind.hold);
    }
    final target = repsRange(plan, current);
    final planned = sets.take(plan.sets).toList();
    final allTop =
        planned.length >= plan.sets &&
        planned.every((s) => s.reps >= target.max);
    final belowMin = planned.any((s) => s.reps < target.min);

    if (!exercise.usesWeight) {
      if (allTop && hadReserve) {
        return change(
          ExerciseProgress(
            repsBonus: current.repsBonus + bodyweightRepsStep,
            increases: current.increases + 1,
          ),
          ProgressKind.increase,
        );
      }
      return change(
        ExerciseProgress(
          repsBonus: current.repsBonus,
          increases: current.increases,
        ),
        ProgressKind.hold,
      );
    }

    // Первая тренировка: вес, который человек выбрал сам, и есть рабочий.
    if (current.isCalibrating) {
      return change(
        ExerciseProgress(workingWeight: _lastWeight(sets)),
        ProgressKind.calibrated,
      );
    }
    final weight = current.workingWeight!;
    if (allTop && hadReserve) {
      return change(
        ExerciseProgress(
          workingWeight: _round(weight + weightStep(exercise, weight)),
          increases: current.increases + 1,
        ),
        ProgressKind.increase,
      );
    }
    if (!belowMin)
      return change(
        ExerciseProgress(workingWeight: weight, increases: current.increases),
        ProgressKind.hold,
      );
    final misses = current.misses + 1;
    if (misses >= missesBeforeDeload) {
      return change(
        ExerciseProgress(
          workingWeight: _round(weight * deloadFactor),
          increases: current.increases,
        ),
        ProgressKind.deload,
      );
    }
    return change(
      ExerciseProgress(
        workingWeight: weight,
        misses: misses,
        increases: current.increases,
      ),
      ProgressKind.hold,
    );
  }

  /// Ноги и тяги растут быстрее жимов; гантели — по килограмму.
  static double weightStep(Exercise exercise, double weight) {
    if (exercise.id.startsWith('db_')) return 1;
    final big =
        exercise.mainPart == BodyPart.legs ||
        exercise.mainPart == BodyPart.back;
    if (!big) return 2.5;
    return weight < 40 ? 2.5 : 5;
  }

  static ({int min, int max}) repsRange(
    PlannedExercise plan,
    ExerciseProgress progress,
  ) => (
    min: plan.repsMin + progress.repsBonus,
    max: plan.repsMax + progress.repsBonus,
  );

  static double _lastWeight(List<SetRecord> sets) => sets.last.weight;

  /// До 0,5 кг: такие шаги есть у блинов и гантелей.
  static double _round(double kg) => (kg * 2).round() / 2;
}

/// Расчётный разовый максимум по формуле Эпли (раздел 3.1).
/// Подходы больше 12 повторов в оценку не идут: формула там неточна.
double? estimatedOneRepMax(SetRecord set) {
  if (set.weight <= 0 || set.reps < 1 || set.reps > 12) return null;
  return set.weight * (1 + set.reps / 30);
}

/// Раскладка на неделю: какой день что тренировать — «Пн — Спина и бицепс».
/// [days] — дни программы по кругу, [nextIndex] — какой из них следующий,
/// [trainingDays] — дни недели по графику (0 — понедельник), [today] — от какого дня.
List<({int weekday, String title})> weekLayout({
  required List<ProgramDay> days,
  required int nextIndex,
  required List<int> trainingDays,
  required DateTime today,
}) {
  if (days.isEmpty || trainingDays.isEmpty) return const [];
  final sorted = [...trainingDays]..sort();
  final todayIndex = today.weekday - 1;
  // Ближайшие дни по графику, начиная с сегодняшнего, — на неделю вперёд.
  final upcoming = [
    ...sorted.where((d) => d >= todayIndex),
    ...sorted.where((d) => d < todayIndex),
  ];
  return [
    for (final (i, d) in upcoming.indexed)
      (weekday: d, title: days[(nextIndex + i) % days.length].title),
  ];
}
