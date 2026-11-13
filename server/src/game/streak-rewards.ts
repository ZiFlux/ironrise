/**
 * Награды за серию (п. 37 бэклога). Совпадает с app/lib/game/streak_rewards.dart.
 * Каждое продление серии — немного монет, рубежи — крупные награды: монеты,
 * опыт отстающей части, бустеры на следующую тренировку и вещи «за серию».
 */
import { BodyPart, PartMap } from './body-part';
import { WorkoutSummary, buildSummary } from './workout';

/** Бустеры на следующую тренировку: опыт ×1,5 и монеты ×2. Сколько штук. */
export interface Boosters {
  xp: number;
  coins: number;
}

export interface StreakMilestone {
  day: number;
  coins: number;
  /** Опыт отстающей части тела. */
  xp?: number;
  boosters?: Partial<Boosters>;
  /** Вещь «за серию»: не продаётся, выдаётся навсегда. */
  item?: string;
}

export const XP_BOOST = 1.5;
export const COIN_BOOST = 2;

export const STREAK_MILESTONES: readonly StreakMilestone[] = [
  { day: 3, coins: 20 },
  { day: 5, coins: 30, boosters: { xp: 1 } },
  { day: 7, coins: 50, item: 'sn_streak' },
  { day: 10, coins: 60, boosters: { coins: 1 } },
  { day: 14, coins: 80, xp: 100 },
  { day: 21, coins: 100, item: 'tc_streak' },
  { day: 30, coins: 150, item: 'bc_streak', boosters: { xp: 1, coins: 1 } },
  { day: 45, coins: 200, xp: 200 },
  { day: 60, coins: 250, item: 'hc_streak' },
];

/** Вещи за серию — эксклюзивы, в продаже их нет. */
export const STREAK_ITEMS: readonly string[] = ['sn_streak', 'tc_streak', 'bc_streak', 'hc_streak'];

/** После 60 дней — рубеж каждые 30 дней. */
export const milestoneFor = (day: number): StreakMilestone | undefined =>
  STREAK_MILESTONES.find((m) => m.day === day) ??
  (day > 60 && day % 30 === 0 ? { day, coins: 250, xp: 200, boosters: { xp: 1, coins: 1 } } : undefined);

/** Монеты за каждое продление: чем длиннее серия, тем больше (до 10). */
export const dailyStreakCoins = (streak: number): number => Math.min(10, 2 + Math.floor(streak / 3));

export interface StreakReward {
  streak: number;
  coins: number;
  xp: number;
  boosters: Boosters;
  items: string[];
  milestones: number[];
}

/** Награда за рост серии с [before] до [after]: все пройденные рубежи и монеты за продление. */
export const streakReward = (before: number, after: number): StreakReward | null => {
  if (after <= before) return null;
  const reward: StreakReward = {
    streak: after,
    coins: dailyStreakCoins(after),
    xp: 0,
    boosters: { xp: 0, coins: 0 },
    items: [],
    milestones: [],
  };
  for (let d = before + 1; d <= after; d++) {
    const m = milestoneFor(d);
    if (!m) continue;
    reward.milestones.push(d);
    reward.coins += m.coins;
    reward.xp += m.xp ?? 0;
    reward.boosters.xp += m.boosters?.xp ?? 0;
    reward.boosters.coins += m.boosters?.coins ?? 0;
    if (m.item) reward.items.push(m.item);
  }
  return reward;
};

export const readBoosters = (raw: unknown): Boosters => {
  const j = (raw ?? {}) as Partial<Record<keyof Boosters, unknown>>;
  const n = (v: unknown) => (typeof v === 'number' && v > 0 ? Math.floor(v) : 0);
  return { xp: n(j.xp), coins: n(j.coins) };
};

/** Квест возвращения: серия сгорела — первая тренировка после перерыва даёт +25% опыта. */
export const COMEBACK_XP = 1.25;

/** Бустер опыта ×1,5 и/или возвращение ×1,25 (до дневного потолка — его применяют после). */
export const withXpBoost = <T extends WorkoutSummary>(
  summary: T,
  xpBefore: PartMap<number>,
  on: boolean,
  comeback = false,
): T => {
  const factor = (on ? XP_BOOST : 1) * (comeback ? COMEBACK_XP : 1);
  if (factor === 1 || summary.gains.length === 0) return summary;
  const earned: Partial<Record<BodyPart, number>> = {};
  for (const g of summary.gains) earned[g.part] = Math.round(g.xp * factor);
  const lagging = new Set(summary.gains.filter((g) => g.wasLagging).map((g) => g.part));
  const rebuilt = buildSummary(earned, xpBefore, lagging, summary);
  return { ...summary, gains: rebuilt.gains, coins: rebuilt.coins };
};

/** Бустер монет: ×2 к монетам за тренировку. */
export const withCoinBoost = <T extends WorkoutSummary>(summary: T, on: boolean): T =>
  on ? { ...summary, coins: Math.round(summary.coins * COIN_BOOST) } : summary;

/** Сколько монет за продление в этот день — для подсказки «завтра +N». */
export const nextStreakCoins = (streak: number): number => {
  const next = streak + 1;
  return dailyStreakCoins(next) + (milestoneFor(next)?.coins ?? 0);
};
