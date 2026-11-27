import { zoneLowerBound } from './cardio';
import { GameConfig as C } from './config';
import { PulseSummary } from './pulse-summary';

/**
 * Личная норма пульса для кардио (27.11.2026). Общий порог зоны 2 (покой + 60%
 * резерва) честен для бега, но на быстрой ходьбе или велотренажёре многие до
 * него не дотягивают, хотя занимаются всерьёз. Поэтому:
 * - первые сессии каждого вида — калибровка: засчитываются минуты от нижней
 *   границы (покой + 35% резерва — уже работа, а не прогулка);
 * - дальше — личная норма вида: 92% обычного рабочего пульса человека на нём,
 *   не ниже нижней границы и не выше общего порога.
 * Считает только сервер, по сводкам пульса прошлых кардио (клиенту не верим).
 */

export const CARDIO_ACTIVITIES = ['run', 'walk', 'bike', 'elliptical', 'other', 'recovery'] as const;
export type CardioActivity = (typeof CARDIO_ACTIVITIES)[number];

/** Сколько сессий вида — калибровка. */
export const CALIBRATION_SESSIONS = 2;
/** Нижняя граница: покой + такая доля резерва пульса. */
export const FLOOR_RESERVE_SHARE = 0.35;
/** Норма — такая доля обычного рабочего пульса. */
export const NORM_SHARE = 0.92;
/** Первые минуты сессии — разгон, в рабочий пульс не входят. */
export const WARMUP_MINUTES = 3;
/** Меньше стольких рабочих минут — сессия для нормы не годится. */
export const MIN_WORK_MINUTES = 8;
/** Норма — по стольким последним сессиям вида. */
export const NORM_WINDOW = 5;

export const cardioFloor = (resting: number = C.defaultRestingHeartRate, max: number = C.defaultMaxHeartRate): number =>
  Math.round(resting + FLOOR_RESERVE_SHARE * (max - resting));

const median = (xs: number[]): number => {
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

/** Рабочий пульс сессии: медиана по минутам без разгона; null — данных мало. */
export const workPulse = (pulse: PulseSummary | null | undefined): number | null => {
  const minutes = (pulse?.perMinute ?? []).slice(WARMUP_MINUTES).filter((b) => b > 0);
  return minutes.length >= MIN_WORK_MINUTES ? Math.round(median(minutes)) : null;
};

export interface CardioNorm {
  /** С какого пульса минуты засчитываются полностью. */
  bound: number;
  /** Идёт калибровка: норма ещё не своя. */
  calibrating: boolean;
  /** Сколько сессий вида уже годится для нормы. */
  sessions: number;
}

/**
 * Норма по рабочему пульсу прошлых сессий вида ([history] — новые первыми,
 * только годные, см. [workPulse]).
 */
export const cardioNorm = (history: number[], resting?: number, max?: number): CardioNorm => {
  const floor = cardioFloor(resting, max);
  const general = zoneLowerBound(resting, max);
  if (history.length < CALIBRATION_SESSIONS) {
    return { bound: floor, calibrating: true, sessions: history.length };
  }
  const own = Math.round(NORM_SHARE * median(history.slice(0, NORM_WINDOW)));
  return {
    bound: Math.min(general, Math.max(floor, own)),
    calibrating: false,
    sessions: history.length,
  };
};

/** Прошлые кардио → рабочий пульс по видам, новые первыми. */
export const historyByActivity = (
  workouts: { payload: unknown; pulse: unknown }[],
): Record<CardioActivity, number[]> => {
  const out = Object.fromEntries(CARDIO_ACTIVITIES.map((a) => [a, [] as number[]])) as Record<CardioActivity, number[]>;
  for (const w of workouts) {
    const activity = (w.payload as { activity?: string } | null)?.activity as CardioActivity | undefined;
    if (!activity || !(activity in out)) continue;
    const work = workPulse(w.pulse as PulseSummary | null);
    if (work !== null) out[activity].push(work);
  }
  return out;
};
