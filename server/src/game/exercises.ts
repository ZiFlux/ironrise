import { BodyPart } from './body-part';
import { EXERCISE_DATA } from './exercise-data';

export interface Exercise {
  id: string;
  name: string;
  equipment: 'none' | 'dumbbells' | 'gym';
  usesWeight: boolean;
  shares: Partial<Record<BodyPart, number>>;
}

/**
 * Потолок веса по инвентарю, кг (п. 75): выше — невозможно, подход не засчитывается.
 * Тот же потолок в приложении — app/lib/game/set_sanity.dart.
 */
export const maxWeightFor = (equipment: Exercise['equipment']): number =>
  equipment === 'none' ? 150 : equipment === 'dumbbells' ? 100 : 500;

/** Повторов (или секунд) в подходе — больше не бывает. */
export const MAX_REPS_PER_SET = 300;

/** Подход правдоподобен: вес и повторы в пределах возможного. */
export const isPlausibleSet = (exercise: Exercise, set: { weight: number; reps: number }): boolean =>
  set.reps <= MAX_REPS_PER_SET && (!exercise.usesWeight || set.weight <= maxWeightFor(exercise.equipment));

/** Справочник силовых упражнений: shared/exercises.json (tools/gen_exercises.py). */
export const EXERCISES: readonly Exercise[] = EXERCISE_DATA;

const byId = new Map(EXERCISES.map((e) => [e.id, e]));

export const findExercise = (id: string): Exercise | undefined => byId.get(id);
