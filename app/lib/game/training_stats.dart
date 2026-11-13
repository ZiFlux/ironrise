import 'body_part.dart';
import 'muscles.dart';
import 'calendar.dart';
import 'program.dart';
import 'workout.dart';
import '../state/training_log.dart';

/// Статистика по журналу тренировок: только чистые расчёты, без интерфейса.
class TrainingStats {
  const TrainingStats(this.log);

  /// От новых к старым.
  final List<LoggedWorkout> log;

  Iterable<LoggedWorkout> get strength =>
      log.where((w) => w.kind == WorkoutKind.strength);

  int get workouts => log.length;
  int get sets => strength.fold(0, (n, w) => n + w.sets);
  double get volume => strength.fold(0.0, (v, w) => v + w.volume);

  int inLastDays(int days, DateTime now) {
    final from = StatDates.startOfDay(now).subtract(Duration(days: days - 1));
    return log.where((w) => !w.at.isBefore(from)).length;
  }

  /// Дни с тренировками: ключ dayKey → какие виды были.
  Map<String, Set<WorkoutKind>> get activeDays {
    final out = <String, Set<WorkoutKind>>{};
    for (final w in log) {
      (out[dayKey(w.at)] ??= {}).add(w.kind);
    }
    return out;
  }

  /// Объём силовых по неделям (с понедельника), [weeks] последних, от старых к новым.
  List<({DateTime week, double volume, int workouts})> weekly(
    DateTime now, {
    int weeks = 8,
  }) {
    final thisWeek = StatDates.mondayOf(now);
    return [
      for (var i = weeks - 1; i >= 0; i--)
        () {
          final start = thisWeek.subtract(Duration(days: 7 * i));
          final end = start.add(const Duration(days: 7));
          final inWeek = log.where(
            (w) => !w.at.isBefore(start) && w.at.isBefore(end),
          );
          return (
            week: start,
            volume: inWeek
                .where((w) => w.kind == WorkoutKind.strength)
                .fold(0.0, (v, w) => v + w.volume),
            workouts: inWeek.length,
          );
        }(),
    ];
  }

  /// Опыт по частям тела за последние [days] дней.
  Map<BodyPart, int> gainsInLastDays(int days, DateTime now) {
    final from = StatDates.startOfDay(now).subtract(Duration(days: days - 1));
    final out = <BodyPart, int>{};
    for (final w in log.where((w) => !w.at.isBefore(from))) {
      for (final g in w.gains.entries) {
        out[g.key] = (out[g.key] ?? 0) + g.value;
      }
    }
    return out;
  }

  /// Упражнения, которые делал, — от частых к редким.
  List<String> get exercisesDone {
    final count = <String, int>{};
    for (final w in strength) {
      for (final e in w.exercises) {
        count[e.id] = (count[e.id] ?? 0) + 1;
      }
    }
    return count.keys.toList()..sort((a, b) => count[b]!.compareTo(count[a]!));
  }

  /// Динамика упражнения: лучший подход каждой тренировки, от старых к новым.
  /// С весом — расчётный максимум (кг), без веса — повторы или секунды.
  List<({DateTime at, double value})> progressOf(
    String exerciseId, {
    int last = 12,
  }) {
    final points = <({DateTime at, double value})>[];
    for (final w in strength) {
      for (final e in w.exercises.where((e) => e.id == exerciseId)) {
        if (e.sets.isEmpty) continue;
        points.add((at: w.at, value: _best(e.sets)));
      }
    }
    return points.take(last).toList().reversed.toList();
  }

  static double _best(List<SetRecord> sets) => sets
      .map(
        (s) => s.weight > 0
            ? estimatedOneRepMax(s) ?? s.weight
            : s.reps.toDouble(),
      )
      .reduce((a, b) => a > b ? a : b);

  /// Какие упражнения больше всего прокачали часть тела: подходы × доля нагрузки.
  List<({String id, double sets})> topExercisesFor(
    BodyPart part,
    double Function(String id) shareOf, {
    int limit = 3,
  }) {
    final score = <String, double>{};
    for (final w in strength) {
      for (final e in w.exercises) {
        final share = shareOf(e.id);
        if (share <= 0) continue;
        score[e.id] = (score[e.id] ?? 0) + e.sets.length * share;
      }
    }
    final sorted = score.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(limit)) (id: e.key, sets: e.value)];
  }
}

/// Небольшие помощники с датами без зависимости от Flutter.
class StatDates {
  const StatDates._();

  static DateTime startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  static DateTime mondayOf(DateTime d) =>
      startOfDay(d).subtract(Duration(days: d.weekday - 1));
}

/// «Горящие» части тела: на что больше всего опыта за последние [days] дней.
/// До двух частей, каждая — не меньше пятой части опыта. Журнала мало (свежая
/// установка) — берём накопленные очки мышц героя [muscles].
Set<BodyPart> hotParts(
  List<LoggedWorkout> log,
  DateTime now, {
  int days = 14,
  MusclePoints muscles = const {},
}) {
  final gains = TrainingStats(log).gainsInLastDays(days, now);
  final total = gains.values.fold(0, (a, b) => a + b);
  if (total < 20) {
    // Нет свежих данных — по мышцам: часть, чьи мышцы набрали больше всего.
    final byPart = <BodyPart, double>{};
    for (final e in muscles.entries) {
      byPart[e.key.part] = (byPart[e.key.part] ?? 0) + e.value;
    }
    final sum = byPart.values.fold(0.0, (a, b) => a + b);
    if (sum <= 0) return const {};
    final sorted = byPart.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return {
      for (final e in sorted.take(2))
        if (e.value / sum >= 0.2) e.key,
    };
  }
  final sorted = gains.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {
    for (final e in sorted.take(2))
      if (e.value / total >= 0.2) e.key,
  };
}

/// Очки мышц за последние [days] дней — что качается сейчас (для поз и «огней»).
MusclePoints recentMuscles(
  List<LoggedWorkout> log,
  DateTime now, {
  int days = 14,
}) {
  final from = StatDates.startOfDay(now).subtract(Duration(days: days - 1));
  return MuscleMath.pointsOf([
    for (final w in log)
      if (w.kind == WorkoutKind.strength && !w.at.isBefore(from))
        for (final e in w.exercises) (exerciseId: e.id, sets: e.sets.length),
  ], 1);
}

/// Две самые нагруженные мышцы за последнее время (или за всё, если журнала мало).
Set<Muscle> hotMuscles(
  List<LoggedWorkout> log,
  DateTime now, {
  MusclePoints muscles = const {},
}) {
  var points = recentMuscles(log, now);
  if (points.values.fold(0.0, (a, b) => a + b) <= 0) points = muscles;
  final sorted = points.entries.where((e) => e.value > 0).toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return {for (final e in sorted.take(2)) e.key};
}
