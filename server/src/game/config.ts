/**
 * Игровые коэффициенты (ТЗ, раздел 4; PLAN 0). Значения по умолчанию совпадают
 * с app/lib/game/game_config.dart. Позже переедут в таблицу game_config, чтобы
 * меняться без релиза.
 */
export const GameConfig = {
  baseXpPerSet: 18,
  xpPerLevel: 100,
  laggingThreshold: 1.5,
  laggingXpMultiplier: 1.5,
  powerPenaltyUnbalanced: 0.9,
  powerBonusBalanced: 1.05,
  streakCap: 30,
  unverifiedValidity: 0.5,
  maxSetsPerExercise: 8,
  coinsPerXp: 0.2,
  /**
   * Потолок опыта за календарный день, все тренировки вместе (ТЗ 4.4).
   * Тяжёлая подтверждённая силовая даёт ~450, два часа кардио — до 720:
   * больше за день — уже перетренированность, а не прогресс.
   */
  dailyXpCap: 600,

  // Антифрод
  minSecondsPerSet: 45,
  minPulseCoverage: 0.6,
  defaultRestingHeartRate: 70,
  minPulseAboveRest: 15,
  minPulseSpread: 5,

  // Дуэли
  duelMinRounds: 6,
  duelMaxRounds: 10,
  duelMissChance: 0.2,
  duelCritChance: 0.2,
  duelCritMultiplier: 2,
  duelWinCoins: 15,
  duelLossCoins: 3,

  // Кардио
  cardioXpPerMinute: 6,
  cardioMaxMinutes: 120,
  cardioZoneReserveShare: 0.6,
  defaultMaxHeartRate: 190,
} as const;
