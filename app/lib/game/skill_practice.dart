/// «Не получается упражнение» — учимся (docs/TRAINING_SYSTEM.md 15).
///
/// 1. Сразу: на сегодня — замена с теми же мышцами, проще (exercise_swap.dart).
/// 2. Дальше: в тренировках, где по плану стоит это упражнение, — замена и
///    комплекс подводящих (вис, негативы, облегчённые варианты…), чтобы движение
///    начало получаться.
/// 3. Через две недели — проверка: упражнение возвращается в план. Получилось —
///    отработка закончена, нет — ещё две недели.
/// 4. Комплекс можно делать отдельно от плана, хоть каждый день. Если человек
///    делал его вне тренировок за последнюю неделю, в тренировки идёт только
///    замена — комплекс не дублируется.
library;

import 'exercise_catalog.dart';
import 'exercise_swap.dart';
import 'program.dart';

/// Упражнение, которое учимся делать.
class SkillGoal {
  const SkillGoal({
    required this.exerciseId,
    required this.since,
    this.practice = const [],
    this.checks = 0,
  });

  final String exerciseId;

  /// С какого момента учимся (после неудачной проверки — заново).
  final DateTime since;

  /// Когда комплекс делался отдельно от плана.
  final List<DateTime> practice;

  /// Сколько проверок не прошло.
  final int checks;

  static const checkAfter = Duration(days: 14);

  /// Комплекс вне тренировок за это время — в тренировки только замена.
  static const outsideFresh = Duration(days: 7);

  Exercise get exercise => ExerciseCatalog.byId(exerciseId);

  DateTime get checkAt => since.add(checkAfter);

  bool checkDue(DateTime now) => !now.isBefore(checkAt);

  /// Дней до проверки (0 — уже пора).
  int daysToCheck(DateTime now) {
    final left = checkAt.difference(now);
    return left.isNegative ? 0 : (left.inHours / 24).ceil();
  }

  bool practicedOutside(DateTime now) =>
      practice.any((d) => now.difference(d) < outsideFresh);

  SkillGoal copyWith({
    DateTime? since,
    List<DateTime>? practice,
    int? checks,
  }) => SkillGoal(
    exerciseId: exerciseId,
    since: since ?? this.since,
    practice: practice ?? this.practice,
    checks: checks ?? this.checks,
  );

  Map<String, dynamic> toJson() => {
    'since': since.toIso8601String(),
    'practice': [for (final d in practice) d.toIso8601String()],
    'checks': checks,
  };

  factory SkillGoal.fromJson(String id, Map<String, dynamic> j) => SkillGoal(
    exerciseId: id,
    since: DateTime.parse(j['since'] as String),
    practice: [
      for (final d in j['practice'] as List? ?? const [])
        DateTime.parse(d as String),
    ],
    checks: (j['checks'] as num?)?.toInt() ?? 0,
  );
}

class SkillPractice {
  const SkillPractice._();

  /// Подводящих в тренировке по плану: больше — тренировка растянется.
  static const drillsInWorkout = 2;

  /// Подводящих в отдельном комплексе.
  static const drillsInComplex = 4;

  /// Подводящие для [target]: сначала отмеченные в базе (prepFor), потом проще в
  /// том же движении — от самого близкого по сложности. Только доступные с
  /// инвентарём, без исключённых и без самого упражнения.
  static List<Exercise> drillsFor(
    Exercise target, {
    required Equipment equipment,
    Set<String> excluded = const {},
    int limit = drillsInComplex,
  }) {
    bool ok(Exercise e) =>
        e.id != target.id &&
        !excluded.contains(e.id) &&
        isAvailable(e.id, equipment);
    final tagged =
        [
          for (final e in ExerciseCatalog.all)
            if (e.prepFor.contains(target.id) && ok(e)) e,
        ]..sort((a, b) {
          // Сначала упражнения на само движение со своим весом (вис, лопатки,
          // негативы), потом тренажёры; внутри — от простого.
          int rank(Exercise e) => (e.usesWeight ? 10 : 0) + e.difficulty;
          return rank(a).compareTo(rank(b));
        });
    final easier =
        [
          for (final e in ExerciseCatalog.all)
            if (e.pattern == target.pattern &&
                e.pattern.isNotEmpty &&
                e.difficulty < target.difficulty &&
                e.unit == target.unit &&
                ok(e) &&
                !tagged.contains(e))
              e,
        ]..sort(
          (a, b) => (target.difficulty - a.difficulty).compareTo(
            target.difficulty - b.difficulty,
          ),
        );
    return [...tagged, ...easier].take(limit).toList();
  }

