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

/// Упражнение в плане: подходы, диапазон повторов и сколько повторов оставить в запасе.
class PlannedExercise {
  const PlannedExercise(
    this.exerciseId, {
    required this.sets,
    required this.repsMin,
    required this.repsMax,
    required this.repsInReserve,
  });

  final String exerciseId;
  final int sets;
  final int repsMin;
  final int repsMax;
  final int repsInReserve;

  Exercise get exercise => ExerciseCatalog.byId(exerciseId);

  Map<String, dynamic> toJson() => {
    'exerciseId': exerciseId,
    'sets': sets,
    'repsMin': repsMin,
    'repsMax': repsMax,
    'repsInReserve': repsInReserve,
  };

  factory PlannedExercise.fromJson(Map<String, dynamic> j) => PlannedExercise(
    j['exerciseId'],
    sets: j['sets'],
    repsMin: j['repsMin'],
    repsMax: j['repsMax'],
    repsInReserve: j['repsInReserve'],
  );
}

class ProgramDay {
  const ProgramDay(this.id, this.title, this.exercises);

  final String id;
  final String title;
  final List<PlannedExercise> exercises;

  /// Подход с отдыхом ≈ 2,5 минуты, плюс разминка.
  Duration get estimatedDuration =>
      Duration(minutes: 8 + exercises.fold(0, (n, e) => n + e.sets) * 3);
}

/// Фаза «Старт» (недели 1–4): всё тело, дни А и Б по очереди,
/// 2 подхода × 10–12 повторов, 3 повтора в запасе.
class StartProgram {
  const StartProgram._();

  static PlannedExercise _base(String id) =>
      PlannedExercise(id, sets: 2, repsMin: 10, repsMax: 12, repsInReserve: 3);

  /// Планка — в секундах.
  static const _plank = PlannedExercise('plank', sets: 2, repsMin: 20, repsMax: 30, repsInReserve: 3);

  static List<ProgramDay> days(Equipment equipment) => switch (equipment) {
    Equipment.gym => [
      ProgramDay('A', 'Тренировка А', [
        _base('barbell_squat'),
        _base('bench_press'),
        _base('lat_pulldown'),
        _plank,
      ]),
      ProgramDay('B', 'Тренировка Б', [
        _base('romanian_deadlift'),
        _base('db_shoulder_press'),
        _base('db_row'),
        _base('lunges'),
      ]),
    ],
    Equipment.dumbbells => [
      ProgramDay('A', 'Тренировка А', [
        _base('bodyweight_squat'),
        _base('push_up'),
        _base('db_row'),
        _plank,
      ]),
      ProgramDay('B', 'Тренировка Б', [
        _base('romanian_deadlift'),
        _base('db_shoulder_press'),
        _base('db_row'),
        _base('lunges'),
      ]),
    ],
  };
}

/// Нужен тренажёр, штанга или турник: дома с гантелями недоступно.
const _gymOnly = {
  'barbell_squat', 'bench_press', 'lat_pulldown', 'leg_press', 'back_extension', 'pull_up', 'dips', 'hanging_leg_raise',
};

bool isAvailable(String exerciseId, Equipment equipment) =>
    equipment == Equipment.gym || !_gymOnly.contains(exerciseId);

/// Чем заменить упражнение зала дома с гантелями, по порядку предпочтения.
const _homeAlternatives = <String, List<String>>{
  'barbell_squat': ['bodyweight_squat', 'lunges'],
  'bench_press': ['push_up', 'db_bench_press'],
  'lat_pulldown': ['db_row'],
  'leg_press': ['lunges', 'bodyweight_squat'],
  'back_extension': ['romanian_deadlift'],
  'pull_up': ['db_row'],
  'dips': ['push_up'],
  'hanging_leg_raise': ['crunches', 'plank'],
};

enum ProgramPhase {
  start('Старт'),
  base('База');

  const ProgramPhase(this.label);
  final String label;

