/**
 * Личная норма пульса для тренировок ауры (16.11). Ауры открываются не сразу:
 * сначала неделя обычных тренировок с пульсом, чтобы накопились данные — средний
 * пульс тренировок и пики на подходах. Тренировку ауры потом сравниваем с ними,
 * а где движения ауры совпадают с упражнениями базы — с пиками именно на них.
 */
import { AURA_MIN_AVG_BPM, AURA_MIN_PEAK_BPM, AuraKind } from './aura';

/** Сколько ждать с первой тренировки с пульсом и сколько таких тренировок нужно. */
export const AURA_UNLOCK_DAYS = 7;
export const AURA_UNLOCK_WORKOUTS = 3;

/** По каким тренировкам считать норму. */
export const AURA_NORM_WINDOW_DAYS = 30;

/** Доля личной нормы: средний пульс ауры от 85 % обычного или пик от 90 %. */
export const AURA_AVG_SHARE = 0.85;
export const AURA_PEAK_SHARE = 0.9;

/** Нижние границы: даже у очень спокойного пульса сидя ауру не прокачать. */
export const AURA_FLOOR_AVG = 75;
export const AURA_FLOOR_PEAK = 100;

/** Движения ауры, которые есть в базе упражнений (shared/exercises.json). */
export const AURA_EXERCISES: Record<AuraKind, string[]> = {
  fury: ['jump_squat', 'push_up'],
  guard: ['plank', 'side_plank'],
  haste: ['jumping_jacks', 'lunges'],
  focus: ['push_up', 'bodyweight_squat'],
};

/** Тренировка из базы, как её видит расчёт нормы. */
export interface NormWorkout {
  startedAt: Date;
  /** Сводка пульса или (старые записи) сырой ряд. */
  pulse: unknown;
  /** Подходы силовой: пик пульса у подхода (п. 106). */
  entries?: { exerciseId: string; sets: { peak?: number }[] }[];
}

export interface AuraNorm {
  /** Ауры доступны. */
  ready: boolean;
  /** Сколько ещё дней и тренировок с пульсом до открытия (0 — уже). */
  daysLeft: number;
  workoutsLeft: number;
  /** Пороги для тренировки ауры этого вида. */
  minAvg: number;
  minPeak: number;
}

const median = (xs: number[]): number | null => {
  if (xs.length === 0) return null;
  const s = [...xs].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
};

/** Средний и максимум пульса тренировки: из сводки или из сырого ряда. */
const pulseStats = (pulse: unknown): { avg: number; max: number } | null => {
  if (Array.isArray(pulse)) {
    const bpm = pulse.map((p) => (p as { bpm?: number }).bpm).filter((b): b is number => typeof b === 'number');
    if (bpm.length < 2) return null;
    return { avg: bpm.reduce((a, b) => a + b, 0) / bpm.length, max: Math.max(...bpm) };
  }
  const s = pulse as { n?: number; avg?: number; max?: number } | null;
  if (!s || typeof s.avg !== 'number' || typeof s.max !== 'number' || (s.n ?? 0) < 2) return null;
  return { avg: s.avg, max: s.max };
};

export const auraNorm = (args: {
  kind: AuraKind;
  workouts: NormWorkout[];
  now: Date;
  /** Уже качал ауру до этого правила — не запираем снова. */
  grandfathered?: boolean;
}): AuraNorm => {
  const DAY = 86_400_000;
  const withPulse = args.workouts
    .map((w) => ({ w, s: pulseStats(w.pulse) }))
    .filter((x): x is { w: NormWorkout; s: { avg: number; max: number } } => x.s !== null);
  const first = withPulse.reduce<number | null>(
    (min, x) => (min === null || x.w.startedAt.getTime() < min ? x.w.startedAt.getTime() : min),
    null,
  );
  const daysSince = first === null ? 0 : Math.floor((args.now.getTime() - first) / DAY);
  const daysLeft = first === null ? AURA_UNLOCK_DAYS : Math.max(0, AURA_UNLOCK_DAYS - daysSince);
  const workoutsLeft = Math.max(0, AURA_UNLOCK_WORKOUTS - withPulse.length);
  const ready = args.grandfathered === true || (daysLeft === 0 && workoutsLeft === 0);

  const recent = withPulse.filter((x) => args.now.getTime() - x.w.startedAt.getTime() <= AURA_NORM_WINDOW_DAYS * DAY);
  const avgNorm = median(recent.map((x) => x.s.avg));
  const own = new Set(AURA_EXERCISES[args.kind]);
  const peaksOf = (filter: (id: string) => boolean) =>
    recent.flatMap((x) =>
      (x.w.entries ?? []).flatMap((e) =>
        filter(e.exerciseId) ? e.sets.map((s) => s.peak).filter((p): p is number => typeof p === 'number') : [],
      ),
    );
  const ownPeaks = peaksOf((id) => own.has(id));
  const allPeaks = peaksOf(() => true);
  // Сначала — пики на тех же движениях, потом — на любых подходах, потом — максимумы тренировок.
  const peakNorm =
    (ownPeaks.length >= 3 ? median(ownPeaks) : null) ??
    (allPeaks.length >= 5 ? median(allPeaks) : null) ??
    median(recent.map((x) => x.s.max));

  return {
    ready,
    daysLeft: ready ? 0 : daysLeft,
    workoutsLeft: ready ? 0 : workoutsLeft,
    // Норм ещё нет (старые игроки без пульса) — общие пороги.
    minAvg: avgNorm === null ? AURA_MIN_AVG_BPM : Math.round(Math.max(AURA_FLOOR_AVG, avgNorm * AURA_AVG_SHARE)),
    minPeak: peakNorm === null ? AURA_MIN_PEAK_BPM : Math.round(Math.max(AURA_FLOOR_PEAK, peakNorm * AURA_PEAK_SHARE)),
  };
};
