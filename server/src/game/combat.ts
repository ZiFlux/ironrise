/**
 * Боёвка с выбором действий (docs/COMBAT.md). Бой — 3 раунда по 4 шага: бойцы заранее
 * выбирают цепочку действий, шаги разыгрываются попарно. Здоровье и урон — от силы
 * и уровней частей тела, выбор даёт перевес, но сила главнее.
 * Чистая логика: один seed и одни и те же цепочки — один и тот же бой.
 */
import { z } from 'zod';
import { AURA_TURNS, AuraKind, auraEffect } from './aura';
import { BodyPart, PartMap } from './body-part';
import { FighterSnapshot, seededRandom } from './duel';
import { pickDuelEvent } from './duel-flavor';
import { averageLevel, power } from './progression';

/** Бой короче (28.11.2026, docs/DUELS_2.md): было 6 × 5 — до 30 решений, рутина. */
export const COMBAT_ROUNDS = 3;
export const COMBAT_STEPS = 4;
/** Мощный удар — не больше стольких за раунд. */
export const MAX_HEAVY_PER_ROUND = 2;
/** Одно действие — не больше стольких подряд. */
export const MAX_SAME_IN_ROW = 3;
/** Доля шагов, где ИИ выбирает лучший ответ на действие игрока. */
export const AI_BEST_CHANCE = 0.6;

export const COMBAT_ACTIONS = ['body', 'legs', 'heavy', 'grab', 'block', 'evade'] as const;
export type CombatAction = (typeof COMBAT_ACTIONS)[number];
/** none — пропуск шага: сбит захватом или событием. */
export type StepAction = CombatAction | 'none';

const ATTACKS: ReadonlySet<StepAction> = new Set(['body', 'legs', 'heavy', 'grab']);
const DAMAGE_MUL: Record<'body' | 'legs' | 'heavy' | 'grab', number> = { body: 1, legs: 0.85, heavy: 1.35, grab: 0.7 };
/** Урон шага от силы: при равных бойцах нокаут обычно к концу 3-го раунда. */
export const DAMAGE_DIVISOR = 6;
const CRIT_CHANCE = 0.1;
/** Блок: доля погашенного урона = BASE + SCALE · (защита / (защита + атака)), не больше MAX. */
const BLOCK_BASE = 0.15;
const BLOCK_SCALE = 0.4;
const BLOCK_MAX = 0.6;
/** Отход: шанс уйти = base + scale · отношение уровней. */
const EVADE: Record<'body' | 'legs' | 'heavy' | 'grab', [number, number]> = {
  heavy: [0.25, 0.4],
  body: [0.1, 0.3],
  grab: [0.15, 0.3],
  legs: [0.03, 0.06],
};
/** Захват, встреченный ударом, проходит наполовину слабее, а захватывающий получает больше. */
const GRAB_COUNTERED = 0.4;
const OPEN_BONUS = 1.1;
/** Удачная защита отвечает: блок — слабым ударом, отход — встречным (доля удара в корпус). */
const BLOCK_COUNTER = 0.45;
const EVADE_COUNTER = 0.7;
const CRIT_MUL = 1.7;
const EVENT_CHANCE = 0.15;

/** Цепочка раунда: ровно COMBAT_STEPS действий, мощных не больше 2, одинаковых подряд не больше 3. */
export const chainProblem = (chain: readonly string[]): string | null => {
  if (chain.length !== COMBAT_STEPS) return `Нужно ${COMBAT_STEPS} действий`;
  if (!chain.every((a) => (COMBAT_ACTIONS as readonly string[]).includes(a))) return 'Неизвестное действие';
  if (chain.filter((a) => a === 'heavy').length > MAX_HEAVY_PER_ROUND) {
    return `Мощных ударов — не больше ${MAX_HEAVY_PER_ROUND} за раунд`;
  }
  let run = 1;
  for (let i = 1; i < chain.length; i++) {
    run = chain[i] === chain[i - 1] ? run + 1 : 1;
    if (run > MAX_SAME_IN_ROW) return `Одно действие — не больше ${MAX_SAME_IN_ROW} раз подряд`;
  }
  return null;
};

