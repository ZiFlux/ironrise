import { GameConfig as C } from './config';

export interface PulseSample {
  at: Date;
  bpm: number;
}

const seconds = (from: Date, to: Date) => (to.getTime() - from.getTime()) / 1000;

/** Пульс покрывает достаточную долю тренировки. */
export const hasEnoughPulse = (pulse: PulseSample[], durationSec: number): boolean => {
  if (pulse.length < 2 || durationSec <= 0) return false;
  return seconds(pulse[0].at, pulse[pulse.length - 1].at) / durationSec >= C.minPulseCoverage;
};

const pulseFactor = (pulse: PulseSample[], restingHeartRate: number): number => {
  const values = pulse.map((s) => s.bpm);
  const mean = values.reduce((a, b) => a + b, 0) / values.length;
  const spread = Math.sqrt(values.reduce((a, v) => a + (v - mean) ** 2, 0) / values.length);
  let factor = 1;
  if (mean < restingHeartRate + C.minPulseAboveRest) factor *= 0.3;
  if (spread < C.minPulseSpread) factor *= 0.6;
  return factor;
};

/**
 * Коэффициент достоверности V ∈ [0; 1] для силовой тренировки (ТЗ 4.4).
 * Без пульса — 0,5; низкий или ровный пульс и нереальный темп подходов снижают V.
 */
export const strengthValidity = (args: {
  startedAt: Date;
  finishedAt: Date;
  totalSets: number;
  pulse: PulseSample[];
  restingHeartRate?: number;
}): number => {
  const duration = seconds(args.startedAt, args.finishedAt);
  const rest = args.restingHeartRate ?? C.defaultRestingHeartRate;
  const base = hasEnoughPulse(args.pulse, duration) ? pulseFactor(args.pulse, rest) : C.unverifiedValidity;
  const pace = duration < C.minSecondsPerSet * args.totalSets ? 0.3 : 1;
  return base * pace;
};
