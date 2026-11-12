import { BODY_PARTS, PartMap } from './body-part';
import { botActivityBase } from './league';
import { GameConfig as C } from './config';
import { FighterSnapshot, seededRandom } from './duel';
import { averageLevel } from './progression';
import { botNames } from './duel-flavor';
import { randomBotLook } from './looks';
import { daysBetween } from './streak';

/** Соперники от слабого к сильному относительно уровней игрока. */
const RATIOS = [0.8, 0.95, 1.05, 1.2];

const daySeed = (day: string): number => Number(day.replaceAll('-', ''));

export interface Bot extends FighterSnapshot {
  isFemale: boolean;
  /** Случайный образ из вещей магазина (формат AvatarLook.toJson). */
  appearance: Record<string, unknown>;
}

/**
 * Боты дня (порт DuelBots из клиента): набор меняется раз в день и подстраивается
 * под уровни игрока; у половины одна часть отстаёт, чтобы было видно цену перекоса.
 */
export const botsForDay = (player: { levels: PartMap<number>; streakDays: number }, day: string): Bot[] => {
  const seed = daySeed(day);
  const rnd = seededRandom(seed);
  const female = RATIOS.map(() => rnd() < 0.5);
  const names = botNames(female, rnd);
  return RATIOS.map((ratio, i) => {
    const levels = { ...player.levels };
    for (const p of BODY_PARTS) levels[p] = Math.max(1, Math.round(player.levels[p] * ratio + rnd() - 0.5));
    const isFemale = female[i];
    if (i % 2 === 1) {
      const part = BODY_PARTS[Math.floor(rnd() * BODY_PARTS.length)];
      const weak = Math.floor(averageLevel(levels) - C.laggingThreshold - 1);
      if (weak >= 1) {
        const lost = levels[part] - weak;
        levels[part] = weak;
        const others = BODY_PARTS.filter((p) => p !== part);
        for (let k = 0; k < lost; k++) levels[others[k % others.length]] += 1;
      }
    }
    return {
      id: `bot_${seed}_${i}`,
      name: names[i],
      isFemale,
      appearance: randomBotLook(isFemale, rnd),
      levels,
      streakDays: player.streakDays,
    };
  });
};

export interface LeagueEntry {
  name: string;
  points: number;
  isPlayer: boolean;
}

export const LEAGUE_WORKOUT_POINTS = 10;
export const LEAGUE_WIN_POINTS = 3;
const BOTS_IN_LEAGUE = 7;

/** Понедельник недели дня YYYY-MM-DD. */
export const mondayOf = (day: string): string => {
  const d = new Date(`${day}T00:00:00Z`);
  const shift = (d.getUTCDay() + 6) % 7; // Пн = 0
  return new Date(d.getTime() - shift * 86_400_000).toISOString().slice(0, 10);
};

/** Недельная лига: игрок и боты, очки за активность (тренировка +10, победа +3). */
export const weeklyLeague = (args: {
  today: string;
  playerName: string;
  playerPoints: number;
  /** Лига игрока: в старших боты тренируются чаще. */
  tier?: number;
}): LeagueEntry[] => {
  const monday = mondayOf(args.today);
  const weekSeed = daySeed(monday);
  const daysPassed = daysBetween(monday, args.today) + 1;
  const nameRnd = seededRandom(weekSeed);
  const names = botNames(Array.from({ length: BOTS_IN_LEAGUE }, () => nameRnd() < 0.5), nameRnd);
  const entries: LeagueEntry[] = [{ name: args.playerName, points: args.playerPoints, isPlayer: true }];
  for (let b = 0; b < BOTS_IN_LEAGUE; b++) {
    const rnd = seededRandom(weekSeed * 31 + b);
    const activity = botActivityBase(args.tier ?? 0) + rnd() * 0.55;
    let points = 0;
    for (let d = 0; d < 7; d++) {
      const trained = rnd() < activity;
      const wins = Math.floor(rnd() * 3);
      if (d < daysPassed) points += (trained ? LEAGUE_WORKOUT_POINTS : 0) + wins * LEAGUE_WIN_POINTS;
    }
    entries.push({ name: names[b], points, isPlayer: false });
  }
  // При равенстве игрок выше: его очки заработаны по-настоящему.
  return entries.sort((a, b) => b.points - a.points || Number(b.isPlayer) - Number(a.isPlayer));
};