export const ChainSchema = z
  .array(z.enum(COMBAT_ACTIONS))
  .length(COMBAT_STEPS)
  .refine((c) => chainProblem(c) === null, { message: 'Bad chain' });

/** Каким уровнем бьёт действие и каким защищается. */
const level = (lv: PartMap<number>, parts: BodyPart[]) => parts.reduce((s, p) => s + lv[p], 0) / parts.length;
const ATTACK_PARTS: Record<'body' | 'legs' | 'heavy' | 'grab', BodyPart[]> = {
  body: ['chest', 'back', 'core'],
  legs: ['legs'],
  heavy: ['arms'],
  grab: ['back'],
};
const BLOCK_PARTS: BodyPart[] = ['core', 'chest'];
const EVADE_PARTS: BodyPart[] = ['legs', 'cardio'];

/** Доля защиты против атаки: 0,5 при равных уровнях. */
const ratio = (def: number, att: number) => (def + 1) / (def + att + 2);

/** Сколько урона гасит блок (0,2–0,85). Мощный пробивает наполовину, по ногам — частично. */
const blockShare = (defLv: PartMap<number>, attLv: PartMap<number>, act: 'body' | 'legs' | 'heavy') => {
  const share = Math.min(BLOCK_MAX, Math.max(0.1, BLOCK_BASE + BLOCK_SCALE * ratio(level(defLv, BLOCK_PARTS), level(attLv, ATTACK_PARTS[act]))));
  return share * (act === 'heavy' ? 0.5 : act === 'legs' ? 0.8 : 1);
};

/** Шанс уйти отходом: от мощного — легко, от удара по ногам — почти никогда. */
const evadeChance = (defLv: PartMap<number>, attLv: PartMap<number>, act: 'body' | 'legs' | 'heavy' | 'grab') => {
  const r = ratio(level(defLv, EVADE_PARTS), level(attLv, ATTACK_PARTS[act]));
  const base = EVADE[act];
  return Math.min(0.95, base[0] + base[1] * r);
};

/** Базовый урон действия бойца: от силы и уровня бьющей части. */
const baseDamage = (lv: PartMap<number>, pw: number, act: 'body' | 'legs' | 'heavy' | 'grab') => {
  const partFactor = (1 + level(lv, ATTACK_PARTS[act]) / Math.max(1, averageLevel(lv))) / 2;
  return (pw / DAMAGE_DIVISOR) * partFactor * DAMAGE_MUL[act];
};

export type StepOutcome = 'hit' | 'crit' | 'blocked' | 'evaded' | 'broken' | 'grabbed' | 'countered' | 'riposte' | 'none';

interface Strike {
  damage: number;
  outcome: StepOutcome;
  /** Захват удался — следующий шаг соперника сорван. */
  stun: boolean;
}

/** Удар [act] бойца в [theirs]; rnd — для разброса, крита и отхода. */
const resolveStrike = (
  act: StepAction,
  theirs: StepAction,
  me: { lv: PartMap<number>; pw: number },
  them: { lv: PartMap<number> },
  rnd: () => number,
): Strike => {
  if (!ATTACKS.has(act)) return { damage: 0, outcome: 'none', stun: false };
  const a = act as 'body' | 'legs' | 'heavy' | 'grab';
  let mul = 1;
  let outcome: StepOutcome = 'hit';
  let stun = false;
  if (a === 'grab') {
    // Захват срывается, если соперник бьёт; от отхода — по шансу; блок ломает.
    if (theirs === 'body' || theirs === 'legs' || theirs === 'heavy') {
      mul = GRAB_COUNTERED;
      outcome = 'countered';
    } else {
    if (theirs === 'evade' && rnd() < evadeChance(them.lv, me.lv, a)) return { damage: 0, outcome: 'evaded', stun: false };
      stun = theirs !== 'none';
      outcome = theirs === 'block' ? 'broken' : 'grabbed';
    }
  } else if (theirs === 'block') {
    mul = 1 - blockShare(them.lv, me.lv, a);
    outcome = 'blocked';
  } else if (theirs === 'evade') {
    if (rnd() < evadeChance(them.lv, me.lv, a)) return { damage: 0, outcome: 'evaded', stun: false };
  } else if (theirs === 'grab') {
    mul = OPEN_BONUS; // захватывающий раскрылся
  }
  const spread = 0.9 + rnd() * 0.2;
  const crit = outcome === 'hit' && rnd() < CRIT_CHANCE;
  if (crit) outcome = 'crit';
  const damage = Math.max(1, Math.round(baseDamage(me.lv, me.pw, a) * mul * spread * (crit ? CRIT_MUL : 1)));
  return { damage, outcome, stun };
};