  /// Столько тренировок по плану длится «Старт» (≈ 4 недели по 3 тренировки).
  static const startWorkouts = 12;

  static ProgramPhase after(int completedPlanWorkouts) =>
      completedPlanWorkouts < startWorkouts ? ProgramPhase.start : ProgramPhase.base;
}

/// Фаза «База» (недели 5–12): 3 подхода × 8–12, 2 повтора в запасе,
/// дни по формату тренировок, точечное упражнение на отстающую часть.
class BaseProgram {
  const BaseProgram._();

  static PlannedExercise _base(String id) =>
      PlannedExercise(id, sets: 3, repsMin: 8, repsMax: 12, repsInReserve: 2);

  static const _plank = PlannedExercise('plank', sets: 3, repsMin: 30, repsMax: 45, repsInReserve: 2);

  static ProgramDay _day(String id, String title, List<String> exerciseIds) => ProgramDay(id, title, [
    for (final e in exerciseIds) e == 'plank' ? _plank : _base(e),
  ]);

  static final _fullBody = [
    _day('A', 'Тренировка А', ['barbell_squat', 'bench_press', 'lat_pulldown', 'plank']),
    _day('B', 'Тренировка Б', ['romanian_deadlift', 'db_shoulder_press', 'db_row', 'lunges']),
  ];

  static final _upperLower = [
    _day('U1', 'Верх 1', ['bench_press', 'lat_pulldown', 'db_shoulder_press', 'db_curl']),
    _day('L1', 'Низ 1', ['barbell_squat', 'romanian_deadlift', 'lunges', 'plank']),
    _day('U2', 'Верх 2', ['db_bench_press', 'db_row', 'push_up', 'french_press']),
    _day('L2', 'Низ 2', ['leg_press', 'back_extension', 'bodyweight_squat', 'hanging_leg_raise']),
  ];

  /// День отстающей части: упражнения добираются под отстающую часть тела.
  static final _focusDay = ProgramDay('F', 'День отстающей части', const []);

  /// 3 тренировки в неделю — фулбоди, 4 — верх/низ, 5 и больше — ещё день отстающей части.
  static List<ProgramDay> days(Equipment equipment, int sessionsPerWeek) {
    final template = switch (sessionsPerWeek) {
      <= 3 => _fullBody,
      4 => _upperLower,
      _ => [..._upperLower, _focusDay],
    };
    return [for (final day in template) forEquipment(day, equipment)];
  }

  /// Дома с гантелями упражнения зала заменяются доступными, без повторов внутри дня.
  static ProgramDay forEquipment(ProgramDay day, Equipment equipment) {
    if (equipment == Equipment.gym) return day;
    final used = <String>{};
    final exercises = <PlannedExercise>[];
    for (final planned in day.exercises) {
      final options = [planned.exerciseId, ...?_homeAlternatives[planned.exerciseId]];
      final id = options.where((o) => isAvailable(o, equipment) && !used.contains(o)).firstOrNull;
      if (id == null) continue;
      used.add(id);
      exercises.add(PlannedExercise(
        id,
        sets: planned.sets,
        repsMin: planned.repsMin,
        repsMax: planned.repsMax,
        repsInReserve: planned.repsInReserve,
      ));
    }
    return ProgramDay(day.id, day.title, exercises);
  }

  /// Точечное упражнение на отстающую часть: самое нагружающее её, доступное
  /// и ещё не стоящее в этом дне. Кардио качается с часов, его не добавляем.
  static PlannedExercise? accessoryFor(BodyPart lagging, ProgramDay day, Equipment equipment) {
    if (lagging == BodyPart.cardio) return null;
    final inDay = {for (final e in day.exercises) e.exerciseId};
    final exercise = ExerciseCatalog.forPart(lagging)
        .where((e) => isAvailable(e.id, equipment) && !inDay.contains(e.id))
        .firstOrNull;
    if (exercise == null) return null;
    final seconds = exercise.unit == ExerciseUnit.seconds;
    return PlannedExercise(
      exercise.id,
      sets: 2,
      repsMin: seconds ? 30 : 10,
      repsMax: seconds ? 45 : 15,
      repsInReserve: 2,
    );
  }

