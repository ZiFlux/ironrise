import { BodyPart, PartMap } from './body-part';
import { GameConfig as C } from './config';
import { buildSummary, WorkoutSummary } from './workout';

/** Отметка в итоге тренировки: с кем тренировались и сколько добавил бонус. */
export interface JointMark {
  partners: string[];
  bonusXp: number;
}

/**
 * Бонус совместной тренировки: опыт каждой части ×(1 + jointBonus), монеты — от нового опыта.
 * Применяется до дневного потолка, так что вместе нельзя набрать больше дневной нормы.
 */
export const withJointBonus = <T extends WorkoutSummary>(
  summary: T,
  xpBefore: PartMap<number>,
  partners: string[],
): T & { joint?: JointMark } => {
  if (partners.length === 0 || summary.gains.length === 0) return summary;
  const earned: Partial<Record<BodyPart, number>> = {};
  for (const g of summary.gains) earned[g.part] = g.xp * (1 + C.jointBonus);
  const lagging = new Set(summary.gains.filter((g) => g.wasLagging).map((g) => g.part));
  const rebuilt = buildSummary(earned, xpBefore, lagging, summary);
  const before = summary.gains.reduce((s, g) => s + g.xp, 0);
  const after = rebuilt.gains.reduce((s, g) => s + g.xp, 0);
  return { ...summary, gains: rebuilt.gains, coins: rebuilt.coins, joint: { partners, bonusXp: after - before } };
};

/** Шестизначный код без ведущего нуля — его удобно продиктовать. */
export const jointCode = (rnd: () => number): string => String(100_000 + Math.floor(rnd() * 900_000));

/** Тренировка засчитывается сессии, если закончилась после входа в неё и началась до её конца. */
export const countsForSession = (
  workout: { startedAt: Date; finishedAt: Date },
  session: { joinedAt: Date; endsAt: Date },
): boolean => workout.finishedAt >= session.joinedAt && workout.startedAt <= session.endsAt;
