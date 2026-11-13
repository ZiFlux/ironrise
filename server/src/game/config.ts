/**
 * Игровые коэффициенты (ТЗ, раздел 4; PLAN 0). Значения по умолчанию совпадают
 * с app/lib/game/game_config.dart. Позже переедут в таблицу game_config, чтобы
 * меняться без релиза.
 */
export const GameConfig = {
  /** Шаги в день отдыха: опыт кардио за каждую тысячу и потолок за день. */
  stepsXpPerThousand: 3,
  stepsXpCap: 30,
  /** С тем же ботом — снова через столько часов. */
  duelCooldownHours: 5,
  /** Повторный бой с ботом за те же сутки — такая доля монет. */
  duelRepeatCoinFactor: 0.5,
  baseXpPerSet: 18,
  xpPerLevel: 100,
  laggingThreshold: 1.5,
  laggingXpMultiplier: 1.5,
  powerPenaltyUnbalanced: 0.9,
  powerBonusBalanced: 1.05,
  streakCap: 30,
  unverifiedValidity: 0.5,
  maxSetsPerExercise: 4,
  coinsPerXp: 0.2,
  /**
   * Потолок опыта за календарный день, все тренировки вместе (ТЗ 4.4).
   * Тяжёлая подтверждённая силовая даёт ~450, два часа кардио — до 720:
   * больше за день — уже перетренированность, а не прогресс.
   */
  dailyXpCap: 600,
  /** Бонус монет за тренировку, выполненную по плану программы (docs/TRAINING_SYSTEM.md, 7). */
  planCoinBonus: 0.2,
  /** Монеты за правильный ответ на вопрос «Совета дня», раз в день. */
  tipCoins: 10,
  /** Советы дня: монеты за каждый верный ответ подборки и бонус, если верны все. */
  tipCoinsPerAnswer: 4,
  tipQuizBonus: 10,
  /** Больше советов в подборке не бывает. */
  tipsPerDayMax: 5,
  /** Монеты за создание аккаунта — один раз. */
  welcomeCoins: 100,
  /** Премиум: +25% монет за тренировку (косметика, на силу не влияет). */
  premiumCoinBonus: 0.25,

  // Совместная тренировка (ТЗ 3.2): вместе в одно время и в одном месте.
  /** +25% опыта и монет каждому участнику. Дневной потолок опыта действует как обычно. */
  jointBonus: 0.25,
  /** Код для подключения живёт 15 минут: его вводят, стоя рядом. */
  jointCodeMinutes: 15,
  /** Тренировки в течение 4 часов после создания засчитываются как совместные. */
  jointSessionHours: 4,
  jointMaxMembers: 5,

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
  /** Шанс случайного события перед ударом (креатин, селфи у зеркала…). */
  duelEventChance: 0.12,
  /** Удар под предтреном и т. п. */
  duelBoostMultiplier: 1.5,
  /** Лечение событием — доля от полного здоровья. */
  duelHealMin: 0.05,
  duelHealMax: 0.09,
  duelWinCoins: 15,
  duelLossCoins: 3,

  // Кардио
  cardioXpPerMinute: 6,
  cardioMaxMinutes: 120,
  cardioZoneReserveShare: 0.6,
  defaultMaxHeartRate: 190,
} as const;
