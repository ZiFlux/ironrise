import 'dart:math';

import 'game_config.dart';
import 'workout.dart';

class PulseSample {
  const PulseSample(this.at, this.bpm);

  final DateTime at;
  final int bpm;
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
  }) {
    final duration = finishedAt.difference(session.startedAt);
    final base = _hasEnoughPulse(pulse, duration)
        ? _pulseFactor(pulse, restingHeartRate)
        : GameConfig.unverifiedValidity;
    return base * _paceFactor(session.totalSets, duration);
  }

  static bool _hasEnoughPulse(List<PulseSample> pulse, Duration duration) {
    if (pulse.length < 2 || duration.inSeconds == 0) return false;
    final covered = pulse.last.at.difference(pulse.first.at);
    return covered.inSeconds / duration.inSeconds >= GameConfig.minPulseCoverage;
  }

  static double _pulseFactor(List<PulseSample> pulse, int restingHeartRate) {
    final values = [for (final s in pulse) s.bpm];
    final mean = values.reduce((a, b) => a + b) / values.length;
    final spread = sqrt(values.map((v) => pow(v - mean, 2)).reduce((a, b) => a + b) / values.length);

    var factor = 1.0;
    if (mean < restingHeartRate + GameConfig.minPulseAboveRest) factor *= 0.3;
    if (spread < GameConfig.minPulseSpread) factor *= 0.6;
    return factor;
  }

  /// Нельзя сделать 50 подходов за 10 минут.
  static double _paceFactor(int totalSets, Duration duration) =>
      duration < GameConfig.minTimePerSet * totalSets ? 0.3 : 1;
}
