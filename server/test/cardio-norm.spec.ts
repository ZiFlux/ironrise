import { scoreCardio, zoneLowerBound } from '../src/game/cardio';
import { cardioFloor, cardioNorm, historyByActivity, workPulse } from '../src/game/cardio-norm';
import { PulseSummary } from '../src/game/pulse-summary';

const summary = (perMinute: number[]): PulseSummary => ({
  n: perMinute.length * 12,
  avg: 0,
  min: 0,
  max: 0,
  perMinute,
});

describe('личная норма пульса кардио', () => {
  it('рабочий пульс — медиана без первых 3 минут разгона; мало минут — нет', () => {
    expect(workPulse(summary([90, 100, 110, 125, 128, 130, 126, 129, 131, 127, 128]))).toBe(128);
    expect(workPulse(summary([90, 100, 110, 125, 128]))).toBeNull();
    expect(workPulse(null)).toBeNull();
  });

  it('первые 2 сессии вида — калибровка с нижней границы (покой + 35% резерва)', () => {
    const n = cardioNorm([128], 60, 190);
    expect(n).toEqual({ bound: cardioFloor(60, 190), calibrating: true, sessions: 1 });
    expect(n.bound).toBe(106);
  });

  it('ходьба на 130: норма ~120 вместо общих 138', () => {
    const n = cardioNorm([130, 128, 132], 60, 190);
    expect(n.calibrating).toBe(false);
    expect(n.bound).toBe(Math.round(0.92 * 130));
    expect(n.bound).toBeLessThan(zoneLowerBound(60, 190));
  });

  it('норма не ниже нижней границы и не выше общего порога', () => {
    expect(cardioNorm([95, 96], 60, 190).bound).toBe(cardioFloor(60, 190));
    expect(cardioNorm([175, 178], 60, 190).bound).toBe(zoneLowerBound(60, 190));
  });

  it('история по видам: только годные сессии, свой вид', () => {
    const long = summary([100, 110, 120, ...Array(10).fill(130)]);
    const h = historyByActivity([
      { payload: { activity: 'walk' }, pulse: long },
      { payload: { activity: 'walk' }, pulse: { n: 0 } },
      { payload: { activity: 'run' }, pulse: long },
      { payload: { activity: 'swim' }, pulse: long },
    ]);
    expect(h.walk).toEqual([130]);
    expect(h.run).toEqual([130]);
    expect(h.bike).toEqual([]);
  });

  it('по личной норме минуты на 125 идут полностью', () => {
    const start = new Date('2026-11-27T10:00:00Z');
    const pulse = Array.from({ length: 30 * 6 }, (_, i) => ({
      at: new Date(start.getTime() + i * 10_000),
      bpm: 125,
    }));
    const finishedAt = new Date(start.getTime() + 30 * 60_000);
    const xpBefore = { chest: 0, back: 0, arms: 0, legs: 0, core: 0, cardio: 0 };
    const general = scoreCardio({ startedAt: start, finishedAt, pulse, xpBefore, restingHeartRate: 60, maxHeartRate: 190 });
    const personal = scoreCardio({
      startedAt: start,
      finishedAt,
      pulse,
      xpBefore,
      restingHeartRate: 60,
      maxHeartRate: 190,
      zoneBound: 120,
      calibrating: false,
    });
    expect(general.zoneMinutes).toBe(0);
    expect(personal.zoneMinutes).toBe(30);
    expect(personal.zoneBound).toBe(120);
    expect(personal.calibrating).toBe(false);
  });
});
