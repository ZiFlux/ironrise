import { strengthValidity } from '../src/game/anti-fraud';
import { BodyPart, PartMap, partMap } from '../src/game/body-part';
import { scoreCardio, secondsInZone, zoneLowerBound } from '../src/game/cardio';
import { GameConfig as C } from '../src/game/config';
import { FighterSnapshot, seededRandom, simulateDuel } from '../src/game/duel';
import { countsForSession, jointCode, withJointBonus } from '../src/game/joint';
import { power } from '../src/game/progression';
import { currentStreak, maxRestDaysInRow, streakAfterActivity } from '../src/game/streak';
import { applyDailyCap, scoreStrength, StrengthSession, withPlanBonus } from '../src/game/workout';

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

  it('больше 4 подходов не засчитываются', () => {
    const s = scoreStrength(session('db_curl', 12, 90), xpAll(0), 1);
    expect(gainsOf(s).arms).toBe(18 * 4);
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
import { priceOf, SHOP_PRICES, TESTER_ITEMS } from '../src/game/shop';
import { premiumStatus, unverifiedValidityFor, withPremiumCoins } from '../src/game/premium';

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

  it('в магазине 55 вещей, из них 41 платная — как в клиенте', () => {
    const prices = Object.values(SHOP_PRICES);
    expect(prices).toHaveLength(55);
    expect(prices.filter((p) => p > 0)).toHaveLength(41);
  });
});

import { randomBotLook, unpaidItems, wornItems } from '../src/game/looks';

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

import { isStreakAtRisk } from '../src/game/streak';

describe('напоминание о серии', () => {
  it('Пн/Ср/Пт: после тренировки в понедельник под угрозой только четверг', () => {
    const days = [0, 2, 4]; // лимит отдыха 2 дня
    expect(isStreakAtRisk('2026-11-09', '2026-11-11', days)).toBe(false);
    expect(isStreakAtRisk('2026-11-09', '2026-11-12', days)).toBe(true);
    expect(isStreakAtRisk('2026-11-09', '2026-11-13', days)).toBe(false); // уже сгорела
  });
});

import { dailyReminderDue, parseSettings } from '../src/push/settings';

describe('настройки уведомлений', () => {
  it('по умолчанию всё включено, напоминание в 19', () => {
    expect(parseSettings({})).toEqual({
      friend_request: true, friend_accepted: true, attacked: true, streak_risk: true, streakReminderHour: 19,
      daily_tip: true, duels_refreshed: true, morningHour: 9, training_reminder: true,
    });
  });

  it('сохранённое выключение уважается, битые данные — умолчания', () => {
    expect(parseSettings({ attacked: false, streakReminderHour: 21 }).attacked).toBe(false);
    expect(parseSettings({ attacked: false, streakReminderHour: 21 }).streakReminderHour).toBe(21);
    expect(parseSettings({ streakReminderHour: 3 }).streak_risk).toBe(true);
    expect(parseSettings(null).friend_request).toBe(true);
  });
});

describe('дневной потолок опыта', () => {
  const zero = partMap(() => 0);
  const heavy: StrengthSession = {
    startedAt: new Date('2026-11-11T18:00:00Z'),
    finishedAt: new Date('2026-11-11T19:30:00Z'),
    entries: ['bench_press', 'barbell_squat', 'lat_pulldown', 'db_curl'].map((exerciseId) => ({
      exerciseId,
      sets: Array.from({ length: 8 }, () => ({ weight: 30, reps: 8 })),
    })),
  };

  it('не трогает тренировку в пределах потолка', () => {
    const summary = scoreStrength(heavy, zero, 1);
    expect(applyDailyCap(summary, zero, 0)).toBe(summary);
  });

  it('срезает опыт сверх потолка с учётом уже набранного за день', () => {
    const summary = scoreStrength(heavy, zero, 1); // ≈ 4 × 8 × 18
    const before = summary.gains.reduce((s, g) => s + g.xp, 0);
    const capped = applyDailyCap(summary, zero, 400);
    const total = capped.gains.reduce((s, g) => s + g.xp, 0);
    expect(total).toBeLessThanOrEqual(C.dailyXpCap - 400);
    expect(capped.cappedXp).toBe(before - total);
    expect(capped.coins).toBe(Math.round(total * C.coinsPerXp));
  });

  it('после потолка тренировка опыта не даёт', () => {
    const capped = applyDailyCap(scoreStrength(heavy, zero, 1), zero, C.dailyXpCap);
    expect(capped.gains).toEqual([]);
    expect(capped.coins).toBe(0);
  });
});

