import {
  LADDER,
  bossUnlocked,
  ladderBotId,
  ladderCoins,
  ladderTier,
  readBeaten,
  tierWins,
} from '../src/game/bot-ladder';
import { power } from '../src/game/progression';

describe('лестница ботов (п. 88)', () => {
  it('сила растёт от ступени к ступени, босс сильнее своих ботов', () => {
    let prevBoss = 0;
    for (let t = 0; t < LADDER.length; t++) {
      const { bots, boss } = ladderTier(t);
      const powers = bots.map((b) => power(b.levels, b.streakDays));
      const bossPower = power(boss.levels, boss.streakDays);
      expect(bossPower).toBeGreaterThanOrEqual(Math.max(...powers));
      if (t > 0) expect(Math.min(...powers)).toBeGreaterThan(prevBoss * 0.6);
      expect(bossPower).toBeGreaterThan(prevBoss);
      prevBoss = bossPower;
    }
  });

  it('ауры: на первой ступени нет, со второй — у сильных ботов и босса, уровень растёт', () => {
    expect(ladderTier(0).bots.every((b) => !b.aura)).toBe(true);
    expect(ladderTier(0).boss.aura).toBeUndefined();
    const t2 = ladderTier(2);
    expect(t2.boss.aura?.level).toBeGreaterThanOrEqual(1);
    expect(t2.bots.filter((b) => b.aura)).toHaveLength(2);
    expect(ladderTier(12).boss.aura?.level).toBe(5);
  });

  it('боты ступени одинаковы у всех и с уникальными id', () => {
    expect(ladderTier(3)).toEqual(ladderTier(3));
    const ids = ladderTier(5).bots.map((b) => b.id);
    expect(new Set(ids).size).toBe(ids.length);
  });

  it('босс открывается после 3 побед на своей ступени', () => {
    const beaten = [ladderBotId(2, 0), ladderBotId(2, 1), ladderBotId(1, 3)];
    expect(tierWins(2, beaten)).toBe(2);
    expect(bossUnlocked(2, beaten)).toBe(false);
    expect(bossUnlocked(2, [...beaten, ladderBotId(2, 3)])).toBe(true);
  });

  it('монеты: первая победа полностью, повтор — 30 %, босс щедрее, выше — больше', () => {
    const first = ladderCoins({ tier: 0, won: true, firstWin: true, boss: false });
    const again = ladderCoins({ tier: 0, won: true, firstWin: false, boss: false });
    expect(again).toBe(Math.round(first * 0.3));
    expect(ladderCoins({ tier: 0, won: true, firstWin: true, boss: true })).toBeGreaterThan(first);
    expect(ladderCoins({ tier: 6, won: true, firstWin: true, boss: false })).toBeGreaterThan(first);
  });

  it('из профиля читаются только id лестницы', () => {
    expect(readBeaten(['lad_0_1', 'bot_1', 5, null])).toEqual(['lad_0_1']);
    expect(readBeaten('мусор')).toEqual([]);
  });
});
