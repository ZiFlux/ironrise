import { CombatAction, aiChain, chainProblem, emptyHabits, playRound, randomChain, startCombat } from '../src/game/combat';
import { FighterSnapshot, seededRandom } from '../src/game/duel';
import { PartMap } from '../src/game/body-part';

const lv = (n: number): PartMap<number> => ({ chest: n, back: n, arms: n, legs: n, core: n, cardio: n });
const fighter = (id: string, level: number): FighterSnapshot => ({ id, name: id, levels: lv(level), streakDays: 0 });

type Policy = 'random' | 'smart';

/** Доля побед атакующего за [n] боёв. smart — игрок угадывает лучший ответ, как ИИ, но всегда. */
const winRate = (a: FighterSnapshot, d: FighterSnapshot, policy: Policy, n = 600) => {
  let wins = 0;
  for (let seed = 1; seed <= n; seed++) {
    const rnd = seededRandom(seed * 31);
    let st = startCombat(a, d, seed);
    while (!st.finished) {
      let chain: CombatAction[];
      if (policy === 'random') chain = randomChain(rnd);
      else {
        // «Толковый» игрок: лучший ответ на равномерного соперника на каждом шаге.
        chain = aiChain(emptyHabits(), { lv: a.levels, pw: st.powerA }, { lv: d.levels, pw: st.powerD }, () => rnd() * 0.5);
      }
      st = playRound(st, a, d, chain).state;
    }
    if (st.attackerWon) wins++;
  }
  return wins / n;
};

describe('боёвка с выбором действий (docs/COMBAT.md)', () => {
  it('цепочка: 5 действий, мощных ≤ 2, одинаковых подряд ≤ 3', () => {
    expect(chainProblem(['body', 'legs', 'block', 'evade', 'grab'])).toBeNull();
    expect(chainProblem(['body', 'legs'])).not.toBeNull();
    expect(chainProblem(['heavy', 'body', 'heavy', 'block', 'heavy'])).not.toBeNull();
    expect(chainProblem(['block', 'block', 'block', 'block', 'body'])).not.toBeNull();
    expect(chainProblem(['body', 'kick', 'body', 'body', 'body'])).not.toBeNull();
  });

  it('один seed и одни цепочки — один и тот же раунд', () => {
    const a = fighter('a', 10);
    const d = fighter('d', 10);
    const chain: CombatAction[] = ['body', 'block', 'heavy', 'evade', 'grab'];
    const r1 = playRound(startCombat(a, d, 42), a, d, chain);
    const r2 = playRound(startCombat(a, d, 42), a, d, chain);
    expect(r1).toEqual(r2);
  });

  it('бой кончается: нокаут или 6 раундов', () => {
    const a = fighter('a', 10);
    const d = fighter('d', 10);
    let st = startCombat(a, d, 7);
    let rounds = 0;
    while (!st.finished) {
      st = playRound(st, a, d, randomChain(seededRandom(rounds + 1))).state;
      rounds++;
    }
    expect(rounds).toBeLessThanOrEqual(6);
    expect(st.attackerWon).not.toBeNull();
  });

  it('баланс: сила главнее выбора', () => {
    const equalRandom = winRate(fighter('a', 10), fighter('d', 10), 'random');
    const strongerRandom = winRate(fighter('a', 13), fighter('d', 10), 'random');
    const weakerSmart = winRate(fighter('a', 9), fighter('d', 10), 'smart');
    const weakerRandom = winRate(fighter('a', 9), fighter('d', 10), 'random');
    const equalSmart = winRate(fighter('a', 10), fighter('d', 10), 'smart');
    // eslint-disable-next-line no-console
    console.log({ equalRandom, strongerRandom, weakerSmart, weakerRandom, equalSmart });
    // Равные, игрок наугад против ИИ (60 % лучший ответ на его привычки) — ИИ чаще побеждает.
    expect(equalRandom).toBeGreaterThan(0.08);
    expect(equalRandom).toBeLessThan(0.4);
    // На 30 % сильнее и наугад — почти всегда побеждает: сила главнее выбора.
    expect(strongerRandom).toBeGreaterThan(0.75);
    // Слабее на 10 %: наугад — почти без шансов, с толковым выбором — шанс есть, но не гарантия.
    expect(weakerSmart).toBeGreaterThan(0.1);
    expect(weakerSmart).toBeLessThan(0.5);
    expect(weakerSmart).toBeGreaterThan(weakerRandom * 3);
    // Толковый выбор при равных — решающий перевес.
    expect(equalSmart).toBeGreaterThan(0.6);
  });
});