describe('бонус за тренировку по плану', () => {
  const zero = partMap(() => 0);
  const session: StrengthSession = {
    startedAt: new Date('2026-11-12T18:00:00Z'),
    finishedAt: new Date('2026-11-12T18:40:00Z'),
    entries: [{ exerciseId: 'bench_press', sets: [{ weight: 30, reps: 12 }, { weight: 30, reps: 12 }] }],
  };

  it('+20% монет, опыт тот же', () => {
    const plain = scoreStrength(session, zero, 1);
    const planned = withPlanBonus(plain, true);
    expect(planned.coins).toBe(Math.round(plain.coins * 1.2));
    expect(planned.gains).toEqual(plain.gains);
    expect(withPlanBonus(plain, false)).toBe(plain);
  });
});

import { addWeeks, settleWeek, sundayOf, TOP_TIER, weekOutcome } from '../src/game/league';

describe('лиги', () => {
  it('первые двое поднимаются, последние двое опускаются', () => {
    expect(weekOutcome(1, 8, 3)).toBe('up');
    expect(weekOutcome(2, 8, 3)).toBe('up');
    expect(weekOutcome(4, 8, 3)).toBe('stay');
    expect(weekOutcome(7, 8, 3)).toBe('down');
  });

  it('неделя без тренировок — минус лига, даже на первом месте', () => {
    expect(weekOutcome(1, 8, 0)).toBe('down');
  });

  it('лига не выходит за бронзу и золото', () => {
    expect(settleWeek({ week: '2026-11-02', tier: 0, rank: 8, size: 8, trainedDays: 3 }).tierAfter).toBe(0);
    expect(settleWeek({ week: '2026-11-02', tier: TOP_TIER, rank: 1, size: 8, trainedDays: 3 }).tierAfter).toBe(TOP_TIER);
    expect(settleWeek({ week: '2026-11-02', tier: 0, rank: 1, size: 8, trainedDays: 3 })).toMatchObject({
      outcome: 'up',
      tierBefore: 0,
      tierAfter: 1,
    });
  });

  it('недели считаются с понедельника по воскресенье', () => {
    expect(sundayOf('2026-11-09')).toBe('2026-11-15');
    expect(addWeeks('2026-11-09', 1)).toBe('2026-11-16');
  });
});

import { nextScheduleChangeAt } from '../src/game/schedule';

describe('смена графика', () => {
  const now = new Date('2026-11-12T12:00:00Z');
  it('первая смена — сразу', () => {
    expect(nextScheduleChangeAt(null, now)).toBeNull();
  });
  it('следующая — через 7 дней', () => {
    expect(nextScheduleChangeAt(new Date('2026-11-10T12:00:00Z'), now)?.toISOString()).toBe('2026-11-17T12:00:00.000Z');
    expect(nextScheduleChangeAt(new Date('2026-11-05T11:00:00Z'), now)).toBeNull();
  });
});

import { DUEL_EVENTS, botNames } from '../src/game/duel-flavor';

