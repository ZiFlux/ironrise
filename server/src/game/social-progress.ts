/**
 * Вехи героя и общая серия напарников (PLAN 4.8, п. 6 и 9).
 * Совпадает с app/lib/game/hero_milestones.dart и app/lib/game/streak_pair.dart.
 */
import { PartMap } from './body-part';
import { averageLevel } from './progression';

/** Вехи по среднему уровню героя: вещь в подарок, поза победы и аватарки. */
export interface HeroMilestone {
  level: number;
  item: string;
}

export const HERO_MILESTONES: readonly HeroMilestone[] = [
  { level: 5, item: 'acc_headband' },
  { level: 10, item: 'acc_wristbands' },
  { level: 20, item: 'acc_belt' },
];

/** Уровень героя — средний по частям тела, вниз. */
export const heroLevel = (levels: PartMap<number>): number => Math.floor(averageLevel(levels));

/** Вехи, которые пройдены после [rewarded] при уровне [level]. */
export const heroMilestonesDue = (rewarded: number, level: number): HeroMilestone[] =>
  HERO_MILESTONES.filter((m) => m.level > rewarded && m.level <= level);

/** Напарникам за неделю нужно столько тренировок каждому. */
export const PAIR_WEEKLY_WORKOUTS = 2;

const DAY = 86_400_000;

/** Понедельник недели дня (YYYY-MM-DD). */
export const mondayOfDay = (day: string): string => {
  const d = new Date(`${day}T00:00:00Z`);
  const shift = (d.getUTCDay() + 6) % 7;
  return new Date(d.getTime() - shift * DAY).toISOString().slice(0, 10);
};

const addDays = (day: string, n: number) =>
  new Date(Date.parse(`${day}T00:00:00Z`) + n * DAY).toISOString().slice(0, 10);

/**
 * Общая серия в неделях: подряд идущие недели (с [since], до текущей), где у
 * обоих не меньше PAIR_WEEKLY_WORKOUTS тренировок. Текущая неделя серию не
 * сжигает — она ещё идёт. [daysA]/[daysB] — дни тренировок, по одному на каждую.
 */
export const pairStreak = (
  daysA: readonly string[],
  daysB: readonly string[],
  since: string,
  today: string,
): { weeks: number; thisWeek: { a: number; b: number }; need: number } => {
  const count = (days: readonly string[], monday: string) => {
    const end = addDays(monday, 7);
    return days.filter((d) => d >= monday && d < end).length;
  };
  const current = mondayOfDay(today);
  const thisWeek = { a: count(daysA, current), b: count(daysB, current) };
  let weeks = 0;
  for (let w = addDays(current, -7); w >= mondayOfDay(since); w = addDays(w, -7)) {
    if (count(daysA, w) >= PAIR_WEEKLY_WORKOUTS && count(daysB, w) >= PAIR_WEEKLY_WORKOUTS) weeks++;
    else break;
  }
  // Текущая неделя уже выполнена обоими — засчитываем сразу.
  if (thisWeek.a >= PAIR_WEEKLY_WORKOUTS && thisWeek.b >= PAIR_WEEKLY_WORKOUTS) weeks++;
  return { weeks, thisWeek, need: PAIR_WEEKLY_WORKOUTS };
};