/** Ожидаемый размен шага для ИИ: сколько нанесу минус сколько получу. */
const expectedNet = (
  mine: StepAction,
  theirs: StepAction,
  me: { lv: PartMap<number>; pw: number },
  them: { lv: PartMap<number>; pw: number },
): number => {
  const out = (act: StepAction, other: StepAction, a: typeof me, d: typeof them): number => {
    if (!ATTACKS.has(act)) {
      if (other !== 'body' && other !== 'legs' && other !== 'heavy') return 0;
      const counter = baseDamage(a.lv, a.pw, 'body');
      if (act === 'block') return counter * BLOCK_COUNTER;
      if (act === 'evade') return counter * EVADE_COUNTER * evadeChance(a.lv, d.lv, other);
      return 0;
    }
    const k = act as 'body' | 'legs' | 'heavy' | 'grab';
    const base = baseDamage(a.lv, a.pw, k);
    if (k === 'grab') {
      if (other === 'body' || other === 'legs' || other === 'heavy') return base * GRAB_COUNTERED;
      // Сбитый шаг соперника — ещё полудара сверху.
      const land = other === 'evade' ? 1 - evadeChance(d.lv, a.lv, k) : 1;
      return land * base * 1.5;
    }
    if (other === 'block') return base * (1 - blockShare(d.lv, a.lv, k));
    if (other === 'evade') return base * (1 - evadeChance(d.lv, a.lv, k));
    if (other === 'grab') return base * OPEN_BONUS;
    return base * (1 + CRIT_CHANCE * (CRIT_MUL - 1));
  };
  return out(mine, theirs, me, them) - out(theirs, mine, them, me);
};

/** Можно ли поставить [act] шагом [i] в начатую цепочку. */
const allowed = (chain: StepAction[], act: CombatAction) => {
  if (act === 'heavy' && chain.filter((a) => a === 'heavy').length >= MAX_HEAVY_PER_ROUND) return false;
  const tail = chain.slice(-MAX_SAME_IN_ROW);
  return !(tail.length === MAX_SAME_IN_ROW && tail.every((a) => a === act));
};

/** Частоты действий игрока за бой: ИИ не видит текущую цепочку, а угадывает по привычкам. */
export type ActionHabits = Record<CombatAction, number>;
export const emptyHabits = (): ActionHabits => ({ body: 0, legs: 0, heavy: 0, grab: 0, block: 0, evade: 0 });

/**
 * Цепочка ИИ на раунд: на каждом шаге с шансом [AI_BEST_CHANCE] — лучший ответ на
 * привычки игрока (что он чаще делал в этом бою; в начале боя — всё поровну), иначе —
 * случайное допустимое действие. Текущую цепочку игрока ИИ не видит.
 */
export const aiChain = (
  habits: ActionHabits,
  me: { lv: PartMap<number>; pw: number },
  them: { lv: PartMap<number>; pw: number },
  rnd: () => number,
): CombatAction[] => {
  const weight = (a: CombatAction) => habits[a] + 1;
  const total = COMBAT_ACTIONS.reduce((sum, a) => sum + weight(a), 0);
  const value = (mine: CombatAction) =>
    COMBAT_ACTIONS.reduce((sum, theirs) => sum + (weight(theirs) / total) * expectedNet(mine, theirs, me, them), 0);
  const chain: CombatAction[] = [];
  for (let i = 0; i < COMBAT_STEPS; i++) {
    const options = COMBAT_ACTIONS.filter((a) => allowed(chain, a));
    const pick =
      rnd() < AI_BEST_CHANCE
        ? options.reduce((best, a) => (value(a) > value(best) ? a : best))
        : options[Math.floor(rnd() * options.length)];
    chain.push(pick);
  }
  return chain;
};