describe('колорит дуэлей', () => {
  const fighterOf = (id: string, level: number): FighterSnapshot => ({
    id,
    name: id,
    levels: partMap(() => level),
    streakDays: 0,
  });

  it('события случаются примерно в 12% ходов, все трёх видов', () => {
    let turns = 0;
    const seen = new Map<string, number>();
    for (let s = 0; s < 3000; s++) {
      for (const h of simulateDuel(fighterOf('a', 8), fighterOf('b', 8), s).log) {
        turns++;
        if (h.event) seen.set(h.event.id, (seen.get(h.event.id) ?? 0) + 1);
      }
    }
    const events = [...seen.values()].reduce((a, b) => a + b, 0);
    expect(events / turns).toBeGreaterThan(0.1);
    expect(events / turns).toBeLessThan(0.14);
    expect(new Set(DUEL_EVENTS.filter((e) => seen.has(e.id)).map((e) => e.kind))).toEqual(new Set(['heal', 'boost', 'skip']));
  });

  it('лечение не поднимает здоровье выше максимума, пропуск хода не наносит урон', () => {
    for (let s = 0; s < 2000; s++) {
      const r = simulateDuel(fighterOf('a', 6), fighterOf('b', 6), s);
      for (const h of r.log) {
        if (h.kind === 'skip') expect(h.damage).toBe(0);
        if (h.event?.selfHpAfter !== undefined) {
          expect(h.event.selfHpAfter).toBeLessThanOrEqual(h.byAttacker ? r.powerA : r.powerD);
        }
      }
    }
  });

  it('у ботов разные имена с согласованным родом и образ из вещей магазина', () => {
    const bots = botsForDay({ levels: partMap(() => 5), streakDays: 3 }, '2026-11-12');
    expect(new Set(bots.map((b) => b.name)).size).toBe(4);
    for (const b of bots) {
      expect(wornItems(b.appearance)).not.toBeNull();
      expect(b.appearance.sex).toBe(b.isFemale ? 'female' : 'male');
      if (b.isFemale) expect(b.name).not.toMatch(/ый |ой /);
    }
    const rnd = seededRandom(1);
    const names = botNames(Array(40).fill(false), rnd);
    expect(new Set(names).size).toBe(40);
  });
});

describe('совместная тренировка', () => {
  const xpBefore = { chest: 0, back: 0, arms: 0, legs: 0, core: 0, cardio: 0 };
  const base = {
    durationSec: 1800,
    totalSets: 9,
    validity: 1,
    gains: [{ part: 'chest' as const, xp: 200, levelBefore: 1, levelAfter: 3, xpAfter: 200, wasLagging: false }],
    coins: 40,
  };

  it('+25% опыта и монет с партнёрами, без партнёров — без изменений', () => {
    const joint = withJointBonus(base, xpBefore, ['Стас']);
    expect(joint.gains[0].xp).toBe(250);
    expect(joint.coins).toBe(50);
    expect(joint.joint).toEqual({ partners: ['Стас'], bonusXp: 50 });
    expect(withJointBonus(base, xpBefore, [])).toBe(base);
  });

  it('дневной потолок действует и для совместной', () => {
    const big = { ...base, gains: [{ ...base.gains[0], xp: 560 }] };
    const capped = applyDailyCap(withJointBonus(big, xpBefore, ['Стас']), xpBefore, 0);
    expect(capped.gains.reduce((s, g) => s + g.xp, 0)).toBeLessThanOrEqual(C.dailyXpCap);
  });

  it('засчитывается только тренировка внутри сессии и после входа', () => {
    const s = { joinedAt: new Date('2026-11-12T10:00:00Z'), endsAt: new Date('2026-11-12T14:00:00Z') };
    const w = (from: string, to: string) => ({ startedAt: new Date(from), finishedAt: new Date(to) });
    expect(countsForSession(w('2026-11-12T09:50:00Z', '2026-11-12T11:00:00Z'), s)).toBe(true);
    expect(countsForSession(w('2026-11-12T08:00:00Z', '2026-11-12T09:00:00Z'), s)).toBe(false);
    expect(countsForSession(w('2026-11-12T15:00:00Z', '2026-11-12T16:00:00Z'), s)).toBe(false);
    expect(jointCode(() => 0)).toBe('100000');
    expect(jointCode(() => 0.999999)).toMatch(/^\d{6}$/);
  });
});

