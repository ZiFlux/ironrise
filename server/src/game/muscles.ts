import { BodyPart } from './body-part';

/**
 * Отдельные мышцы аватара. Опыт по-прежнему копится по частям тела (ТЗ 4.1), а очки
 * мышц показывают, как он распределён внутри части: кто качает одно и то же —
 * получает перекачанную мышцу. Совпадает с app/lib/game/muscles.dart.
 */
export const MUSCLES = [
  'pecs', 'delts', 'traps', 'lats', 'lowerBack', 'biceps', 'triceps', 'forearms',
  'abs', 'obliques', 'glutes', 'quads', 'hamstrings', 'calves',
] as const;
export type Muscle = (typeof MUSCLES)[number];
export type MusclePoints = Partial<Record<Muscle, number>>;

export const MUSCLE_PART: Readonly<Record<Muscle, BodyPart>> = {
  pecs: 'chest',
  delts: 'arms', biceps: 'arms', triceps: 'arms', forearms: 'arms',
  traps: 'back', lats: 'back', lowerBack: 'back',
  abs: 'core', obliques: 'core',
  glutes: 'legs', quads: 'legs', hamstrings: 'legs', calves: 'legs',
};

/** Целевые мышцы упражнений, доли в сумме 1. */
export const EXERCISE_MUSCLES: Readonly<Record<string, MusclePoints>> = {
  push_up: { pecs: 0.55, triceps: 0.2, delts: 0.15, abs: 0.1 },
  bench_press: { pecs: 0.6, triceps: 0.25, delts: 0.15 },
  db_bench_press: { pecs: 0.6, triceps: 0.2, delts: 0.2 },
  dips: { triceps: 0.45, pecs: 0.4, delts: 0.15 },
  lat_pulldown: { lats: 0.6, biceps: 0.25, traps: 0.15 },
  db_row: { lats: 0.5, traps: 0.2, biceps: 0.2, forearms: 0.1 },
  pull_up: { lats: 0.55, biceps: 0.25, traps: 0.1, forearms: 0.1 },
  back_extension: { lowerBack: 0.6, glutes: 0.25, hamstrings: 0.15 },
  bodyweight_squat: { quads: 0.6, glutes: 0.3, abs: 0.1 },
  barbell_squat: { quads: 0.55, glutes: 0.25, lowerBack: 0.1, abs: 0.1 },
  lunges: { quads: 0.45, glutes: 0.35, hamstrings: 0.1, calves: 0.1 },
  leg_press: { quads: 0.65, glutes: 0.25, calves: 0.1 },
  romanian_deadlift: { hamstrings: 0.45, glutes: 0.3, lowerBack: 0.25 },
  db_shoulder_press: { delts: 0.65, triceps: 0.25, traps: 0.1 },
  db_curl: { biceps: 0.8, forearms: 0.2 },
  french_press: { triceps: 1 },
  plank: { abs: 0.7, obliques: 0.3 },
  crunches: { abs: 0.85, obliques: 0.15 },
  hanging_leg_raise: { abs: 0.65, obliques: 0.2, forearms: 0.15 },
};

/** Очки мышц за тренировку: подходы × доля мышцы × достоверность. */
export const musclePointsOf = (
  entries: readonly { exerciseId: string; sets: readonly unknown[] }[],
  validity: number,
): MusclePoints => {
  const out: MusclePoints = {};
  for (const e of entries) {
    for (const [m, share] of Object.entries(EXERCISE_MUSCLES[e.exerciseId] ?? {}) as [Muscle, number][]) {
      out[m] = (out[m] ?? 0) + e.sets.length * share * validity;
    }
  }
  return out;
};

export const addMusclePoints = (a: MusclePoints, b: MusclePoints): MusclePoints => {
  const out: MusclePoints = { ...a };
  for (const [m, v] of Object.entries(b) as [Muscle, number][]) {
    out[m] = Math.round(((out[m] ?? 0) + v) * 100) / 100;
  }
  return out;
};