// ── Состояние боя ──────────────────────────────────────────────────────────

interface AuraState {
  kind: AuraKind;
  level: number;
  used: boolean;
  left: number;
}

export interface CombatSide {
  hp: number;
  aura: AuraState | null;
  /** Следующий шаг сорван (захват в конце прошлого раунда). */
  stunned: boolean;
}

export interface CombatState {
  seed: number;
  round: number;
  powerA: number;
  powerD: number;
  a: CombatSide;
  d: CombatSide;
  finished: boolean;
  attackerWon: boolean | null;
  /** Что игрок выбирал в этом бою — по этому ИИ угадывает следующие ходы. */
  habits: ActionHabits;
  /** Оба упали в одном шаге: кто устоял «меньше в минус» (иначе ничью брал атакующий). */
  doubleKoWinner?: boolean;
}

export interface CombatAuraMark {
  owner: 'attacker' | 'defender';
  kind: AuraKind;
  start?: boolean;
}

export interface CombatStep {
  round: number;
  step: number;
  /** Что сделали бойцы (none — шаг сорван). */
  a: StepAction;
  d: StepAction;
  /** Урон по защищающемуся (от атакующего) и по атакующему. */
  toD: number;
  toA: number;
  outA: StepOutcome;
  outD: StepOutcome;
  hpA: number;
  hpD: number;
  /** Событие у бойца перед шагом (первый шаг раунда): id из DUEL_EVENTS. */
  event?: { owner: 'attacker' | 'defender'; id: string; heal?: number };
  auras?: CombatAuraMark[];
}

const auraOf = (f: FighterSnapshot): AuraState | null =>
  f.aura && f.aura.level > 0 ? { kind: f.aura.kind, level: f.aura.level, used: false, left: 0 } : null;

export const startCombat = (a: FighterSnapshot, d: FighterSnapshot, seed: number): CombatState => {
  const powerA = power(a.levels, a.streakDays);
  const powerD = power(d.levels, d.streakDays);
  return {
    seed,
    round: 0,
    powerA,
    powerD,
    a: { hp: powerA, aura: auraOf(a), stunned: false },
    d: { hp: powerD, aura: auraOf(d), stunned: false },
    finished: false,
    attackerWon: null,
    habits: emptyHabits(),
  };
};

/** Аура включается сама: здоровья меньше 65 % или идут последние 2 раунда. */
const auraTime = (side: CombatSide, max: number, round: number) =>
  side.hp / Math.max(1, max) < 0.65 || round >= COMBAT_ROUNDS - 2;

/**
 * Раунд: цепочка игрока ([chainA]) против ИИ соперника. Возвращает новое состояние и
 * шаги. Детерминирован: зерно раунда — seed боя + номер раунда.
 */
