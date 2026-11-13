import 'dart:math';

import 'exercise_catalog.dart';
import 'muscles.dart';
import 'session_builder.dart';
import 'training_stats.dart';
import '../state/training_log.dart';

/// Куда идёт упражнение.
enum LiftTrend { growing, plateau, declining }

/// Прогноз упражнения по истории: тренд за последние тренировки и где человек
/// будет через 4 и 12 недель, если продолжит так же.
class LiftForecast {
  const LiftForecast({
    required this.exerciseId,
    required this.current,
    required this.weeklyPct,
    required this.in4Weeks,
    required this.in12Weeks,
    required this.trend,
    required this.weeksOfData,
  });

  final String exerciseId;

  /// Расчётный максимум (кг) или лучший подход (повторы, секунды) сейчас.
  final double current;

  /// Прирост в неделю, доля (0,02 — 2 %).
  final double weeklyPct;
  final double in4Weeks;
  final double in12Weeks;
  final LiftTrend trend;
  final double weeksOfData;
}

/// Анализ тренировок (п. 51 бэклога): нагрузка на мышцы против недельной нормы,
/// прогноз по упражнениям, плато и подсказки.
class TrainingAnalysis {
  const TrainingAnalysis(this.log, {required this.level, required this.now});

  /// От новых к старым.
  final List<LoggedWorkout> log;
  final TrainingLevel level;
  final DateTime now;

  /// Быстрее этого не растут даже при идеальном режиме: новичок ~3 % в неделю,
  /// средний ~1,25 %, опытный ~0,5 %. Прогноз не обещает больше.
  static double maxWeeklyGain(TrainingLevel level) => switch (level) {
    TrainingLevel.novice => 0.03,
    TrainingLevel.intermediate => 0.0125,
    TrainingLevel.advanced => 0.005,
  };

  /// Рабочие подходы на каждую мышцу за последние [days] дней (главная мышца
  /// упражнения — целый подход, помогающая — частично).
  Map<Muscle, double> muscleSets({int days = 7}) {
    final from = StatDates.startOfDay(now).subtract(Duration(days: days - 1));
    final out = <Muscle, double>{};
    for (final w in log) {
      if (w.kind != WorkoutKind.strength || w.at.isBefore(from)) continue;
      for (final e in w.exercises) {
        for (final m in Muscle.values) {
          final c = setCredit(e.id, m);
          if (c > 0) out[m] = (out[m] ?? 0) + c * e.sets.length;
        }
      }
    }
    return out;
  }

  /// Доля недельной нормы по мышцам: 1 — норма выполнена.
  Map<Muscle, double> coverage() {
    final done = muscleSets();
    return {
      for (final m in Muscle.values) m: (done[m] ?? 0) / weeklyTarget(m, level),
    };
  }

  /// Прогноз по упражнению: нужны 3 тренировки на отрезке от 10 дней.
  LiftForecast? forecast(String exerciseId) {
    final points = TrainingStats(log).progressOf(exerciseId, last: 12);
    if (points.length < 3) return null;
    final first = points.first.at;
    final span = points.last.at.difference(first).inHours / 24;
    if (span < 10) return null;
    // Линейная регрессия: значение от дня.
    final xs = [for (final p in points) p.at.difference(first).inHours / 24];
    final ys = [for (final p in points) p.value];
    final n = xs.length;
    final mx = xs.reduce((a, b) => a + b) / n;
    final my = ys.reduce((a, b) => a + b) / n;
    var num = 0.0, den = 0.0;
    for (var i = 0; i < n; i++) {
      num += (xs[i] - mx) * (ys[i] - my);
      den += (xs[i] - mx) * (xs[i] - mx);
    }
    final slopePerDay = den == 0 ? 0.0 : num / den;
    // «Сейчас» — по линии тренда, а не по одному удачному дню.
    final current = max(0.0, my + slopePerDay * (xs.last - mx));
    if (current <= 0) return null;
    final rawPct = slopePerDay * 7 / current;
    final pct = rawPct.clamp(-0.05, maxWeeklyGain(level));
    final trend = pct > 0.003
        ? LiftTrend.growing
        : pct < -0.005
        ? LiftTrend.declining
        : LiftTrend.plateau;
    // Рост замедляется: дальний прогноз — с поправкой 0,75.
    final grow = max(0.0, pct);
    return LiftForecast(
      exerciseId: exerciseId,
      current: current,
      weeklyPct: pct,
      in4Weeks: current * (1 + grow * 4),
      in12Weeks: current * (1 + grow * 12 * 0.75),
      trend: trend,
      weeksOfData: span / 7,
    );
  }

  /// Прогнозы по самым частым упражнениям (до [limit]).
  List<LiftForecast> forecasts({int limit = 4}) => [
    for (final id in TrainingStats(log).exercisesDone)
      if (ExerciseCatalog.tryById(id) != null) ?forecast(id),
  ].take(limit).toList();

  /// Тренировок за 4 недели против плана: насколько режим соблюдается (0–1+).
  double consistency(int plannedPerWeek) {
    if (plannedPerWeek <= 0) return 1;
    final from = StatDates.startOfDay(now).subtract(const Duration(days: 27));
    final done = log
        .where((w) => w.kind == WorkoutKind.strength && !w.at.isBefore(from))
        .length;
    return done / (plannedPerWeek * 4);
  }

  /// Короткие выводы для экрана: что недогружено, что стоит, что растёт.
  List<String> insights({required int plannedPerWeek}) {
    final out = <String>[];
    final hasWeek = muscleSets().values.any((v) => v > 0);
    if (hasWeek) {
      final weak =
          coverage().entries
              .where((e) => e.value < 0.6 && !_minor(e.key))
              .toList()
            ..sort((a, b) => a.value.compareTo(b.value));
      if (weak.isNotEmpty) {
        final names = weak.take(3).map((e) => e.key.label.toLowerCase());
        out.add(
          'Мало нагрузки за неделю: ${names.join(', ')}. Тренировки по плану '
          'закрывают норму — ${level.weeklySets} подходов на мышцу',
        );
      } else {
        out.add('Норма нагрузки на мышцы за неделю выполнена');
      }
    }
    final c = consistency(plannedPerWeek);
    if (log.isNotEmpty && c < 0.7) {
      out.add(
        'За 4 недели сделано ${(c * 100).round()} % тренировок по графику — '
        'из-за пропусков рост медленнее прогноза',
      );
    }
    for (final f in forecasts()) {
      final name = ExerciseCatalog.byId(f.exerciseId).name;
      switch (f.trend) {
        case LiftTrend.plateau when f.weeksOfData >= 3:
          out.add(
            '$name не растёт ${f.weeksOfData.round()} нед. — помогут облегчённая '
            'неделя, другой диапазон повторов или вариант упражнения',
          );
        case LiftTrend.declining:
          out.add(
            '$name снижается — проверь сон, питание и не болит ли что-то',
          );
        default:
          break;
      }
    }
    return out;
  }

  static bool _minor(Muscle m) => const {
    Muscle.forearms,
    Muscle.calves,
    Muscle.obliques,
    Muscle.traps,
    Muscle.lowerBack,
  }.contains(m);
}
