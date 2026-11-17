import 'exercise_catalog.dart';
import 'program.dart';

/// Лесенки «проще → сложнее» внутри движения (pattern) — пункт 19 бэклога.
///
/// Шаблон дня задаёт движение, а вариант подбирается под уровень человека в нём:
/// новичок начинает с самых простых, хорошие результаты для своего веса тела
/// открывают вариант сложнее. Потолок — шаблон +1 ступень и не выше 3.
class ExerciseLadder {
  const ExerciseLadder._();

  static const maxLevel = 3;

  /// Третья ступень (штанга, становая, подтягивания) — только после «Старта».
  static const workoutsBeforeTopLevel = ProgramPhase.startWorkouts;

  /// Повторы сверх плана у упражнений без веса, после которых пора сложнее.
  static const bodyweightRepsToLevelUp = 6;

  /// Без веса тела в профиле — по числу прибавок рабочего веса.
  static const increasesToLevelUp = 4;

  /// Рабочий вес / вес тела, с которого вариант освоен. У гантелей — вес одной.
  static const _masteredAt = <String, double>{
    'machine_chest_press': 0.5,
    'db_bench_press': 0.25,
    'bench_press': 0.8,
    'lat_pulldown': 0.6,
    'leg_press': 1.2,
    'goblet_squat': 0.3,
    'leg_curl': 0.4,
    'romanian_deadlift': 0.6,
    'db_shoulder_press': 0.15,
    'db_curl': 0.15,
    'hammer_curl': 0.15,
    'triceps_pushdown': 0.3,
    'french_press': 0.25,
    'hip_thrust': 0.8,
    'sumo_squat': 0.3,
    'lying_leg_curl': 0.4,
  };

  /// Женщинам те же ступени — при меньшей доле веса тела.
  static const femaleFactor = 0.7;

  /// Уровень в движении: сохранённый или стартовый, но не ниже упражнения,
  /// которое человек уже делает (у прежних пользователей план не упрощается).
  static int levelOf(
    String pattern, {
    required Map<String, int> levels,
    required Map<String, ExerciseProgress> progress,
    required int start,
  }) {
    var level = levels[pattern] ?? start;
    for (final id in progress.keys) {
      final e = ExerciseCatalog.tryById(id);
      if (e != null && e.pattern == pattern && e.difficulty > level) {
        level = e.difficulty;
      }
    }
    return level.clamp(1, maxLevel);
  }

  /// Освоил ли вариант: результат хороший для своей комплекции.
  static bool mastered(
    Exercise exercise,
    ExerciseProgress progress, {
    double? bodyweightKg,
    bool female = false,
  }) {
    if (!exercise.usesWeight) {
      return progress.repsBonus >= bodyweightRepsToLevelUp;
    }
    final weight = progress.workingWeight;
    if (weight == null) return false;
    final ratio = _masteredAt[exercise.id];
    if (ratio != null && bodyweightKg != null && bodyweightKg > 0) {
      return weight >= bodyweightKg * ratio * (female ? femaleFactor : 1);
    }
    return progress.increases >= increasesToLevelUp;
  }

  /// Есть ли куда расти: вариант сложнее в том же движении с этим инвентарём.
  static Exercise? harderThan(Exercise exercise, Equipment equipment) =>
      ExerciseCatalog.all
          .where(
            (e) =>
                e.pattern == exercise.pattern &&
                e.unit == exercise.unit &&
                e.difficulty == exercise.difficulty + 1 &&
                isAvailable(e.id, equipment),
          )
          .firstOrNull;
}

/// Переход на ступень выше: что было и что будет.
typedef LevelUp = ({String from, String to});
