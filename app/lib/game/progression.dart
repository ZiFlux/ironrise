import 'dart:math';

import 'body_part.dart';
import 'game_config.dart';

/// Чистые функции прогрессии (ТЗ, разделы 4.1, 4.2, 4.5).
/// Позже та же логика будет на сервере, клиент только показывает результат.
class Progression {
  const Progression._();

  static int levelFromXp(int xp) => xp ~/ GameConfig.xpPerLevel + 1;

  /// Доля пути до следующего уровня, 0..1.
  static double levelProgress(int xp) =>
      (xp % GameConfig.xpPerLevel) / GameConfig.xpPerLevel;

  /// Уровень с дробной частью по опыту (3,4 — уровень 3 и 40% до четвёртого).
  /// Аватар растёт по нему плавно, а не скачком на новом уровне.
  static double fractionalLevel(int xp) => 1 + xp / GameConfig.xpPerLevel;

  static Map<BodyPart, double> fractionalLevels(Map<BodyPart, int> xp) => {
    for (final p in BodyPart.values) p: fractionalLevel(xp[p] ?? 0),
  };

  static Map<BodyPart, int> levels(Map<BodyPart, int> xp) => {
    for (final p in BodyPart.values) p: levelFromXp(xp[p] ?? 0),
  };

  static double averageLevel(Map<BodyPart, int> levels) =>
      levels.values.fold<int>(0, (a, b) => a + b) / levels.length;

  /// Отстающие части: уровень ниже среднего больше чем на порог.
  static List<BodyPart> laggingParts(Map<BodyPart, int> levels) {
    final avg = averageLevel(levels);
    return [
      for (final e in levels.entries)
        if (e.value < avg - GameConfig.laggingThreshold) e.key,
    ]..sort((a, b) => levels[a]!.compareTo(levels[b]!));
  }

  static double balanceMultiplier(Map<BodyPart, int> levels) =>
      laggingParts(levels).isEmpty
      ? GameConfig.powerBonusBalanced
      : GameConfig.powerPenaltyUnbalanced;

  /// Сила аватара: P = (10·ΣL + 2·min(S, 30)) · K_bal.
  static int power(Map<BodyPart, int> levels, int streakDays) {
    final sum = levels.values.fold<int>(0, (a, b) => a + b);
    final raw = 10 * sum + 2 * min(streakDays, GameConfig.streakCap);
    return (raw * balanceMultiplier(levels)).round();
  }

  /// Опыт части тела за один подход: XP = k_base · d · B · V.
  static double xpForSet({
    required double share,
    required bool isLagging,
    required double validity,
  }) {
    final b = isLagging ? GameConfig.laggingXpMultiplier : 1.0;
    return GameConfig.baseXpPerSet * share * b * validity;
  }
}
