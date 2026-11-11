/// Уровни силы (docs/TRAINING_SYSTEM.md, раздел 3.2).
/// Нормативы — черновик для проверки специалистом.
library;

enum StrengthLevel {
  start('Старт'),
  novice('Новичок'),
  amateur('Любитель'),
  experienced('Опытный'),
  strong('Сильный');

  const StrengthLevel(this.label);
  final String label;
}

/// Пороги уровней «Новичок…Сильный»: доля веса тела (или повторы без веса).
class _Thresholds {
  const _Thresholds(this.male, this.female);

  final List<double> male;
  final List<double> female;
}

class StrengthStandards {
  const StrengthStandards._();

  /// Расчётный максимум / вес тела.
  static const _byBodyweight = {
    'barbell_squat': _Thresholds([0.75, 1.25, 1.75, 2.25], [0.5, 0.85, 1.25, 1.6]),
    'bench_press': _Thresholds([0.5, 0.85, 1.25, 1.6], [0.3, 0.5, 0.75, 1.0]),
    'lat_pulldown': _Thresholds([0.5, 0.8, 1.1, 1.4], [0.35, 0.55, 0.8, 1.0]),
  };

  /// Максимум повторов в подходе для упражнений с собственным весом.
  static const _byReps = {
    'push_up': _Thresholds([5, 15, 30, 45], [2, 8, 18, 30]),
    'pull_up': _Thresholds([1, 5, 10, 15], [1, 3, 6, 10]),
  };

  /// Упражнения, по которым есть норматив.
  static Iterable<String> get exercises => [..._byBodyweight.keys, ..._byReps.keys];

  static bool usesReps(String exerciseId) => _byReps.containsKey(exerciseId);

  /// Уровень по расчётному максимуму и весу тела; null — норматива нет или не хватает данных.
  static StrengthLevel? byOneRepMax(String exerciseId, double oneRepMax, double? bodyweightKg, {required bool female}) {
    final t = _byBodyweight[exerciseId];
    if (t == null || bodyweightKg == null || bodyweightKg <= 0) return null;
    return _level(oneRepMax / bodyweightKg, female ? t.female : t.male);
  }

  static StrengthLevel? byReps(String exerciseId, int reps, {required bool female}) {
    final t = _byReps[exerciseId];
    if (t == null) return null;
    return _level(reps.toDouble(), female ? t.female : t.male);
  }

  static StrengthLevel _level(double value, List<double> thresholds) {
    var level = 0;
    for (final threshold in thresholds) {
      if (value >= threshold) level++;
    }
    return StrengthLevel.values[level];
  }

  /// Общий уровень — средний по упражнениям, где он известен.
  static StrengthLevel? overall(Iterable<StrengthLevel> levels) {
    if (levels.isEmpty) return null;
    final mean = levels.map((l) => l.index).reduce((a, b) => a + b) / levels.length;
    return StrengthLevel.values[mean.floor()];
  }
}
