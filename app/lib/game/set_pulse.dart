import 'anti_fraud.dart';
import 'set_effort.dart';
import 'workout.dart';

/// Сводка пульса и времени по подходу для сервера (п. 106 бэклога).
/// Сырой ряд остаётся на телефоне и сворачивается сервером по минутам; здесь —
/// то, что нужно для норм пульса по упражнениям (п. 118) и анализа подходов.
typedef SetPulse = ({
  /// Секунд от начала тренировки до записи подхода.
  int t,

  /// Секунд отдыха перед подходом (от прошлого подхода); у первого — null.
  int? rest,

  /// Пик пульса в окне подхода: за 60 с до записи и 20 с после.
  int? peak,

  /// Минимум пульса на отдыхе перед подходом (после прошлого пика).
  int? base,
});

/// Сводки по всем подходам тренировки в порядке записи. [pulse] пустой, если
/// согласия на пульс нет, — тогда только время и отдых.
List<(String exerciseId, int index, SetPulse)> setPulses({
  required DateTime startedAt,
  required List<ExerciseEntry> entries,
  required List<PulseSample> pulse,
}) {
  final sets = [
    for (final e in entries)
      for (final (i, s) in e.sets.indexed)
        if (s.at != null) (id: e.exercise.id, index: i, at: s.at!),
  ]..sort((a, b) => a.at.compareTo(b.at));
  final out = <(String, int, SetPulse)>[];
  DateTime? previous;
  for (final s in sets) {
    final from = s.at.subtract(SetEffortAnalysis.peakBefore);
    final to = s.at.add(SetEffortAnalysis.peakAfter);
    int? maxIn(DateTime a, DateTime b) {
      int? m;
      for (final p in pulse) {
        if (p.at.isBefore(a) || p.at.isAfter(b)) continue;
        if (m == null || p.bpm > m) m = p.bpm;
      }
      return m;
    }

    int? minIn(DateTime a, DateTime b) {
      int? m;
      for (final p in pulse) {
        if (p.at.isBefore(a) || p.at.isAfter(b)) continue;
        if (m == null || p.bpm < m) m = p.bpm;
      }
      return m;
    }

    // Отдых — от конца окна прошлого подхода до начала окна этого.
    final restFrom = previous?.add(SetEffortAnalysis.peakAfter);
    out.add((
      s.id,
      s.index,
      (
        t: s.at.difference(startedAt).inSeconds.clamp(0, 86400),
        rest: previous == null
            ? null
            : s.at.difference(previous).inSeconds.clamp(0, 86400),
        peak: maxIn(from, to),
        base: restFrom == null || !restFrom.isBefore(from)
            ? null
            : minIn(restFrom, from),
      ),
    ));
    previous = s.at;
  }
  return out;
}