  /// День с точечными упражнениями: в обычный день одно в конец,
  /// в день отстающей части — три.
  static ProgramDay withAccessories(ProgramDay day, BodyPart? lagging, Equipment equipment) {
    final isFocusDay = day.id == _focusDay.id;
    var result = day;
    if (lagging != null) {
      for (var i = 0; i < (isFocusDay ? 3 : 1); i++) {
        final extra = accessoryFor(lagging, result, equipment);
        if (extra == null) break;
        result = ProgramDay(result.id, result.title, [...result.exercises, extra]);
      }
    }
    // День отстающей части, когда отставания нет, — обычная тренировка всего тела.
    return result.exercises.isEmpty ? forEquipment(_fullBody.first, equipment) : result;
  }
}

/// Прогресс в упражнении: рабочий вес (или цель повторов без веса) и недоборы подряд.
class ExerciseProgress {
  const ExerciseProgress({this.workingWeight, this.repsBonus = 0, this.misses = 0});

  /// null — вес ещё не подобран (калибровка).
  final double? workingWeight;

  /// Для упражнений без веса цель растёт повторами.
  final int repsBonus;
  final int misses;

  bool get isCalibrating => workingWeight == null;

  Map<String, dynamic> toJson() => {
    'workingWeight': workingWeight,
    'repsBonus': repsBonus,
    'misses': misses,
  };

  factory ExerciseProgress.fromJson(Map<String, dynamic> j) => ExerciseProgress(
    workingWeight: (j['workingWeight'] as num?)?.toDouble(),
    repsBonus: j['repsBonus'] ?? 0,
    misses: j['misses'] ?? 0,
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
    final target = repsRange(plan, current);
    final planned = sets.take(plan.sets).toList();
    final allTop = planned.length >= plan.sets && planned.every((s) => s.reps >= target.max);
    final belowMin = planned.any((s) => s.reps < target.min);

    if (!exercise.usesWeight) {
      if (allTop && hadReserve) {
        return change(
          ExerciseProgress(repsBonus: current.repsBonus + bodyweightRepsStep),
          ProgressKind.increase,
        );
      }
      return change(ExerciseProgress(repsBonus: current.repsBonus), ProgressKind.hold);
    }

    // Первая тренировка: вес, который человек выбрал сам, и есть рабочий.
    if (current.isCalibrating) {
      return change(ExerciseProgress(workingWeight: _lastWeight(sets)), ProgressKind.calibrated);
    }
    final weight = current.workingWeight!;
    if (allTop && hadReserve) {
      return change(
        ExerciseProgress(workingWeight: _round(weight + weightStep(exercise, weight))),
        ProgressKind.increase,
      );
    }
    if (!belowMin) return change(ExerciseProgress(workingWeight: weight), ProgressKind.hold);
    final misses = current.misses + 1;
    if (misses >= missesBeforeDeload) {
      return change(
        ExerciseProgress(workingWeight: _round(weight * deloadFactor)),
        ProgressKind.deload,
      );
    }
    return change(ExerciseProgress(workingWeight: weight, misses: misses), ProgressKind.hold);
  }

  /// Ноги и тяги растут быстрее жимов; гантели — по килограмму.
  static double weightStep(Exercise exercise, double weight) {
    if (exercise.id.startsWith('db_')) return 1;
    final big = exercise.mainPart == BodyPart.legs || exercise.mainPart == BodyPart.back;
    if (!big) return 2.5;
    return weight < 40 ? 2.5 : 5;
  }

  static ({int min, int max}) repsRange(PlannedExercise plan, ExerciseProgress progress) =>
      (min: plan.repsMin + progress.repsBonus, max: plan.repsMax + progress.repsBonus);

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
