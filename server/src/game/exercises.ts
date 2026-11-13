import { BodyPart } from './body-part';
import { EXERCISE_DATA } from './exercise-data';

export interface Exercise {
  id: string;
  name: string;
  shares: Partial<Record<BodyPart, number>>;
}

/** Справочник силовых упражнений: shared/exercises.json (tools/gen_exercises.py). */
export const EXERCISES: readonly Exercise[] = EXERCISE_DATA;

const byId = new Map(EXERCISES.map((e) => [e.id, e]));

export const findExercise = (id: string): Exercise | undefined => byId.get(id);
