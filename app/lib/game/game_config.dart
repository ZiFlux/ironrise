/// Игровые коэффициенты (ТЗ, раздел 4). В продукте будут приходить с сервера.
class GameConfig {
  const GameConfig._();

  /// Базовый опыт за подход (k_base).
  static const int baseXpPerSet = 18;

  /// Опыта на один уровень части тела.
  static const int xpPerLevel = 100;

  /// Насколько уровень части должен быть ниже среднего, чтобы она считалась отстающей.
  static const double laggingThreshold = 1.5;

  /// Множитель опыта для отстающей части (B).
  static const double laggingXpMultiplier = 1.5;

  /// K_bal: при перекосе и при балансе.
  static const double powerPenaltyUnbalanced = 0.9;
  static const double powerBonusBalanced = 1.05;

  /// Максимальный вклад серии в силу, дней.
  static const int streakCap = 30;

  /// Коэффициент достоверности V для тренировки без данных часов (ТЗ 4.4).
  static const double unverifiedValidity = 0.5;

  /// Подходов на одно упражнение сверх этого не засчитываются (антифрод).
  static const int maxSetsPerExercise = 8;

  /// Монет за единицу опыта.
  static const double coinsPerXp = 0.2;

  /// Отдых между подходами по умолчанию.
  static const Duration restBetweenSets = Duration(seconds: 90);
}
