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
  static const int maxSetsPerExercise = 4;

  /// Монет за единицу опыта.
  static const double coinsPerXp = 0.2;

  /// Бонус монет за тренировку, выполненную по плану программы.
  static const double planCoinBonus = 0.2;

  /// Совместная тренировка: +25% опыта и монет каждому (как на сервере).
  static const double jointBonus = 0.25;
  static const int jointSessionHours = 4;

  /// Монеты за создание аккаунта (сервер начисляет один раз).
  static const int welcomeCoins = 100;

  /// Премиум: +25% монет за тренировку (как на сервере).
  static const double premiumCoinBonus = 0.25;

  /// Монеты за правильный ответ на вопрос «Совета дня», раз в день.
  static const int tipCoins = 10;

  /// Советы дня: монеты за каждый верный ответ и бонус за все верные (как на сервере).
  static const int tipCoinsPerAnswer = 4;
  static const int tipQuizBonus = 10;

  // ---- Антифрод (ТЗ 4.4). Пороги калибруются на реальных данных беты. ----

  /// Быстрее этого подходы физически не делаются.
  static const Duration minTimePerSet = Duration(seconds: 45);

  /// Какая доля тренировки должна быть покрыта пульсом, чтобы он считался.
  static const double minPulseCoverage = 0.6;

  /// Пульс покоя по умолчанию, пока пользователь не указал свой.
  static const int defaultRestingHeartRate = 70;

  /// Насколько средний пульс тренировки должен быть выше пульса покоя.
  static const int minPulseAboveRest = 15;

  /// Минимальный разброс пульса: без циклов «подход — отдых» пульс ровный.
  static const double minPulseSpread = 5;

  /// Отдых между подходами по умолчанию.
  static const Duration restBetweenSets = Duration(seconds: 90);

  // ---- Дуэли (ТЗ 4.5). Шансы проверяются Монте-Карло в test/duel_test.dart. ----

  static const int duelMinRounds = 6;
  static const int duelMaxRounds = 10;
  static const double duelMissChance = 0.2;
  static const double duelCritChance = 0.2;
  static const double duelCritMultiplier = 2;

  /// Шанс события перед ударом, усиление удара и лечение (доля здоровья) — как на сервере.
  static const double duelEventChance = 0.12;
  static const double duelBoostMultiplier = 1.5;
  static const double duelHealMin = 0.05;
  static const double duelHealMax = 0.09;

  /// Монеты за дуэль с ботом.
  static const int duelWinCoins = 15;

  /// С тем же ботом — снова через столько часов (как на сервере).
  static const duelCooldown = Duration(hours: 5);

  /// Повторный бой с ботом за те же сутки — такая доля монет.
  static const double duelRepeatCoinFactor = 0.5;
  static const int duelLossCoins = 3;

  // ---- Кардио (PLAN 4.1). 30 минут бега ≈ одна силовая тренировка. ----

  static const int cardioXpPerMinute = 6;
  static const int cardioMaxMinutes = 120;

  /// Зона 2 начинается с этой доли резерва пульса (Карвонен).
  static const double cardioZoneReserveShare = 0.6;

  /// Максимальный пульс, пока не знаем возраст (220 − 30).
  static const int defaultMaxHeartRate = 190;

  /// Очки недельной лиги.
  static const int leagueWorkoutPoints = 10;
  static const int leagueWinPoints = 3;
}