export const playRound = (
  state: CombatState,
  fa: FighterSnapshot,
  fd: FighterSnapshot,
  chainA: readonly CombatAction[],
): { state: CombatState; steps: CombatStep[]; chainD: CombatAction[] } => {
  if (state.finished) throw new Error('Combat is finished');
  const rnd = seededRandom((state.seed + 7919 * (state.round + 1)) >>> 0);
  const s: CombatState = structuredClone(state);
  const A = { lv: fa.levels, pw: s.powerA };
  const D = { lv: fd.levels, pw: s.powerD };
  const chainD = aiChain(s.habits, D, A, rnd);
  for (const act of chainA) s.habits[act]++;
  const actsA: StepAction[] = [...chainA];
  const actsD: StepAction[] = [...chainD];
  if (s.a.stunned) actsA[0] = 'none';
  if (s.d.stunned) actsD[0] = 'none';
  s.a.stunned = false;
  s.d.stunned = false;

  // Событие раунда: у каждого бойца с небольшим шансом.
  const events: CombatStep['event'][] = [];
  const boost = { a: 1, d: 1 };
  for (const owner of ['attacker', 'defender'] as const) {
    if (rnd() >= EVENT_CHANCE) continue;
    const e = pickDuelEvent(rnd);
    const side = owner === 'attacker' ? s.a : s.d;
    const max = owner === 'attacker' ? s.powerA : s.powerD;
    if (e.kind === 'heal') {
      const heal = Math.min(max - side.hp, Math.round(max * (0.05 + rnd() * 0.05)));
      side.hp += heal;
      events.push({ owner, id: e.id, heal });
    } else {
      if (e.kind === 'boost') boost[owner === 'attacker' ? 'a' : 'd'] = 1.5;
      else (owner === 'attacker' ? actsA : actsD)[0] = 'none';
      events.push({ owner, id: e.id });
    }
  }

  const steps: CombatStep[] = [];
  for (let i = 0; i < COMBAT_STEPS && !s.finished; i++) {
    const marks: CombatAuraMark[] = [];
    const mul = { a: i === 0 ? boost.a : 1, d: i === 0 ? boost.d : 1 };
    const incoming = { a: 1, d: 1 };
    let focusA = false;
    let focusD = false;
    let hasteA = false;
    let hasteD = false;
    for (const [key, owner, max] of [
      ['a', 'attacker', s.powerA],
      ['d', 'defender', s.powerD],
    ] as const) {
      const aura = s[key].aura;
      if (!aura) continue;
      let start = false;
      if (!aura.used && auraTime(s[key], max, s.round)) {
        aura.used = true;
        start = true;
        aura.left = aura.kind === 'fury' || aura.kind === 'guard' ? AURA_TURNS : 1;
      }
      if (aura.left <= 0) continue;
      aura.left--;
      marks.push({ owner, kind: aura.kind, start });
      if (aura.kind === 'fury') mul[key] *= auraEffect.fury(aura.level);
      if (aura.kind === 'guard') incoming[key] *= auraEffect.guard(aura.level);
      if (aura.kind === 'focus') key === 'a' ? (focusA = true) : (focusD = true);
      if (aura.kind === 'haste') key === 'a' ? (hasteA = true) : (hasteD = true);
    }
    const strikeA = resolveStrike(actsA[i], actsD[i], A, D, rnd);
    const strikeD = resolveStrike(actsD[i], actsA[i], D, A, rnd);
    const finish = (st: Strike, m: number, inc: number, focus: boolean, focusLevel: number, haste: boolean, hasteLevel: number, lv: PartMap<number>, pw: number) => {
      let dmg = st.damage * m;
      if (focus && dmg > 0 && st.outcome !== 'crit') {
        dmg *= auraEffect.focus(focusLevel) / 1.5;
        st.outcome = 'crit';
      }
      if (haste) dmg += baseDamage(lv, pw, 'body') * auraEffect.haste(hasteLevel);
      return Math.round(dmg * inc);
    };
    // Удачная защита отвечает ударом.
    const counter = (mine: StepAction, theirStrike: Strike, me: typeof A, st: Strike) => {
      const k = mine === 'block' && theirStrike.outcome === 'blocked' ? BLOCK_COUNTER
        : mine === 'evade' && theirStrike.outcome === 'evaded' ? EVADE_COUNTER : 0;
      if (k === 0) return;
      st.damage = Math.max(1, Math.round(baseDamage(me.lv, me.pw, 'body') * k * (0.9 + rnd() * 0.2)));
      st.outcome = 'riposte';
    };
    counter(actsA[i], strikeD, A, strikeA);
    counter(actsD[i], strikeA, D, strikeD);
    const toD = finish(strikeA, mul.a, incoming.d, focusA, s.a.aura?.level ?? 0, hasteA, s.a.aura?.level ?? 0, A.lv, A.pw);
    const toA = finish(strikeD, mul.d, incoming.a, focusD, s.d.aura?.level ?? 0, hasteD, s.d.aura?.level ?? 0, D.lv, D.pw);
    const rawA = s.a.hp - toA;
    const rawD = s.d.hp - toD;
    if (rawA <= 0 && rawD <= 0) {
      const shareA = rawA / Math.max(1, s.powerA);
      const shareD = rawD / Math.max(1, s.powerD);
      s.doubleKoWinner = shareA !== shareD ? shareA > shareD : rnd() < 0.5;
    }
    s.d.hp = Math.max(0, rawD);
    s.a.hp = Math.max(0, rawA);
    // Захват сбивает следующий шаг (или первый шаг следующего раунда).
    if (strikeA.stun) i + 1 < COMBAT_STEPS ? (actsD[i + 1] = 'none') : (s.d.stunned = true);
    if (strikeD.stun) i + 1 < COMBAT_STEPS ? (actsA[i + 1] = 'none') : (s.a.stunned = true);
    steps.push({
      round: s.round,
      step: i,
      a: actsA[i],
      d: actsD[i],
      toD,
      toA,
      outA: strikeA.outcome,
      outD: strikeD.outcome,
      hpA: s.a.hp,
      hpD: s.d.hp,
      ...(i === 0 && events.length ? { event: events[0] } : {}),
      ...(marks.length ? { auras: marks } : {}),
    });
    if (s.a.hp === 0 || s.d.hp === 0) s.finished = true;
  }
  // Второе событие раунда (если были у обоих) — на втором шаге.
  if (events.length > 1 && steps.length > 1) steps[1].event = events[1];
  s.round++;
  if (!s.finished && s.round >= COMBAT_ROUNDS) s.finished = true;
  if (s.finished) s.attackerWon = winner(s);
  return { state: s, steps, chainD };
};

