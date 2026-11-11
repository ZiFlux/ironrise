import { BODY_PARTS, BodyPart, PartMap } from './body-part';
import { GameConfig as C } from './config';
import { findExercise } from './exercises';
import { laggingParts, levelFromXp, levels, xpForSet } from './progression';

export interface SetInput {
  weight: number;
  /** Повторы или секунды. */
  reps: number;
}

export interface EntryInput {
  exerciseId: string;
  sets: SetInput[];
}

export interface StrengthSession {
  startedAt: Date;
  finishedAt: Date;
  entries: EntryInput[];
}

export interface PartGain {
  part: BodyPart;
  xp: number;
  levelBefore: number;
  levelAfter: number;
  xpAfter: number;
  wasLagging: boolean;
}

export interface WorkoutSummary {
  durationSec: number;
  totalSets: number;
  /** Только части с опытом, по убыванию. */
  gains: PartGain[];
  coins: number;
  validity: number;
  /** Сколько опыта срезал дневной потолок; нет поля — не срезал. */
  cappedXp?: number;
}

export const totalSets = (s: StrengthSession): number =>
  s.entries.reduce((n, e) => n + e.sets.length, 0);

export class UnknownExerciseError extends Error {
  constructor(readonly exerciseId: string) {
    super(`Unknown exercise: ${exerciseId}`);
  }
}

/** Собрать итог из уже посчитанного опыта по частям. Общее для силовой и кардио. */
export const buildSummary = (
  earned: Partial<Record<BodyPart, number>>,
  xpBefore: PartMap<number>,
  lagging: ReadonlySet<BodyPart>,
  meta: { durationSec: number; totalSets: number; validity: number },
): WorkoutSummary => {
  const lv = levels(xpBefore);
  const gains: PartGain[] = BODY_PARTS.flatMap((part) => {
    const xp = Math.round(earned[part] ?? 0);
    if (xp <= 0) return [];
    const xpAfter = xpBefore[part] + xp;
    return [{
      part,
      xp,
      levelBefore: lv[part],
      levelAfter: levelFromXp(xpAfter),
      xpAfter,
      wasLagging: lagging.has(part),
    }];
  }).sort((a, b) => b.xp - a.xp);
  const totalXp = gains.reduce((s, g) => s + g.xp, 0);
  return { ...meta, gains, coins: Math.round(totalXp * C.coinsPerXp) };
};

/**
 * Перевод подходов в опыт: XP = k_base · d · B · V (ТЗ 4.1).
 * Отстающие части — по уровням на начало тренировки. Сверх 8 подходов на упражнение не считается.
 */
export const scoreStrength = (
  session: StrengthSession,
  xpBefore: PartMap<number>,
  validity: number,
): WorkoutSummary => {
  const lagging = new Set(laggingParts(levels(xpBefore)));
  const earned: Partial<Record<BodyPart, number>> = {};
  for (const entry of session.entries) {
    const exercise = findExercise(entry.exerciseId);
    if (!exercise) throw new UnknownExerciseError(entry.exerciseId);
    const counted = Math.min(entry.sets.length, C.maxSetsPerExercise);
    for (const [part, share] of Object.entries(exercise.shares) as [BodyPart, number][]) {
      earned[part] = (earned[part] ?? 0) + xpForSet(share, lagging.has(part), validity) * counted;
    }
  }
  return buildSummary(earned, xpBefore, lagging, {
    durationSec: Math.round((session.finishedAt.getTime() - session.startedAt.getTime()) / 1000),
    totalSets: totalSets(session),
    validity,
  });
};

/**
 * Дневной потолок опыта (ТЗ 4.4): если с учётом уже набранного за день опыт
 * превышает потолок, все части тела получают пропорционально меньше.
 */
export const applyDailyCap = <T extends WorkoutSummary>(
  summary: T,
  xpBefore: PartMap<number>,
  xpEarnedToday: number,
  cap: number = C.dailyXpCap,
): T => {
  const total = summary.gains.reduce((s, g) => s + g.xp, 0);
  const allowed = Math.max(0, cap - xpEarnedToday);
  if (total <= allowed) return summary;
  const factor = allowed / total;
  const earned: Partial<Record<BodyPart, number>> = {};
  for (const g of summary.gains) earned[g.part] = Math.floor(g.xp * factor);
  const lagging = new Set(summary.gains.filter((g) => g.wasLagging).map((g) => g.part));
  const rebuilt = buildSummary(earned, xpBefore, lagging, summary);
  const keptXp = rebuilt.gains.reduce((s, g) => s + g.xp, 0);
  return { ...summary, gains: rebuilt.gains, coins: rebuilt.coins, cappedXp: total - keptXp };
};

/**
 * +20% монет за тренировку по плану программы. Опыт не меняется: план
 * не должен давить на силу героя. Признак приходит с телефона — монеты
 * влияют только на косметику, проверять сам план на сервере не нужно.
 */
export const withPlanBonus = <T extends WorkoutSummary>(summary: T, planCompleted: boolean): T =>
  planCompleted ? { ...summary, coins: Math.round(summary.coins * (1 + C.planCoinBonus)) } : summary;