describe('премиум и тестеры', () => {
  const look = {
    sex: 'male', skin: 'iron', hair: 'short', hairColor: 0xff26262a, top: 'none', topColor: 0xff8b5cf6,
    bottom: 'shorts', bottomColor: 0xff1f1f22, sneakersColor: null, accessories: ['betaCap'],
  };

  it('вещи тестеров не продаются и носятся только выданными', () => {
    expect(priceOf('acc_beta_cap')).toBeUndefined();
    expect(unpaidItems(look, new Set())).toEqual(['tc_beta', 'acc_beta_cap']);
    expect(unpaidItems(look, new Set(TESTER_ITEMS))).toEqual([]);
  });

  it('боты не носят вещи тестеров', () => {
    for (let s = 1; s < 300; s++) {
      const worn = wornItems(randomBotLook(s % 2 === 0, seededRandom(s)))!;
      expect(worn.some((id) => TESTER_ITEMS.includes(id))).toBe(false);
    }
  });

  it('статус премиума: тестер навсегда, подписка до даты', () => {
    const now = new Date('2026-11-12T12:00:00Z');
    expect(premiumStatus({ isTester: true, premiumUntil: null }, now)).toMatchObject({ active: true, source: 'tester' });
    expect(premiumStatus({ isTester: false, premiumUntil: new Date('2026-12-01') }, now).source).toBe('subscription');
    expect(premiumStatus({ isTester: false, premiumUntil: new Date('2026-11-01') }, now).active).toBe(false);
  });

  it('у тестера без часов нет штрафа, у остальных V = 0,5', () => {
    const args = { startedAt: new Date(0), finishedAt: new Date(3600_000), totalSets: 12, pulse: [] };
    expect(strengthValidity({ ...args, unverified: unverifiedValidityFor(true) })).toBe(1);
    expect(strengthValidity({ ...args, unverified: unverifiedValidityFor(false) })).toBe(0.5);
  });

  it('премиум: +25% монет, опыт тот же', () => {
    const s = { durationSec: 1, totalSets: 1, validity: 1, gains: [], coins: 40 };
    expect(withPremiumCoins(s, true).coins).toBe(50);
    expect(withPremiumCoins(s, false).coins).toBe(40);
  });
});

describe('утренние уведомления', () => {
  const base = { enabled: true, sentDay: null, today: '2026-11-12', hour: 9, atHour: 9, lastActiveDay: '2026-11-10' };
  it('шлём в свой час раз в день активным игрокам', () => {
    expect(dailyReminderDue(base)).toBe(true);
    expect(dailyReminderDue({ ...base, hour: 8 })).toBe(false);
    expect(dailyReminderDue({ ...base, sentDay: '2026-11-12' })).toBe(false);
    expect(dailyReminderDue({ ...base, enabled: false })).toBe(false);
  });
  it('не беспокоим тех, кто не тренировался больше двух недель', () => {
    expect(dailyReminderDue({ ...base, lastActiveDay: '2026-10-29' })).toBe(true);
    expect(dailyReminderDue({ ...base, lastActiveDay: '2026-10-28' })).toBe(false);
    expect(dailyReminderDue({ ...base, lastActiveDay: null })).toBe(false);
  });
  it('настройки по умолчанию включают оба напоминания на 9:00', () => {
    expect(parseSettings({})).toMatchObject({ daily_tip: true, duels_refreshed: true, morningHour: 9 });
  });
});

import { CREATOR_ITEMS, creatorItemsToGrant, creatorOpen } from '../src/game/start-look';

