import 'dart:math';

import 'anti_fraud.dart';
import 'body_part.dart';
import 'game_config.dart';
import 'progression.dart';
import 'workout.dart';

enum CardioActivity {
  run('Бег'),
  walk('Быстрая ходьба'),
  bike('Велосипед'),
  elliptical('Эллипс'),
  other('Другое'),

  /// День восстановления «Минимума»: кардио + растяжка (экран recovery_screen.dart).
  recovery('Восстановление');

  const CardioActivity(this.label);
  final String label;
}

class CardioSession {
  const CardioSession({required this.startedAt, required this.activity});

  final DateTime startedAt;
  final CardioActivity activity;

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'activity': activity.name,
  };

  factory CardioSession.fromJson(Map<String, dynamic> j) => CardioSession(
    startedAt: DateTime.parse(j['startedAt']),
    activity: CardioActivity.values.byName(j['activity']),
  );
}

/// Опыт кардио (PLAN 4.1): XP = k_cardio · минуты.
/// С пульсом: минуты в зоне 2+ (Карвонен) идут полностью, ниже зоны — наполовину.
/// Без пульса: все минуты с V = 0,5. Так часы никогда не уменьшают опыт.
class CardioScoring {
  const CardioScoring._();

  /// Нижняя граница зоны 2: пульс покоя + 60% резерва пульса.
  static int zoneLowerBound({
    int resting = GameConfig.defaultRestingHeartRate,
    int max = GameConfig.defaultMaxHeartRate,
  }) => (resting + GameConfig.cardioZoneReserveShare * (max - resting)).round();

  /// Время в зоне по замерам пульса. Пропуски в данных длиннее 15 с не считаются.
  static Duration timeInZone(List<PulseSample> pulse, int lowerBound) {
    var seconds = 0;
    for (var i = 1; i < pulse.length; i++) {
      final gap = pulse[i].at.difference(pulse[i - 1].at).inSeconds;
      if (pulse[i - 1].bpm >= lowerBound) seconds += min(gap, 15);
    }
    return Duration(seconds: seconds);
  }

  static bool hasEnoughPulse(List<PulseSample> pulse, Duration duration) {
    if (pulse.length < 2 || duration.inSeconds == 0) return false;
    final covered = pulse.last.at.difference(pulse.first.at);
    return covered.inSeconds / duration.inSeconds >=
        GameConfig.minPulseCoverage;
  }

  static WorkoutSummary summarize({
    required CardioSession session,
    required List<PulseSample> pulse,
    required Map<BodyPart, int> xpBefore,
    required DateTime finishedAt,
    int restingHeartRate = GameConfig.defaultRestingHeartRate,
    int maxHeartRate = GameConfig.defaultMaxHeartRate,
    double unverified = GameConfig.unverifiedValidity,

    /// Личная норма вида (с сервера); нет — общий порог зоны 2.
    int? zoneBound,
  }) {
    final duration = finishedAt.difference(session.startedAt);
    final totalMin = min(
      duration.inSeconds / 60,
      GameConfig.cardioMaxMinutes.toDouble(),
    );
    final verified = hasEnoughPulse(pulse, duration);
    final zoneMin = verified
        ? min(
            timeInZone(
                  pulse,
                  zoneBound ??
                      zoneLowerBound(
                        resting: restingHeartRate,
                        max: maxHeartRate,
                      ),
                ).inSeconds /
                60,
            totalMin,
          )
        : 0.0;
    final effectiveMin = verified
        ? zoneMin + (totalMin - zoneMin) * GameConfig.unverifiedValidity
        : totalMin * unverified;

    final levelsBefore = Progression.levels(xpBefore);
    final lagging = Progression.laggingParts(levelsBefore)
        .contains(BodyPart.cardio);
    final bonus = lagging ? GameConfig.laggingXpMultiplier : 1.0;
    final xp = (GameConfig.cardioXpPerMinute * effectiveMin * bonus).round();
    final before = xpBefore[BodyPart.cardio] ?? 0;

    return WorkoutSummary(
      duration: duration,
      totalSets: 0,
      gains: [
        if (xp > 0)
          PartGain(
            part: BodyPart.cardio,
            xp: xp,
            levelBefore: levelsBefore[BodyPart.cardio]!,
            levelAfter: Progression.levelFromXp(before + xp),
            xpAfter: before + xp,
            wasLagging: lagging,
          ),
      ],
      coins: (xp * GameConfig.coinsPerXp).round(),
      validity: verified ? 1 : unverified,
      cardio: (activity: session.activity.label, zoneMinutes: zoneMin.round()),
    );
  }
}