  /// Замена на сегодня: проще и с теми же мышцами.
  static Exercise? alternativeFor(
    Exercise target, {
    required Equipment equipment,
    Set<String> inWorkout = const {},
    Set<String> excluded = const {},
    bool female = false,
  }) {
    final options = swapOptions(
      target,
      inWorkout: inWorkout,
      equipment: equipment,
      excluded: excluded,
      female: female,
    );
    // Проще — лучше; среди равных порядок swapOptions (совпадение по мышцам).
    return options.where((e) => e.difficulty < target.difficulty).firstOrNull ??
        options.firstOrNull;
  }

  /// Подводящее в плане: 2 подхода с запасом — учимся, а не выкладываемся.
  static PlannedExercise drillPlan(Exercise e, String targetId) {
    final seconds = e.unit == ExerciseUnit.seconds;
    return PlannedExercise(
      e.id,
      sets: 2,
      repsMin: seconds ? e.defaultReps : (e.defaultReps * 0.6).round(),
      repsMax: seconds ? e.defaultReps + 15 : e.defaultReps,
      repsInReserve: 2,
      skillFor: targetId,
      skillRole: SkillRole.drill,
    );
  }

  /// Отдельный комплекс для [goal]: подводящие по 2 подхода.
  static List<PlannedExercise> complex(
    SkillGoal goal, {
    required Equipment equipment,
    Set<String> excluded = const {},
  }) => [
    for (final e in drillsFor(
      goal.exercise,
      equipment: equipment,
      excluded: excluded,
    ))
      drillPlan(e, goal.exerciseId),
  ];

  /// День плана с отработкой: где стоит упражнение, которое учимся делать, —
  /// замена и подводящие или проверка. Сам день не меняется, если отрабатывать
  /// в нём нечего.
  static ProgramDay apply(
    ProgramDay day, {
    required Map<String, SkillGoal> goals,
    required DateTime now,
    required Equipment equipment,
    Set<String> excluded = const {},
    bool female = false,
  }) {
    if (goals.isEmpty) return day;
    final inDay = {for (final e in day.exercises) e.exerciseId};
    final out = <PlannedExercise>[];
    var changed = false;
    for (final planned in day.exercises) {
      final goal = goals[planned.exerciseId];
      if (goal == null) {
        out.add(planned);
        continue;
      }
      changed = true;
      if (goal.checkDue(now)) {
        // Проверка: само упражнение, без замены.
        out.add(
          planned.copyWith(
            skillFor: goal.exerciseId,
            skillRole: SkillRole.check,
          ),
        );
        continue;
      }
      final alternative = alternativeFor(
        goal.exercise,
        equipment: equipment,
        inWorkout: inDay,
        excluded: excluded,
        female: female,
      );
      if (alternative != null) {
        inDay.add(alternative.id);
        out.add(
          planned.copyWith(
            exerciseId: alternative.id,
            skillFor: goal.exerciseId,
            skillRole: SkillRole.alternative,
          ),
        );
      }
      if (goal.practicedOutside(now)) continue;
      for (final drill in drillsFor(
        goal.exercise,
        equipment: equipment,
        excluded: {...excluded, ...inDay},
        limit: drillsInWorkout,
      )) {
        inDay.add(drill.id);
        out.add(drillPlan(drill, goal.exerciseId));
      }
    }
    return changed ? ProgramDay(day.id, day.title, out) : day;
  }

  /// Итог проверки: получилось — хотя бы один подход на нижнюю границу повторов.
  /// null — проверку не делали (подходов нет).
  static bool? checkPassed(PlannedExercise plan, List<int> reps) {
    if (reps.isEmpty) return null;
    return reps.any((r) => r >= plan.repsMin);
  }

  /// Тренировка вне плана считается отработкой, если в ней сделаны хотя бы два
  /// подводящих (или все, если их меньше двух).
  static bool isPractice(SkillGoal goal, Set<String> doneIds, Equipment eq) {
    final drills = drillsFor(goal.exercise, equipment: eq);
    if (drills.isEmpty) return false;
    final done = drills.where((d) => doneIds.contains(d.id)).length;
    return done >= (drills.length < 2 ? drills.length : 2);
  }
}
