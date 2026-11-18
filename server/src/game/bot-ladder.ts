/**
 * Лестница ботов (п. 88): 13 ступеней с абсолютной силой — сначала у всех слабые
 * соперники, выше — всё сильнее. На ступени 4 бота и босс: побил [BOSS_UNLOCK_WINS]
 * ботов — открыт босс, побил босса — следующая ступень. Сила героя растёт только от
 * тренировок, поэтому лестница — ещё и счётчик прогресса.
 * Ступени рассчитаны на рост ~0,75 уровня части за силовую: при 3 тренировках в неделю
 * средний уровень ~10 через месяц и ~30 через 3–4 месяца.
 */
import { AURA_KINDS, AuraKind } from './aura';
import { BODY_PARTS } from './body-part';
import { GameConfig as C } from './config';
import { seededRandom } from './duel';
import { botNames } from './duel-flavor';
import { randomBotLook } from './looks';
import type { Bot } from './bots';

export interface LadderTier {
  name: string;
  /** Средний уровень части у ботов ступени. */
  level: number;
  boss: { name: string; isFemale: boolean };
}

/** Боссы — пародийные отсылки, без настоящих имён (правило проекта). */
export const LADDER: readonly LadderTier[] = [
  { name: 'Турник во дворе', level: 1, boss: { name: 'Дядя Вася с турника', isFemale: false } },
  { name: 'Школьный стадион', level: 2, boss: { name: 'Физрук Палыч', isFemale: false } },
  { name: 'Подвальная качалка', level: 3, boss: { name: 'Гоша-Протеин', isFemale: false } },
  { name: 'Фитнес у дома', level: 4, boss: { name: 'Кристи Шейпинг', isFemale: true } },
  { name: 'Районный зал', level: 6, boss: { name: 'Ронни-Бетономешалка', isFemale: false } },
  { name: 'Секция пауэрлифтинга', level: 8, boss: { name: 'Тётя Валя-Становая', isFemale: true } },
  { name: 'Городской турнир', level: 10, boss: { name: 'Дориан Ятсенко', isFemale: false } },
  { name: 'Областной чемпионат', level: 13, boss: { name: 'Северная Гора', isFemale: false } },
  { name: 'Сборы', level: 16, boss: { name: 'Брайан Шкаф', isFemale: false } },
  { name: 'Национальный кубок', level: 20, boss: { name: 'Кай Зелёный', isFemale: false } },
  { name: 'Мировая лига', level: 25, boss: { name: 'Джей Кастет', isFemale: false } },
  { name: 'Олимп', level: 30, boss: { name: 'Флекс Колесо', isFemale: false } },
  { name: 'Вершина', level: 36, boss: { name: 'Мистер Олимп', isFemale: false } },
];

export const LADDER_BOTS = 4;
/** Побед над ботами ступени, чтобы открыть босса. */
export const BOSS_UNLOCK_WINS = 3;
/** Боты ступени: от слабого к сильному, босс — сильнее всех. */
const RATIOS = [0.75, 0.9, 1.0, 1.1];
const BOSS_RATIO = 1.25;
/** Повторная победа над уже побеждённым — такая доля монет (п. 88). */
export const LADDER_REPEAT_FACTOR = 0.2;

export const ladderBotId = (tier: number, i: number) => `lad_${tier}_${i}`;
export const ladderBossId = (tier: number) => `lad_${tier}_boss`;
export const isBossId = (id: string) => id.endsWith('_boss');

export const clampTier = (tier: number) => Math.max(0, Math.min(LADDER.length - 1, Math.floor(tier)));

/** Уровни бота: от среднего уровня ступени, с разбросом; у некоторых одна часть отстаёт. */
const levelsFor = (avg: number, rnd: () => number, lagging: boolean) => {
  const levels = Object.fromEntries(
    BODY_PARTS.map((p) => [p, Math.max(1, Math.round(avg * (0.85 + rnd() * 0.3)))]),
  ) as Bot['levels'];
  if (lagging && avg >= 3) {
    const part = BODY_PARTS[Math.floor(rnd() * BODY_PARTS.length)];
    levels[part] = Math.max(1, Math.round(avg - C.laggingThreshold - 1));
  }
  return levels;
};

