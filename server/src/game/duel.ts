import { BODY_PARTS, BodyPart, PartMap } from './body-part';
import { GameConfig as C } from './config';
import { pickDuelEvent } from './duel-flavor';
import { AURA_TURNS, AuraKind, auraEffect } from './aura';
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
  /** Выбранная аура и её уровень (1–5); нет — без ауры. */
  aura?: { kind: AuraKind; level: number } | null;
}

/** Аура, горящая на этом ударе: чья (атакующего или защищающегося) и началась ли сейчас. */
export interface AuraMark {
  owner: 'attacker' | 'defender';
  kind: AuraKind;
  start?: boolean;
}

/** skip — боец пропустил ход из-за события (селфи у зеркала и т. п.). */
export type HitKind = 'miss' | 'hit' | 'crit' | 'skip';

export interface DuelHit {
  byAttacker: boolean;
  part: BodyPart;
  kind: HitKind;
  damage: number;
  targetHpAfter: number;
  /** Случайное событие перед ударом: id из DUEL_EVENTS, лечение и здоровье после него. */
  event?: { id: string; heal?: number; selfHpAfter?: number };
  /** Удар усилен событием (×1,5). */
  boosted?: boolean;
  /** Ауры на этом ударе — для пламени на экране боя. */
  auras?: AuraMark[];
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

const strike = (
  f: FighterSnapshot,
  p: number,
  rnd: () => number,
  boost: number,
  /** Фокус: без промаха, крит с этим множителем. */
  forcedCrit?: number,
): { part: BodyPart; kind: HitKind; damage: number } => {
  const part = pickPart(f.levels, rnd);
  const roll = rnd();
  if (forcedCrit === undefined && roll < C.duelMissChance) return { part, kind: 'miss', damage: 0 };
  const crit = forcedCrit !== undefined || roll > 1 - C.duelCritChance;
  const critMul = forcedCrit ?? C.duelCritMultiplier;
  const spread = 0.85 + rnd() * 0.3;
  const base = (p / 20) * ((1 + f.levels[part] / averageLevel(f.levels)) / 2) * spread * boost;
  return { part, kind: crit ? 'crit' : 'hit', damage: Math.max(1, Math.round(base * (crit ? critMul : 1))) };
};

/** Аура бойца в бою: использована ли, сколько ходов осталось. */
interface AuraState {
  kind: AuraKind;
  level: number;
  used: boolean;
  /** Ярость — свои ходы, стойкость — удары соперника. */
  left: number;
}

const auraOf = (f: FighterSnapshot): AuraState | null =>
  f.aura && f.aura.level > 0 ? { kind: f.aura.kind, level: f.aura.level, used: false, left: 0 } : null;

/** Пора включать: здоровья меньше 65 % или осталось 3 раунда. */
const auraTime = (hp: number, max: number, round: number, rounds: number) =>
  hp / Math.max(1, max) < 0.65 || round >= rounds - 3;

/**
 * Ход бойца: иногда перед ударом случается событие — восстановил здоровье,
 * усилил удар или пропустил ход. Возвращает запись лога и лечение.
 */
const turn = (
  f: FighterSnapshot,
  p: number,
  hpSelf: number,
  rnd: () => number,
): { hit: Omit<DuelHit, 'byAttacker' | 'targetHpAfter'>; heal: number } => {
  if (rnd() >= C.duelEventChance) return { hit: strike(f, p, rnd, 1), heal: 0 };
  const e = pickDuelEvent(rnd);
  switch (e.kind) {
    case 'heal': {
      const heal = Math.max(1, Math.round(p * (C.duelHealMin + rnd() * (C.duelHealMax - C.duelHealMin))));
      const selfHpAfter = Math.min(p, hpSelf + heal);
      return { hit: { ...strike(f, p, rnd, 1), event: { id: e.id, heal: selfHpAfter - hpSelf, selfHpAfter } }, heal };
    }
    case 'boost': {
      const s = strike(f, p, rnd, C.duelBoostMultiplier);
      return { hit: { ...s, event: { id: e.id }, boosted: s.kind !== 'miss' }, heal: 0 };
    }
    case 'skip':
      return { hit: { part: pickPart(f.levels, rnd), kind: 'skip', damage: 0, event: { id: e.id } }, heal: 0 };
  }
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
  const auraA = auraOf(a);
  const auraD = auraOf(d);

  /** Ход стороны с учётом аур: своей (ярость, скорость, фокус) и стойкости соперника. */
  const side = (
    me: FighterSnapshot,
    myPower: number,
    myHp: number,
    mine: AuraState | null,
    theirs: AuraState | null,
    owner: 'attacker' | 'defender',
    round: number,
  ): { hits: Omit<DuelHit, 'byAttacker' | 'targetHpAfter'>[]; heal: number } => {
    const other: 'attacker' | 'defender' = owner === 'attacker' ? 'defender' : 'attacker';
    let start = false;
    if (mine && !mine.used && auraTime(myHp, myPower, round, rounds)) {
      mine.used = true;
      start = true;
      if (mine.kind === 'fury') mine.left = AURA_TURNS;
      if (mine.kind === 'guard') mine.left = AURA_TURNS;
    }
    const marks: AuraMark[] = [];
    let boost = 1;
    let forced: number | undefined;
    if (mine && start && mine.kind === 'focus') {
      forced = auraEffect.focus(mine.level);
      marks.push({ owner, kind: 'focus', start: true });
    }
    if (mine && mine.kind === 'fury' && mine.left > 0) {
      boost = auraEffect.fury(mine.level);
      marks.push({ owner, kind: 'fury', start });
      mine.left--;
    }
    if (mine && start && mine.kind === 'guard') marks.push({ owner, kind: 'guard', start: true });
    const t =
      forced !== undefined || boost !== 1
        ? { hit: strike(me, myPower, rnd, boost, forced), heal: 0 }
        : turn(me, myPower, myHp, rnd);
    const hits: Omit<DuelHit, 'byAttacker' | 'targetHpAfter'>[] = [t.hit];
    if (mine && start && mine.kind === 'haste') {
      marks.push({ owner, kind: 'haste', start: true });
      hits.push({ ...strike(me, myPower, rnd, auraEffect.haste(mine.level)), auras: [{ owner, kind: 'haste' }] });
    }
    // Стойкость соперника режет урон этого хода.
    if (theirs && theirs.kind === 'guard' && theirs.left > 0) {
      for (const h of hits) h.damage = Math.round(h.damage * auraEffect.guard(theirs.level));
      marks.push({ owner: other, kind: 'guard' });
      theirs.left--;
    }
    if (marks.length) hits[0] = { ...hits[0], auras: [...(hits[0].auras ?? []), ...marks] };
    return { hits, heal: t.heal };
  };

  for (let r = 0; r < rounds; r++) {
    const ta = side(a, powerA, hpA, auraA, auraD, 'attacker', r);
    hpA = Math.min(powerA, hpA + ta.heal);
    for (const h of ta.hits) {
      hpD = Math.max(0, hpD - h.damage);
      log.push({ byAttacker: true, ...h, targetHpAfter: hpD });
    }
    const td = side(d, powerD, hpD, auraD, auraA, 'defender', r);
    hpD = Math.min(powerD, hpD + td.heal);
    for (const h of td.hits) {
      hpA = Math.max(0, hpA - h.damage);
      log.push({ byAttacker: false, ...h, targetHpAfter: hpA });
    }
  }
  const shareA = hpA / Math.max(1, powerA);
  const shareD = hpD / Math.max(1, powerD);
  const attackerWon = shareA !== shareD ? shareA > shareD : powerA >= powerD;
  return { seed, powerA, powerD, log, attackerWon };
};
