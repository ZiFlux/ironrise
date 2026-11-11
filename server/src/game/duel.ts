import { BODY_PARTS, BodyPart, PartMap } from './body-part';
import { GameConfig as C } from './config';
import { averageLevel, power } from './progression';

/** Детерминированный генератор (mulberry32): один seed — один и тот же бой. */
export const seededRandom = (seed: number): (() => number) => {
  let a = seed >>> 0;
  return () => {
    a = (a + 0x6d2b79f5) >>> 0;
    let t = a;
    t = Math.imul(t ^ (t >>> 15), t | 1);
    t ^= t + Math.imul(t ^ (t >>> 7), t | 61);
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
};

/** Снимок аватара на момент боя (PLAN 1, принцип 3). */
export interface FighterSnapshot {
  id: string;
  name: string;
  levels: PartMap<number>;
  streakDays: number;
}

export type HitKind = 'miss' | 'hit' | 'crit';

export interface DuelHit {
  byAttacker: boolean;
  part: BodyPart;
  kind: HitKind;
  damage: number;
  targetHpAfter: number;
}

export interface DuelResult {
  seed: number;
  powerA: number;
  powerD: number;
  log: DuelHit[];
  attackerWon: boolean;
}

const pickPart = (lv: PartMap<number>, rnd: () => number): BodyPart => {
  const total = BODY_PARTS.reduce((s, p) => s + lv[p], 0);
  let x = Math.floor(rnd() * total);
  for (const p of BODY_PARTS) {
    if (x < lv[p]) return p;
    x -= lv[p];
  }
  return BODY_PARTS[BODY_PARTS.length - 1];
};

const strike = (f: FighterSnapshot, p: number, rnd: () => number): { part: BodyPart; kind: HitKind; damage: number } => {
  const part = pickPart(f.levels, rnd);
  const roll = rnd();
  if (roll < C.duelMissChance) return { part, kind: 'miss', damage: 0 };
  const crit = roll > 1 - C.duelCritChance;
  const spread = 0.85 + rnd() * 0.3;
  const base = (p / 20) * ((1 + f.levels[part] / averageLevel(f.levels)) / 2) * spread;
  return { part, kind: crit ? 'crit' : 'hit', damage: Math.max(1, Math.round(base * (crit ? C.duelCritMultiplier : 1))) };
};

/**
 * Бой по ТЗ 4.5: HP = P, 6–10 раундов, в каждом бьют оба. Побеждает тот, у кого
 * больше доля оставшегося HP; при равенстве — более сильный (ничья — атакующий).
 */
export const simulateDuel = (a: FighterSnapshot, d: FighterSnapshot, seed: number): DuelResult => {
  const rnd = seededRandom(seed);
  const powerA = power(a.levels, a.streakDays);
  const powerD = power(d.levels, d.streakDays);
  const rounds = C.duelMinRounds + Math.floor(rnd() * (C.duelMaxRounds - C.duelMinRounds + 1));
  let hpA = powerA;
  let hpD = powerD;
  const log: DuelHit[] = [];
  for (let r = 0; r < rounds; r++) {
    const sa = strike(a, powerA, rnd);
    hpD = Math.max(0, hpD - sa.damage);
    log.push({ byAttacker: true, ...sa, targetHpAfter: hpD });
    const sd = strike(d, powerD, rnd);
    hpA = Math.max(0, hpA - sd.damage);
    log.push({ byAttacker: false, ...sd, targetHpAfter: hpA });
  }
  const shareA = hpA / Math.max(1, powerA);
  const shareD = hpD / Math.max(1, powerD);
  const attackerWon = shareA !== shareD ? shareA > shareD : powerA >= powerD;
  return { seed, powerA, powerD, log, attackerWon };
};
