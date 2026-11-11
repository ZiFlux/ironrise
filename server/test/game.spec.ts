import { strengthValidity } from '../src/game/anti-fraud';
import { BodyPart, PartMap, partMap } from '../src/game/body-part';
import { scoreCardio, secondsInZone, zoneLowerBound } from '../src/game/cardio';
import { GameConfig as C } from '../src/game/config';
import { FighterSnapshot, seededRandom, simulateDuel } from '../src/game/duel';
import { power } from '../src/game/progression';
import { currentStreak, maxRestDaysInRow, streakAfterActivity } from '../src/game/streak';
import { scoreStrength, StrengthSession } from '../src/game/workout';

// Те же сценарии, что в app/test/*.dart: формулы клиента и сервера должны совпадать.

const xpAll = (v: number): PartMap<number> => partMap(() => v);
const start = new Date('2026-11-11T19:00:00Z');
const at = (min: number) => new Date(start.getTime() + min * 60_000);

const session = (exerciseId: string, sets: number, minutes = 40): StrengthSession => ({
  startedAt: start,
  finishedAt: at(minutes),
  entries: [{ exerciseId, sets: Array.from({ length: sets }, () => ({ weight: 30, reps: 10 })) }],
});

const gainsOf = (s: ReturnType<typeof scoreStrength>) =>
  Object.fromEntries(s.gains.map((g) => [g.part, g.xp])) as Partial<Record<BodyPart, number>>;

describe('опыт за силовую тренировку', () => {
  it('жим лёжа делит опыт между грудью и руками', () => {
    const s = scoreStrength(session('bench_press', 3), xpAll(0), 1);
    expect(gainsOf(s)).toEqual({ chest: 38, arms: 16 });
    expect(s.durationSec).toBe(40 * 60);
    expect(s.coins).toBe(11);
  });

  it('отстающая часть ×1,5, без часов ×0,5', () => {
    const xp = { ...xpAll(300), legs: 0 };
    const s = scoreStrength(session('leg_press', 2), xp, C.unverifiedValidity);
    expect(s.gains[0]).toMatchObject({ part: 'legs', xp: 27, wasLagging: true });
  });

  it('больше 8 подходов не засчитываются', () => {
    const s = scoreStrength(session('db_curl', 12, 90), xpAll(0), 1);
    expect(gainsOf(s).arms).toBe(18 * 8);
  });

  it('неизвестное упражнение — ошибка, а не тихий ноль', () => {
    expect(() => scoreStrength(session('teleport', 1), xpAll(0), 1)).toThrow('teleport');
  });
});

describe('антифрод', () => {
  it('без пульса V = 0,5, нереальный темп ещё ×0,3', () => {
    expect(strengthValidity({ startedAt: start, finishedAt: at(40), totalSets: 10, pulse: [] })).toBe(0.5);
    expect(strengthValidity({ startedAt: start, finishedAt: at(5), totalSets: 20, pulse: [] })).toBeCloseTo(0.15);
  });

  it('живой пульс с циклами подход–отдых даёт V = 1', () => {
    const pulse = Array.from({ length: 240 }, (_, i) => ({
      at: new Date(start.getTime() + i * 10_000),
      bpm: i % 12 < 4 ? 140 : 105,
    }));
    expect(strengthValidity({ startedAt: start, finishedAt: at(40), totalSets: 12, pulse })).toBe(1);
  });
});

describe('серия', () => {
  it('отдых в пределах формата засчитывается, лишний день сбрасывает', () => {
    const base = { currentStreak: 3, lastActiveDay: '2026-11-09', maxRestDays: 2 };
    expect(streakAfterActivity({ ...base, today: '2026-11-11' })).toBe(5);
    expect(streakAfterActivity({ ...base, today: '2026-11-13' })).toBe(1);
    expect(streakAfterActivity({ ...base, today: '2026-11-09' })).toBe(3);
  });

  it('серия на сегодня сгорает после лишнего дня отдыха', () => {
    const base = { streakDays: 5, lastActiveDay: '2026-11-09', maxRestDays: 2 };
    expect(currentStreak({ ...base, today: '2026-11-12' })).toBe(5);
    expect(currentStreak({ ...base, today: '2026-11-13' })).toBe(0);
  });

  it('допустимый отдых по графику', () => {
    expect(maxRestDaysInRow([0, 2, 4])).toBe(2);
    expect(maxRestDaysInRow([0, 1, 2, 3, 4])).toBe(2);
    expect(maxRestDaysInRow([0, 1, 2, 3, 4, 5])).toBe(1);
  });
});

describe('кардио', () => {
  const pulse = (minutes: number, bpm: number) =>
    Array.from({ length: (minutes * 60) / 5 + 1 }, (_, i) => ({ at: new Date(start.getTime() + i * 5000), bpm }));

  it('граница зоны 2 = 142 по умолчанию', () => {
    expect(zoneLowerBound()).toBe(142);
    expect(zoneLowerBound(58, 190)).toBe(137);
  });

  it('30 минут в зоне = 180 опыта, без пульса — 90', () => {
    const inZone = scoreCardio({ startedAt: start, finishedAt: at(30), pulse: pulse(30, 150), xpBefore: xpAll(0) });
    expect(inZone.gains[0]).toMatchObject({ part: 'cardio', xp: 180 });
    expect(inZone.zoneMinutes).toBe(30);
    const blind = scoreCardio({ startedAt: start, finishedAt: at(30), pulse: [], xpBefore: xpAll(0) });
    expect(blind.gains[0].xp).toBe(90);
  });

  it('провалы в данных не идут в зону', () => {
    expect(secondsInZone([{ at: start, bpm: 150 }, { at: at(10), bpm: 150 }], 142)).toBe(15);
  });
});

