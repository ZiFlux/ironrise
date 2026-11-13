import 'program.dart';
import 'session_builder.dart';

/// Вид тренировки (периодизация): обычная, силовая и разгрузочная.
enum WorkoutVariant {
  regular('Обычная', 'Обычный объём: рост мышц и силы'),
  strength(
    'Силовая',
    'Меньше упражнений и подходов, 3–6 повторов, вес тяжелее',
  ),
  deload(
    'Разгрузочная',
    'Те же упражнения, половина подходов и лёгкий вес — отдых для нервной системы',
  );

  const WorkoutVariant(this.label, this.description);

  final String label;
  final String description;
}

/// Ритм тренировок. Опытным — всегда, средним — по желанию («на пробу»),
/// новичкам — только обычные: им пока важнее освоить технику и объём.
///
/// Считается по сделанным тренировкам, а не по календарю: пропущенная неделя
/// не сдвигает разгрузку раньше времени.
class Periodization {
  const Periodization._();

  static bool available(TrainingLevel level, {required bool trial}) =>
      level == TrainingLevel.advanced ||
      (level == TrainingLevel.intermediate && trial);

  /// Рабочих недель до разгрузочной: опытным 3, средним 4.
  static int workWeeks(TrainingLevel level) =>
      level == TrainingLevel.advanced ? 3 : 4;

  /// Силовая — каждая N-я тренировка рабочих недель: опытным каждая 3-я, средним 4-я.
  static int strengthEvery(TrainingLevel level) =>
      level == TrainingLevel.advanced ? 3 : 4;

  /// Какая тренировка по ритму идёт следующей.
  static WorkoutVariant planned({
    required TrainingLevel level,
    required bool trial,
    required int completedWorkouts,
    required int sessionsPerWeek,
  }) {
    if (!available(level, trial: trial)) return WorkoutVariant.regular;
    final per = sessionsPerWeek.clamp(2, 6);
    final work = per * workWeeks(level);
    final pos = completedWorkouts % (work + per);
    if (pos >= work) return WorkoutVariant.deload;
    final every = strengthEvery(level);
    return pos % every == every - 1
        ? WorkoutVariant.strength
        : WorkoutVariant.regular;
  }

  /// Тренировок до ближайшей разгрузочной недели (0 — она уже идёт).
  static int untilDeload({
    required TrainingLevel level,
    required int completedWorkouts,
    required int sessionsPerWeek,
  }) {
    final per = sessionsPerWeek.clamp(2, 6);
    final work = per * workWeeks(level);
    final pos = completedWorkouts % (work + per);
    return pos >= work ? 0 : work - pos;
  }

  /// Не базовые, хоть и в «тяге»: в силовой они не нужны.
  static const _isolationHinges = {
    'leg_curl',
    'back_extension',
    'glute_bridge',
  };
  static const _compoundPatterns = {
    'squat',
    'hinge',
    'lunge',
    'push_h',
    'push_v',
    'pull_h',
    'pull_v',
  };

  static bool isCompound(PlannedExercise p) =>
      _compoundPatterns.contains(p.exercise.pattern) &&
      !_isolationHinges.contains(p.exerciseId);

  /// День под вид тренировки.
  static ProgramDay apply(
    ProgramDay day,
    WorkoutVariant variant,
    TrainingLevel level,
  ) => switch (variant) {
    WorkoutVariant.regular => day,
    WorkoutVariant.strength => _strength(day, level),
    WorkoutVariant.deload => ProgramDay(day.id, day.title, [
      for (final e in day.exercises)
        e.copyWith(
          sets: (e.sets / 2).ceil().clamp(1, 2),
          repsInReserve: 4,
          weightFactor: e.exercise.usesWeight ? 0.7 : 1,
        ),
    ]),
  };

  /// Силовая: сначала базовые движения, всего на 3 упражнения меньше (не меньше 4);
  /// базовые — 3 подхода по 3–6 (средним 4–6) с весом ×1,15, остальное — 2 по 8–10.
  static ProgramDay _strength(ProgramDay day, TrainingLevel level) {
    final keep = (day.exercises.length - 3).clamp(4, day.exercises.length);
    final compound = day.exercises.where(isCompound).toList();
    final chosen = {
      ...compound.take(keep),
      ...day.exercises.where((e) => !isCompound(e)),
    }.take(keep).toSet();
    final advanced = level == TrainingLevel.advanced;
    return ProgramDay(day.id, day.title, [
      for (final e in day.exercises)
        if (chosen.contains(e))
          if (!e.exercise.usesWeight)
            // Без веса тяжелее не сделать — тот же диапазон, меньше запаса.
            e.copyWith(sets: e.sets.clamp(1, 3), repsInReserve: 1)
          else if (isCompound(e))
            e.copyWith(
              sets: 3,
              repsMin: advanced ? 3 : 4,
              repsMax: 6,
              repsInReserve: advanced ? 1 : 2,
              weightFactor: 1.15,
            )
          else
            e.copyWith(
              sets: 2,
              repsMin: 8,
              repsMax: 10,
              repsInReserve: 2,
              weightFactor: 1.05,
            ),
    ]);
  }
}
