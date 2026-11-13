import 'anti_fraud.dart';
import 'workout.dart';

/// Насколько тяжёлым был подход по пульсу.
enum EffortLevel {
  light('легко'),
  moderate('умеренно'),
  hard('тяжело');

  const EffortLevel(this.label);
  final String label;
}

/// Подход глазами пульса: пик рядом с записью и подъём от отдыха перед ним.
class SetEffort {
  const SetEffort({
    required this.exerciseId,
    required this.setIndex,
    required this.peak,
    required this.rise,
    required this.level,
  });

  final String exerciseId;
  final int setIndex;
  final int peak;

  /// На сколько пульс поднялся от отдыха перед подходом.
  final int rise;
  final EffortLevel level;

  /// Подход записан, а пульс не поднялся — запись сомнительна.
  bool get flat => rise < SetEffortAnalysis.flatRise;
}

/// Анализ пульса по подходам (п. 30 бэклога). Во время подхода пульс растёт,
/// на отдыхе падает: сопоставляем эти циклы с моментами записи подходов.
class SetEffortAnalysis {
  const SetEffortAnalysis(this.sets);

  final List<SetEffort> sets;

  /// Пик ищем от 60 с до записи и до 20 с после (пульс догоняет нагрузку).
  static const peakBefore = Duration(seconds: 60);
  static const peakAfter = Duration(seconds: 20);

  /// Подъём меньше — пульс на подход не отреагировал.
  static const flatRise = 6;

  /// Доля резерва пульса: выше — тяжело, ниже — легко.
  static const hardReserve = 0.6;
  static const lightReserve = 0.35;

  bool get isEmpty => sets.isEmpty;

  List<SetEffort> get flatSets => [
    for (final s in sets)
      if (s.flat) s,
  ];

  /// Средний подъём пульса по упражнениям: присед поднимает сильнее сгибаний.
  Map<String, int> get riseByExercise {
    final sum = <String, int>{};
    final count = <String, int>{};
    for (final s in sets) {
      sum[s.exerciseId] = (sum[s.exerciseId] ?? 0) + s.rise;
      count[s.exerciseId] = (count[s.exerciseId] ?? 0) + 1;
    }
    return {for (final id in sum.keys) id: (sum[id]! / count[id]!).round()};
  }

  /// null — анализировать нечего: нет пульса или у подходов нет времени.
  static SetEffortAnalysis? of(
    WorkoutSession session,
    List<PulseSample> pulse, {
    required int restingHr,
    required int maxHr,
  }) {
    if (pulse.length < 10) return null;
    final timed = <(String, int, DateTime)>[
      for (final e in session.entries)
        for (final (i, s) in e.sets.indexed)
          if (s.at != null) (e.exercise.id, i, s.at!),
    ]..sort((a, b) => a.$3.compareTo(b.$3));
    if (timed.isEmpty) return null;

    final reserve = (maxHr - restingHr).clamp(20, 200);
    final out = <SetEffort>[];
    DateTime? previous;
    for (final (id, index, at) in timed) {
      final peakWindow = pulse.where(
        (p) =>
            !p.at.isBefore(at.subtract(peakBefore)) &&
            !p.at.isAfter(at.add(peakAfter)),
      );
      if (peakWindow.isEmpty) continue;
      final peak = peakWindow.map((p) => p.bpm).reduce((a, b) => a > b ? a : b);
      // Отдых перед подходом: от прошлой записи (+30 с) до начала окна пика.
      final restFrom =
          previous?.add(const Duration(seconds: 30)) ??
          at.subtract(const Duration(minutes: 3));
      final restWindow = pulse.where(
        (p) =>
            !p.at.isBefore(restFrom) &&
            p.at.isBefore(at.subtract(peakBefore ~/ 2)),
      );
      final baseline = restWindow.isEmpty
          ? restingHr
          : restWindow.map((p) => p.bpm).reduce((a, b) => a < b ? a : b);
      final share = (peak - restingHr) / reserve;
      out.add(
        SetEffort(
          exerciseId: id,
          setIndex: index,
          peak: peak,
          rise: (peak - baseline).clamp(0, 250),
          level: share >= hardReserve
              ? EffortLevel.hard
              : share <= lightReserve
              ? EffortLevel.light
              : EffortLevel.moderate,
        ),
      );
      previous = at;
    }
    return out.isEmpty ? null : SetEffortAnalysis(out);
  }

  /// Подсказка во время отдыха: пульс ещё высокий — отдохни подольше.
  /// null — можно продолжать.
  static String? restHint({
    required int? bpm,
    required Duration left,
    required int restingHr,
    required int maxHr,
  }) {
    if (bpm == null || left > const Duration(seconds: 15)) return null;
    final reserve = (maxHr - restingHr).clamp(20, 200);
    if ((bpm - restingHr) / reserve < 0.5) return null;
    return 'Пульс ещё $bpm — отдохни ещё 30 с';
  }
}