/** Уровень ауры ботов ступени: 1 внизу, 5 у вершины. */
export const ladderAuraLevel = (tier: number) => Math.min(5, 1 + Math.floor(tier / 3));

/**
 * Ауры ботов (п. 79): со 2-й ступени — у двух сильных ботов, у босса — всегда.
 * Своё зерно, чтобы не менять имена, образы и уровни уже знакомых ботов.
 */
const ladderAuras = (tier: number): { bots: (AuraKind | null)[]; boss: AuraKind | null } => {
  const rnd = seededRandom(5000 + tier * 131);
  const kind = () => AURA_KINDS[Math.floor(rnd() * AURA_KINDS.length)];
  return {
    bots: RATIOS.map((_, i) => (tier >= 1 && i >= 2 ? kind() : null)),
    boss: tier >= 1 ? kind() : null,
  };
};

/** Боты и босс ступени — одни и те же у всех игроков (зерно — номер ступени). */
export const ladderTier = (tierIndex: number): { tier: number; name: string; bots: Bot[]; boss: Bot } => {
  const tier = clampTier(tierIndex);
  const t = LADDER[tier];
  const rnd = seededRandom(1000 + tier * 97);
  const female = RATIOS.map(() => rnd() < 0.5);
  const names = botNames(female, rnd);
  const bots: Bot[] = RATIOS.map((ratio, i) => ({
    id: ladderBotId(tier, i),
    name: names[i],
    isFemale: female[i],
    appearance: randomBotLook(female[i], rnd),
    levels: levelsFor(t.level * ratio, rnd, i % 2 === 1),
    streakDays: Math.min(C.streakCap, tier * 2),
  }));
  const auras = ladderAuras(tier);
  bots.forEach((b, i) => {
    const kind = auras.bots[i];
    if (kind) b.aura = { kind, level: ladderAuraLevel(tier) };
  });
  const boss: Bot = {
    id: ladderBossId(tier),
    name: t.boss.name,
    isFemale: t.boss.isFemale,
    appearance: randomBotLook(t.boss.isFemale, rnd),
    levels: levelsFor(t.level * BOSS_RATIO, rnd, false),
    streakDays: Math.min(C.streakCap, tier * 3),
    ...(auras.boss ? { aura: { kind: auras.boss, level: ladderAuraLevel(tier) } } : {}),
  };
  return { tier, name: t.name, bots, boss };
};

/** Сколько ботов ступени уже побеждено (босс не в счёт). */
export const tierWins = (tier: number, beaten: readonly string[]) =>
  Array.from({ length: LADDER_BOTS }, (_, i) => ladderBotId(tier, i)).filter((id) => beaten.includes(id)).length;

export const bossUnlocked = (tier: number, beaten: readonly string[]) => tierWins(tier, beaten) >= BOSS_UNLOCK_WINS;

/** Монеты за бой на ступени: выше — щедрее; повторная победа — 20 %; босс — бонус. */
export const ladderCoins = (args: { tier: number; won: boolean; firstWin: boolean; boss: boolean }) => {
  const scale = 1 + 0.15 * args.tier;
  if (!args.won) return Math.round(C.duelLossCoins * scale);
  const base = C.duelWinCoins * scale * (args.boss ? 3 : 1);
  return Math.round(args.firstWin ? base : base * LADDER_REPEAT_FACTOR);
};

/** Разбор побеждённых из профиля: только id лестницы, без мусора. */
export const readBeaten = (raw: unknown): string[] =>
  Array.isArray(raw) ? raw.filter((x): x is string => typeof x === 'string' && x.startsWith('lad_')).slice(0, 200) : [];
