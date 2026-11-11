import { BODY_PARTS, BodyPart, PartMap, partMap } from './body-part';
import { GameConfig as C } from './config';

/** Чистые функции прогрессии (ТЗ 4.1, 4.2, 4.5). Совпадают с progression.dart. */
export const levelFromXp = (xp: number): number => Math.floor(xp / C.xpPerLevel) + 1;

export const levels = (xp: PartMap<number>): PartMap<number> => partMap((p) => levelFromXp(xp[p] ?? 0));

export const averageLevel = (lv: PartMap<number>): number =>
  BODY_PARTS.reduce((s, p) => s + lv[p], 0) / BODY_PARTS.length;

/** Отстающие части, от самой слабой. */
export const laggingParts = (lv: PartMap<number>): BodyPart[] => {
  const avg = averageLevel(lv);
  return BODY_PARTS.filter((p) => lv[p] < avg - C.laggingThreshold).sort((a, b) => lv[a] - lv[b]);
};

export const balanceMultiplier = (lv: PartMap<number>): number =>
  laggingParts(lv).length === 0 ? C.powerBonusBalanced : C.powerPenaltyUnbalanced;

/** P = (10·ΣL + 2·min(S, 30)) · K_bal */
export const power = (lv: PartMap<number>, streakDays: number): number => {
  const sum = BODY_PARTS.reduce((s, p) => s + lv[p], 0);
  return Math.round((10 * sum + 2 * Math.min(streakDays, C.streakCap)) * balanceMultiplier(lv));
};

/** XP = k_base · d · B · V */
export const xpForSet = (share: number, isLagging: boolean, validity: number): number =>
  C.baseXpPerSet * share * (isLagging ? C.laggingXpMultiplier : 1) * validity;