/** Победитель: кто устоял; оба или никто — по доле здоровья, при равенстве — кто сильнее. */
const winner = (s: CombatState): boolean => {
  if (s.a.hp === 0 && s.d.hp === 0 && s.doubleKoWinner !== undefined) return s.doubleKoWinner;
  if (s.d.hp === 0 && s.a.hp > 0) return true;
  if (s.a.hp === 0 && s.d.hp > 0) return false;
  const shareA = s.a.hp / Math.max(1, s.powerA);
  const shareD = s.d.hp / Math.max(1, s.powerD);
  return shareA !== shareD ? shareA > shareD : s.powerA >= s.powerD;
};

/** Случайная допустимая цепочка — для брошенного боя и тестов. */
export const randomChain = (rnd: () => number): CombatAction[] => {
  const chain: CombatAction[] = [];
  for (let i = 0; i < COMBAT_STEPS; i++) {
    const options = COMBAT_ACTIONS.filter((a) => allowed(chain, a));
    chain.push(options[Math.floor(rnd() * options.length)]);
  }
  return chain;
};

/**
 * Шанс победы атакующего из текущего состояния: [n] быстрых боёв, где обе
 * стороны играют «толково» (как ИИ: лучший ответ с шансом 60 %, иначе наугад).
 * Для экрана: понятно, когда выбор решает, а когда всё решила сила.
 */
export const winChance = (state: CombatState, fa: FighterSnapshot, fd: FighterSnapshot, n = 150): number => {
  if (state.finished) return state.attackerWon ? 1 : 0;
  let wins = 0;
  for (let i = 0; i < n; i++) {
    const rnd = seededRandom((state.seed ^ Math.imul(i + 1, 2654435761)) >>> 0);
    let s: CombatState = { ...state, seed: (state.seed + Math.imul(i + 1, 40503)) >>> 0 };
    while (!s.finished) {
      const chain = aiChain(emptyHabits(), { lv: fa.levels, pw: s.powerA }, { lv: fd.levels, pw: s.powerD }, rnd);
      s = playRound(s, fa, fd, chain).state;
    }
    if (s.attackerWon) wins++;
  }
  return Math.round((wins / n) * 100) / 100;
};

/** Цепочка «Авто»: за игрока выбирает тот же ИИ, что и за соперника. */
export const autoChain = (state: CombatState, fa: FighterSnapshot, fd: FighterSnapshot): CombatAction[] =>
  aiChain(
    emptyHabits(),
    { lv: fa.levels, pw: state.powerA },
    { lv: fd.levels, pw: state.powerD },
    seededRandom((state.seed ^ Math.imul(state.round + 11, 2246822519)) >>> 0),
  );