describe('стартовый образ', () => {
  const look = {
    sex: 'female', skin: 'tan', hair: 'long', hairColor: 0xffd9b66e, top: 'tee', topColor: 0xffe8e8e8,
    bottom: 'leggings', bottomColor: 0xff1e2a4a, sneakersColor: 0xffededed, accessories: [], accessoryColor: 0xffc6ff3d,
    build: 'solid',
  };

  it('окно открыто 14 дней и до фиксации', () => {
    const until = new Date('2026-11-26T00:00:00Z');
    expect(creatorOpen({ startLockedAt: null, startLookUntil: until }, new Date('2026-11-20T00:00:00Z'))).toBe(true);
    expect(creatorOpen({ startLockedAt: null, startLookUntil: until }, new Date('2026-11-27T00:00:00Z'))).toBe(false);
    expect(creatorOpen({ startLockedAt: new Date(), startLookUntil: until }, new Date('2026-11-20T00:00:00Z'))).toBe(false);
  });

  it('при фиксации выдаются только надетые вещи редактора', () => {
    expect(creatorItemsToGrant(look, new Set(['top_tee']))).toEqual([
      'hair_long', 'hc_blond', 'tc_white', 'bottom_leggings', 'bc_navy', 'sn_white',
    ]);
  });

  it('стартовый образ приложения (майка, тёмно-синий, белые кроссовки) проходит регистрацию', () => {
    const starter = { ...look, sex: 'male', hair: 'short', top: 'tank', topColor: 0xff1e2a4a, bottom: 'shorts' };
    expect(unpaidItems(starter, CREATOR_ITEMS)).toEqual([]);
    expect(unpaidItems({ ...starter, accessories: ['cap'] }, CREATOR_ITEMS)).toEqual(['acc_cap']);
  });

  it('аксессуары, премиум и вещи тестеров в редактор не входят', () => {
    for (const id of ['acc_cap', 'acc_gold_chain', 'tc_gold', 'sn_gold', 'top_beta_tee', 'acc_beta_cap']) {
      expect(CREATOR_ITEMS.has(id)).toBe(false);
    }
    expect(creatorItemsToGrant({ ...look, accessories: ['cap'] }, new Set())).not.toContain('acc_cap');
  });

  it('неизвестное телосложение — образ некорректен', () => {
    expect(wornItems({ ...look, build: 'huge' })).toBeNull();
    expect(wornItems(look)).not.toBeNull();
  });
});

import { addMusclePoints, EXERCISE_MUSCLES, MUSCLES, musclePointsOf } from '../src/game/muscles';
import { EXERCISES } from '../src/game/exercises';

describe('мышцы', () => {
  it('у каждого упражнения есть мышцы, доли в сумме 1', () => {
    for (const e of EXERCISES) {
      const shares = Object.values(EXERCISE_MUSCLES[e.id] ?? {});
      expect(shares.length).toBeGreaterThan(0);
      expect(shares.reduce((a, b) => a + b, 0)).toBeCloseTo(1);
    }
    for (const m of Object.values(EXERCISE_MUSCLES).flatMap((x) => Object.keys(x))) {
      expect(MUSCLES).toContain(m);
    }
  });

  it('очки: подходы × доля × достоверность, копятся', () => {
    const p = musclePointsOf([{ exerciseId: 'db_curl', sets: [1, 2, 3] }], 0.5);
    expect(p.biceps).toBeCloseTo(1.2);
    expect(p.forearms).toBeCloseTo(0.3);
    expect(addMusclePoints(p, p).biceps).toBeCloseTo(2.4);
  });
});

import { NicknameSchema, isReservedNickname, nextNicknameChangeAt, nicknameKey } from '../src/game/nickname';

describe('ники', () => {
  it('регистр, пробелы, «_» и похожая латиница дают один ключ', () => {
    const key = nicknameKey('Юра');
    for (const n of ['юра', 'ЮРА', 'Ю ра', 'Ю_ра', 'Юpa', 'ЮPA']) expect(nicknameKey(n)).toBe(key);
    expect(nicknameKey('Genka')).toBe(nicknameKey('genka'));
    expect(nicknameKey('Ёжик')).toBe(nicknameKey('ежик'));
    expect(nicknameKey('Юля')).not.toBe(key);
  });

  it('запрещённые ники ловятся и в маскировке', () => {
    for (const n of ['IronRise', 'iron rise', 'Admin_Юра', 'Поддержка', 'АДМИН']) expect(isReservedNickname(n)).toBe(true);
    expect(isReservedNickname('Genka')).toBe(false);
  });

  it('ник: 3–20 знаков, буквы, цифры, «_», пробелы сжимаются', () => {
    expect(NicknameSchema.parse('  Юра   Иванов ')).toBe('Юра Иванов');
    expect(NicknameSchema.safeParse('Юр').success).toBe(false);
    expect(NicknameSchema.safeParse('Юра!').success).toBe(false);
  });

  it('смена раз в 30 дней, первая — сразу', () => {
    const now = new Date('2026-11-12T12:00:00Z');
    expect(nextNicknameChangeAt(null, now)).toBeNull();
    expect(nextNicknameChangeAt(new Date('2026-11-01T12:00:00Z'), now)).toEqual(new Date('2026-12-01T12:00:00Z'));
    expect(nextNicknameChangeAt(new Date('2026-10-01T12:00:00Z'), now)).toBeNull();
  });
});

