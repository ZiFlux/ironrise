import { settleWeek, tierInWeek, WeekSettlement } from '../src/game/league';

describe('лига недели: состав той недели, а не текущий', () => {
  const week = '2026-11-16';

  it('запись за неделю важнее текущего уровня', () => {
    expect(tierInWeek({ leagueTier: 3, leagueWeek: '2026-11-23', leagueLast: null }, 1, week)).toBe(1);
  });

  it('ещё не подводил неделю — текущий уровень и есть уровень той недели', () => {
    expect(tierInWeek({ leagueTier: 2, leagueWeek: week, leagueLast: null }, undefined, week)).toBe(2);
  });

  it('уже подведён и поднялся — в той неделе он был в лиге до подъёма', () => {
    const last: WeekSettlement = settleWeek({ week, tier: 1, rank: 1, size: 10, trainedDays: 3 });
    expect(last.tierAfter).toBe(2);
    expect(tierInWeek({ leagueTier: 2, leagueWeek: '2026-11-23', leagueLast: last }, undefined, week)).toBe(1);
  });

  it('последние места опускаются, даже если первые уже поднялись', () => {
    // Таблица той недели неизменна: 10 игроков, последнее место — вниз.
    expect(settleWeek({ week, tier: 1, rank: 10, size: 10, trainedDays: 2 }).outcome).toBe('down');
    expect(settleWeek({ week, tier: 1, rank: 5, size: 10, trainedDays: 2 }).outcome).toBe('stay');
  });
});
