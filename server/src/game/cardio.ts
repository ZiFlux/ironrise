import { PartMap } from './body-part';
import { GameConfig as C } from './config';
import { hasEnoughPulse, PulseSample } from './anti-fraud';
import { laggingParts, levels } from './progression';
import { buildSummary, WorkoutSummary } from './workout';

/** Нижняя граница зоны 2: пульс покоя + 60% резерва (Карвонен). */
export const zoneLowerBound = (
  resting: number = C.defaultRestingHeartRate,
  max: number = C.defaultMaxHeartRate,
): number => Math.round(resting + C.cardioZoneReserveShare * (max - resting));

/** Секунды в зоне. Пропуски в данных длиннее 15 с не считаются. */
export const secondsInZone = (pulse: PulseSample[], lowerBound: number): number => {
  let total = 0;
  for (let i = 1; i < pulse.length; i++) {
    const gap = Math.floor((pulse[i].at.getTime() - pulse[i - 1].at.getTime()) / 1000);
    if (pulse[i - 1].bpm >= lowerBound) total += Math.min(gap, 15);
  }
  return total;
};

export interface CardioSummary extends WorkoutSummary {
  zoneMinutes: number;
}

/**
 * Опыт кардио (PLAN 4.1): минуты в зоне — полностью, ниже зоны и без пульса — с V = 0,5.
 * Так часы никогда не уменьшают опыт. Больше 2 часов не считается.
 */
export const scoreCardio = (args: {
  startedAt: Date;
  finishedAt: Date;
  pulse: PulseSample[];
  xpBefore: PartMap<number>;
  restingHeartRate?: number;
  maxHeartRate?: number;
  /** V без часов: 0,5 по умолчанию, у тестеров 1 (src/game/premium.ts). */
  unverified?: number;
}): CardioSummary => {
  const unverified = args.unverified ?? C.unverifiedValidity;
  const durationSec = Math.round((args.finishedAt.getTime() - args.startedAt.getTime()) / 1000);
  const totalMin = Math.min(durationSec / 60, C.cardioMaxMinutes);
  const verified = hasEnoughPulse(args.pulse, durationSec);
  const zone = zoneLowerBound(args.restingHeartRate, args.maxHeartRate);
  const zoneMin = verified ? Math.min(secondsInZone(args.pulse, zone) / 60, totalMin) : 0;
  const effectiveMin = verified
    ? zoneMin + (totalMin - zoneMin) * C.unverifiedValidity
    : totalMin * unverified;

  const lagging = new Set(laggingParts(levels(args.xpBefore)));
  const bonus = lagging.has('cardio') ? C.laggingXpMultiplier : 1;
  const summary = buildSummary({ cardio: C.cardioXpPerMinute * effectiveMin * bonus }, args.xpBefore, lagging, {
    durationSec,
    totalSets: 0,
    validity: verified ? 1 : unverified,
  });
  return { ...summary, zoneMinutes: Math.round(zoneMin) };
};