import { STREAK_ITEMS, dailyStreakCoins, milestoneFor, streakReward } from '../src/game/streak-rewards';
import { EXCLUSIVE_ITEMS } from '../src/game/shop';

describe('награды за серию', () => {
  it('продление без рубежа — только монеты за день, растут с серией до 10', () => {
    expect(streakReward(1, 2)).toMatchObject({ coins: dailyStreakCoins(2), milestones: [] });
    expect(dailyStreakCoins(2)).toBeLessThan(dailyStreakCoins(20));
    expect(dailyStreakCoins(100)).toBe(10);
  });

  it('пройденные рубежи суммируются, даже если серия прыгнула через отдых', () => {
    const r = streakReward(4, 7)!;
    expect(r.milestones).toEqual([5, 7]);
    expect(r.boosters.xp).toBe(1);
    expect(r.items).toEqual(['sn_streak']);
  });

  it('не растёт — награды нет; после 60 — рубеж каждые 30 дней', () => {
    expect(streakReward(5, 5)).toBeNull();
    expect(milestoneFor(90)).toBeDefined();
    expect(milestoneFor(91)).toBeUndefined();
  });

  it('вещи за серию — эксклюзивы, их нельзя купить', () => {
    for (const id of STREAK_ITEMS) expect(EXCLUSIVE_ITEMS.has(id)).toBe(true);
  });
});

import { stepsXp } from '../src/game/steps';

describe('шаги в день отдыха', () => {
  it('3 опыта за тысячу шагов, не больше 30', () => {
    expect(stepsXp(999)).toBe(0);
    expect(stepsXp(4500)).toBe(12);
    expect(stepsXp(40000)).toBe(30);
  });
});

import { habitHour } from '../src/push/settings';

describe('напоминание по привычке', () => {
  it('медиана часа начала, нужно минимум 3 тренировки', () => {
    expect(habitHour([18, 19])).toBeNull();
    expect(habitHour([18, 19, 20, 7, 19])).toBe(19);
  });
});

import { heroMilestonesDue, mondayOfDay, pairStreak } from '../src/game/social-progress';

describe('вехи героя и напарники', () => {
  it('вехи 5/10/20 выдаются один раз, пропущенные — разом', () => {
    expect(heroMilestonesDue(0, 4)).toEqual([]);
    expect(heroMilestonesDue(0, 11).map((m) => m.level)).toEqual([5, 10]);
    expect(heroMilestonesDue(10, 11)).toEqual([]);
  });

  it('общая серия — недели, где у обоих по 2 тренировки; текущая не сжигает', () => {
    const since = '2026-10-19';
    const a = ['2026-10-20', '2026-10-22', '2026-10-27', '2026-10-29', '2026-11-03', '2026-11-05'];
    const b = ['2026-10-21', '2026-10-23', '2026-10-28', '2026-10-30', '2026-11-04'];
    // Неделя 2 ноября у b — одна тренировка: серия считается с конца, обрывается на ней.
    expect(pairStreak(a, b, since, '2026-11-10').weeks).toBe(0);
    expect(pairStreak(a, b, since, '2026-11-02').weeks).toBe(2);
    expect(pairStreak(a, b, since, '2026-11-04').thisWeek).toEqual({ a: 2, b: 1 });
    expect(mondayOfDay('2026-11-13')).toBe('2026-11-09');
  });
});
