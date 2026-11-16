/**
 * Лиги с повышением и понижением (PLAN.md, раздел 4.8).
 * Неделя: игрок и боты своей лиги. В конце недели первые двое поднимаются,
 * последние двое опускаются. Неделя без тренировок — минус лига, но уровни
 * героя не трогаем: теряется только место в лигах.
 */

export const LEAGUE_TIERS = ['Бронзовая', 'Серебряная', 'Золотая', 'Платиновая', 'Алмазная', 'Чемпионская'] as const;
export const TOP_TIER = LEAGUE_TIERS.length - 1;
export const PROMOTE_TOP = 2;
export const DEMOTE_BOTTOM = 2;

/**
 * Чем выше лига, тем труднее подняться (п. 108): с золотой — только первое место,
 * с платиновой — ещё и не меньше 3 тренировочных дней за неделю.
 */
export const promoteTopFor = (tier: number): number => (tier >= 2 ? 1 : PROMOTE_TOP);
export const minTrainedDaysToPromote = (tier: number): number => (tier >= 3 ? 3 : 1);

export type WeekOutcome = 'up' | 'stay' | 'down';

export interface WeekSettlement {
  week: string;
  rank: number;
  outcome: WeekOutcome;
  tierBefore: number;
  tierAfter: number;
}

export const weekOutcome = (rank: number, size: number, trainedDays: number, tier = 0): WeekOutcome => {
  if (trainedDays === 0) return 'down';
  if (rank <= promoteTopFor(tier) && trainedDays >= minTrainedDaysToPromote(tier)) return 'up';
  if (rank > size - DEMOTE_BOTTOM) return 'down';
  return 'stay';
};

export const tierAfter = (tier: number, outcome: WeekOutcome): number => {
  const next = tier + (outcome === 'up' ? 1 : outcome === 'down' ? -1 : 0);
  return Math.min(TOP_TIER, Math.max(0, next));
};

/** Итог недели по месту игрока в таблице (rank с 1). */
export const settleWeek = (args: {
  week: string;
  tier: number;
  rank: number;
  size: number;
  trainedDays: number;
}): WeekSettlement => {
  const outcome = weekOutcome(args.rank, args.size, args.trainedDays, args.tier);
  return { week: args.week, rank: args.rank, outcome, tierBefore: args.tier, tierAfter: tierAfter(args.tier, outcome) };
};

/** Понедельник через n недель. */
export const addWeeks = (monday: string, n: number): string =>
  new Date(new Date(`${monday}T00:00:00Z`).getTime() + n * 7 * 86_400_000).toISOString().slice(0, 10);

/** Воскресенье недели, начинающейся с понедельника monday. */
export const sundayOf = (monday: string): string =>
  new Date(new Date(`${monday}T00:00:00Z`).getTime() + 6 * 86_400_000).toISOString().slice(0, 10);

/** Боты в лиге выше тренируются чаще: чем выше лига, тем труднее подняться. */
export const botActivityBase = (tier: number): number => 0.25 + 0.1 * tier;
