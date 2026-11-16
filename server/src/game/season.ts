/**
 * Сезоны и батлпас. Сезон — 8 недель; за тренировки, дуэли и советы идут очки
 * сезона, каждые [SEASON_LEVEL_POINTS] — уровень (до [SEASON_MAX_LEVEL]).
 * Две дорожки наград: бесплатная и премиум. Награды выдаются сами при наборе
 * уровня; премиум, купленный посреди сезона, получает свою дорожку задним числом.
 * Совпадает с app/lib/game/season.dart.
 */

export const SEASON_WEEKS = 8;
export const SEASON_LEVEL_POINTS = 150;
export const SEASON_MAX_LEVEL = 30;

/** Начало первого сезона (понедельник). */
const FIRST_SEASON_START = Date.UTC(2026, 10, 2);
const SEASON_MS = SEASON_WEEKS * 7 * 86_400_000;

const SEASON_NAMES = ['Пробуждение', 'Закалка', 'Прорыв', 'Пик формы'];

export interface Season {
  number: number;
  name: string;
  startsAt: Date;
  endsAt: Date;
}

export const seasonAt = (now: Date): Season => {
  const n = Math.max(0, Math.floor((now.getTime() - FIRST_SEASON_START) / SEASON_MS));
  const startsAt = new Date(FIRST_SEASON_START + n * SEASON_MS);
  return {
    number: n + 1,
    name: SEASON_NAMES[n % SEASON_NAMES.length],
    startsAt,
    endsAt: new Date(startsAt.getTime() + SEASON_MS),
  };
};

export const seasonLevel = (points: number): number =>
  Math.min(SEASON_MAX_LEVEL, Math.floor(Math.max(0, points) / SEASON_LEVEL_POINTS));

/** Очки сезона: тренировка по достоверности, план — бонус, дуэли и советы — понемногу. */
export const SEASON_POINTS = {
  strength: (validity: number, planCompleted: boolean) => Math.round(100 * validity) + (planCompleted ? 20 : 0),
  cardio: (validity: number) => Math.round(60 * validity),
  duelWin: 15,
  duelLoss: 5,
  tip: 10,
} as const;

export type SeasonTrack = 'free' | 'premium';

export interface SeasonReward {
  coins: number;
  items: string[];
  boosters: { xp: number; coins: number };
}

/** Вещи сезонов: по номеру сезона, уровню и дорожке. */
export const SEASON_ITEM_TABLE: Record<number, Record<SeasonTrack, Record<number, string>>> = {
  1: {
    free: { 5: 'sn_s1', 15: 'tc_s1', 20: 'hair_wolfcut', 25: 'bc_s1' },
    premium: { 10: 'hc_s1', 20: 'sn_s1p', 25: 'acc_bucket', 30: 'tc_s1p' },
  },
  // Сезон 2 «Закалка» (с 28.12.2026): сталь и мороз, шарф.
  2: {
    free: { 5: 'sn_s2', 15: 'tc_s2', 20: 'acc_scarf', 25: 'bc_s2' },
    premium: { 10: 'hc_s2', 20: 'sn_s2p', 25: 'bc_s2p', 30: 'tc_s2p' },
  },
};

/** Все сезонные вещи: не продаются, носить можно только полученные. */
export const SEASON_ITEMS: readonly string[] = Object.values(SEASON_ITEM_TABLE).flatMap((s) =>
  [...Object.values(s.free), ...Object.values(s.premium)],
);

/** Награда уровня [level] дорожки [track] в сезоне [season]. */
export const seasonReward = (season: number, track: SeasonTrack, level: number): SeasonReward => {
  const item = SEASON_ITEM_TABLE[season]?.[track]?.[level];
  const free = track === 'free';
  return {
    coins: (free ? 15 : 10) + (level === SEASON_MAX_LEVEL ? (free ? 200 : 300) : 0),
    items: item ? [item] : [],
    boosters: {
      xp: (free && level === 20) || (!free && (level === 15 || level === 25)) ? 1 : 0,
      coins: free && level === 10 ? 1 : 0,
    },
  };
};

/** Сумма наград уровней (from, to] — то, что выдать при наборе. */
export const seasonRewardsBetween = (
  season: number,
  track: SeasonTrack,
  from: number,
  to: number,
): SeasonReward => {
  const total: SeasonReward = { coins: 0, items: [], boosters: { xp: 0, coins: 0 } };
  for (let l = from + 1; l <= to; l++) {
    const r = seasonReward(season, track, l);
    total.coins += r.coins;
    total.items.push(...r.items);
    total.boosters.xp += r.boosters.xp;
    total.boosters.coins += r.boosters.coins;
  }
  return total;
};
