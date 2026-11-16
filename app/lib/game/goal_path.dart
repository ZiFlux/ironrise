import '../state/hero.dart' show Goal;
import 'session_builder.dart' show TrainingLevel;

/// Свой путь у каждой главной цели (п. 117, TRAINING_SYSTEM.md 15): повторы, запас,
/// отдых, число упражнений и финишер «на дыхалку». Фаза «Старт» одинакова для всех —
/// цель меняет в ней только отдых. Дополнительные цели — акценты: чаще взвешивание
/// при «похудеть».
class GoalPath {
  const GoalPath({
    required this.compoundReps,
    required this.isolationReps,
    required this.rest,
    this.reserveDelta = 0,
    this.exerciseDelta = 0,
    this.finisher = false,
  });

  /// Повторы в базовых и в изолирующих упражнениях.
  final (int, int) compoundReps;
  final (int, int) isolationReps;

  /// Отдых между подходами.
  final Duration rest;

  /// Повторов в запасе: + — больше запаса (регулярность), − — ближе к отказу.
  final int reserveDelta;

  /// Упражнений в тренировке относительно уровня (−1 — короче и проще).
  final int exerciseDelta;

  /// В конце — упражнение «на дыхалку» (бёрпи, скалолаз, прыжки).
  final bool finisher;

  static GoalPath of(Goal goal, TrainingLevel level) => switch (goal) {
    // Масса: классика гипертрофии, 8–12 / 10–15, отдых полторы минуты.
    Goal.mass => const GoalPath(
      compoundReps: (8, 12),
      isolationReps: (10, 15),
      rest: Duration(seconds: 90),
    ),
    // Сила: базовые тяжелее (новичку — не ниже 6 повторов), отдых дольше, изоляции меньше.
    Goal.strength => GoalPath(
      compoundReps: level == TrainingLevel.novice ? (6, 8) : (4, 6),
      isolationReps: (8, 12),
      rest: const Duration(seconds: 150),
      exerciseDelta: -1,
    ),
    // Похудеть: больше повторов, короче отдых, финишер на дыхалку.
    Goal.fatLoss => const GoalPath(
      compoundReps: (10, 15),
      isolationReps: (12, 15),
      rest: Duration(seconds: 60),
      finisher: true,
    ),
    // Выносливость: много повторов, короткий отдых, финишер на дыхалку.
    Goal.endurance => const GoalPath(
      compoundReps: (12, 20),
      isolationReps: (15, 20),
      rest: Duration(seconds: 45),
      finisher: true,
    ),
    // Регулярность: короче и с запасом — чтобы тренировка радовала, а не выжимала.
    Goal.consistency => const GoalPath(
      compoundReps: (10, 12),
      isolationReps: (12, 15),
      rest: Duration(seconds: 90),
      reserveDelta: 1,
      exerciseDelta: -1,
    ),
  };
}

/// Отдых между подходами по главной цели (таймер на экране тренировки).
Duration restFor(Goal? goal) => goal == null
    ? const Duration(seconds: 90)
    : GoalPath.of(goal, TrainingLevel.intermediate).rest;

/// Как часто звать взвеситься: при «похудеть» (главной или дополнительной) — раз в 2 дня.
Duration weighInEveryFor(Goal? goal, List<Goal> extra) =>
    goal == Goal.fatLoss || extra.contains(Goal.fatLoss)
    ? const Duration(days: 2)
    : const Duration(days: 3);