describe('дуэль', () => {
  const fighter = (id: string, level: number): FighterSnapshot => ({
    id,
    name: id,
    levels: partMap(() => level),
    streakDays: 0,
  });

  const winRate = (a: FighterSnapshot, d: FighterSnapshot, n = 4000) => {
    let wins = 0;
    for (let s = 0; s < n; s++) if (simulateDuel(a, d, s).attackerWon) wins++;
    return wins / n;
  };

  it('генератор детерминирован и равномерен на [0; 1)', () => {
    const a = seededRandom(42);
    const b = seededRandom(42);
    const xs = Array.from({ length: 1000 }, () => a());
    expect(xs).toEqual(Array.from({ length: 1000 }, () => b()));
    expect(Math.min(...xs)).toBeGreaterThanOrEqual(0);
    expect(Math.max(...xs)).toBeLessThan(1);
  });

  it('равные силы ≈ 50%, перевес 20% ≈ 85% (ТЗ 4.5)', () => {
    expect(winRate(fighter('a', 10), fighter('b', 10))).toBeCloseTo(0.5, 1);
    const strong = fighter('a', 12);
    const weak = fighter('b', 10);
    expect(power(strong.levels, 0) / power(weak.levels, 0)).toBeCloseTo(1.2, 2);
    const rate = winRate(strong, weak);
    expect(rate).toBeGreaterThanOrEqual(0.78);
    expect(rate).toBeLessThanOrEqual(0.92);
  });

  it('один seed — один и тот же лог, 6–10 раундов', () => {
    const r1 = simulateDuel(fighter('a', 5), fighter('b', 6), 7);
    const r2 = simulateDuel(fighter('a', 5), fighter('b', 6), 7);
    expect(r1).toEqual(r2);
    expect(r1.log.length / 2).toBeGreaterThanOrEqual(6);
    expect(r1.log.length / 2).toBeLessThanOrEqual(10);
  });
});

import { botsForDay, mondayOf, weeklyLeague } from '../src/game/bots';
import { SHOP_PRICES } from '../src/game/shop';

describe('боты, лига, магазин', () => {
  const player = { levels: partMap(() => 5), streakDays: 4 };

  it('боты дня стабильны, их 4, от слабого к сильному', () => {
    const a = botsForDay(player, '2026-11-11');
    expect(a).toEqual(botsForDay(player, '2026-11-11'));
    expect(a).toHaveLength(4);
    expect(power(a[0].levels, 4)).toBeLessThan(power(a[3].levels, 4));
    expect(botsForDay(player, '2026-11-12')[0].id).not.toBe(a[0].id);
  });

  it('понедельник недели', () => {
    expect(mondayOf('2026-11-11')).toBe('2026-11-09');
    expect(mondayOf('2026-11-09')).toBe('2026-11-09');
    expect(mondayOf('2026-11-15')).toBe('2026-11-09');
  });

  it('лига: 8 участников, по убыванию, очки ботов растут к концу недели', () => {
    const mon = weeklyLeague({ today: '2026-11-09', playerName: 'me', playerPoints: 0 });
    const sun = weeklyLeague({ today: '2026-11-15', playerName: 'me', playerPoints: 0 });
    expect(sun).toHaveLength(8);
    const sum = (xs: typeof mon) => xs.reduce((s, e) => s + e.points, 0);
    expect(sum(sun)).toBeGreaterThan(sum(mon));
    for (let i = 1; i < sun.length; i++) expect(sun[i - 1].points).toBeGreaterThanOrEqual(sun[i].points);
  });

  it('в магазине 41 вещь, из них 27 платных — как в клиенте', () => {
    const prices = Object.values(SHOP_PRICES);
    expect(prices).toHaveLength(41);
    expect(prices.filter((p) => p > 0)).toHaveLength(27);
  });
});

import { unpaidItems, wornItems } from '../src/game/looks';

describe('образ и купленные вещи', () => {
  // AvatarLook.starter(male).toJson() из клиента.
  const starter = {
    sex: 'male', skin: 'iron', hair: 'short', hairColor: 0xff26262a, top: 'none', topColor: 0xff1f1f22,
    bottom: 'shorts', bottomColor: 0xff1f1f22, sneakersColor: null, accessories: [], accessoryColor: 0xffc6ff3d,
  };

  it('стартовый образ — только бесплатные вещи', () => {
    expect(unpaidItems(starter, new Set())).toEqual([]);
  });

  it('некупленная футболка и повязка видны, купленные — нет', () => {
    const look = { ...starter, top: 'tee', accessories: ['headband'] };
    expect(unpaidItems(look, new Set())).toEqual(['top_tee', 'acc_headband']);
    expect(unpaidItems(look, new Set(['top_tee', 'acc_headband']))).toEqual([]);
  });

  it('цвет, которого нет в магазине, или чужой пол — образ некорректен', () => {
    expect(wornItems({ ...starter, topColor: 0xff123456 })).toBeNull();
    expect(wornItems({ ...starter, sex: 'robot' })).toBeNull();
    expect(wornItems({ sex: 'male' })).toBeNull();
  });
});
