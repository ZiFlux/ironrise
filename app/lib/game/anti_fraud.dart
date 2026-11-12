import 'dart:math';

import 'game_config.dart';
import 'workout.dart';

class PulseSample {
  const PulseSample(this.at, this.bpm);

  final DateTime at;
  final int bpm;
}

/// Почему опыт за тренировку урезан. Показывается на экране итогов.
enum ValidityIssue {
  /// Пульса нет совсем.
  noPulse,

  /// Пульс записан меньше чем на часть тренировки.
  partialPulse,

  /// Средний пульс почти как в покое.
  lowIntensity,

  /// Пульс ровный, без циклов «подход — отдых».
  flatPulse,

  /// Подходов больше, чем можно сделать за это время.
  tooFast,
}

/// Итог проверки: коэффициент V и что именно его снизило.
class ValidityReport {
  const ValidityReport(this.value, this.issues, {required this.pulseCoverage});

  final double value;
  final List<ValidityIssue> issues;

  /// Доля тренировки, покрытая пульсом, 0..1.
  final double pulseCoverage;
}

/// Коэффициент достоверности V от 0 до 1 (ТЗ 4.4).
/// Ручной ввод сверяется с пульсом и с правдоподобным темпом подходов.
class AntiFraud {
  const AntiFraud._();

  static double validity({
    required WorkoutSession session,
    required List<PulseSample> pulse,
    required DateTime finishedAt,
    int restingHeartRate = GameConfig.defaultRestingHeartRate,
  }) => check(
    session: session,
    pulse: pulse,
    finishedAt: finishedAt,
    restingHeartRate: restingHeartRate,
  ).value;

  /// [unverified] — V без пульса: 0,5, у бета-тестеров 1 (как на сервере).
  static ValidityReport check({
    required WorkoutSession session,
    required List<PulseSample> pulse,
    required DateTime finishedAt,
    int restingHeartRate = GameConfig.defaultRestingHeartRate,
    double unverified = GameConfig.unverifiedValidity,
  }) {
    final duration = finishedAt.difference(session.startedAt);
    final coverage = _coverage(pulse, duration);
    final issues = <ValidityIssue>[];
    var value = 1.0;

    if (pulse.length < 2) {
      issues.add(ValidityIssue.noPulse);
      value = unverified;
    } else if (coverage < GameConfig.minPulseCoverage) {
      issues.add(ValidityIssue.partialPulse);
      value = unverified;
    } else {
      final values = [for (final s in pulse) s.bpm];
      final mean = values.reduce((a, b) => a + b) / values.length;
      final spread = sqrt(
        values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) /
            values.length,
      );
      if (mean < restingHeartRate + GameConfig.minPulseAboveRest) {
        issues.add(ValidityIssue.lowIntensity);
        value *= 0.3;
      }
      if (spread < GameConfig.minPulseSpread) {
        issues.add(ValidityIssue.flatPulse);
        value *= 0.6;
      }
    }
    // Нельзя сделать 50 подходов за 10 минут.
    if (duration < GameConfig.minTimePerSet * session.totalSets) {
      issues.add(ValidityIssue.tooFast);
      value *= 0.3;
    }
    return ValidityReport(value, issues, pulseCoverage: coverage);
  }

  static double _coverage(List<PulseSample> pulse, Duration duration) {
    if (pulse.length < 2 || duration.inSeconds == 0) return 0;
    final covered =
        pulse.last.at.difference(pulse.first.at).inSeconds / duration.inSeconds;
    return covered.clamp(0, 1).toDouble();
  }
}
