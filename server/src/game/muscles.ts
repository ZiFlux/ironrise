import { BodyPart } from './body-part';
import { EXERCISE_MUSCLE_DATA } from './exercise-data';

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

/** Целевые мышцы упражнений, доли в сумме 1 (shared/exercises.json). */
export const EXERCISE_MUSCLES = EXERCISE_MUSCLE_DATA as Readonly<Record<string, MusclePoints>>;

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
