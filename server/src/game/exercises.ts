import { BodyPart } from './body-part';

export interface Exercise {
  id: string;
  name: string;
  shares: Partial<Record<BodyPart, number>>;
}

/**
 * Стартовый справочник: копия app/lib/game/exercise_catalog.dart (только то,
 * что нужно серверу для расчёта опыта). Потом — таблицы exercises и exercise_shares.
 */
export const EXERCISES: readonly Exercise[] = [
  { id: 'push_up', name: 'Отжимания', shares: { chest: 0.7, arms: 0.2, core: 0.1 } },
  { id: 'bench_press', name: 'Жим штанги лёжа', shares: { chest: 0.7, arms: 0.3 } },
  { id: 'db_bench_press', name: 'Жим гантелей лёжа', shares: { chest: 0.7, arms: 0.3 } },
  { id: 'dips', name: 'Отжимания на брусьях', shares: { chest: 0.4, arms: 0.6 } },
  { id: 'lat_pulldown', name: 'Тяга верхнего блока', shares: { back: 0.75, arms: 0.25 } },
  { id: 'db_row', name: 'Тяга гантели в наклоне', shares: { back: 0.7, arms: 0.3 } },
  { id: 'pull_up', name: 'Подтягивания', shares: { back: 0.7, arms: 0.3 } },
  { id: 'back_extension', name: 'Гиперэкстензия', shares: { back: 0.7, legs: 0.3 } },
  { id: 'bodyweight_squat', name: 'Приседания', shares: { legs: 0.85, core: 0.15 } },
  { id: 'barbell_squat', name: 'Приседания со штангой', shares: { legs: 0.8, back: 0.1, core: 0.1 } },
  { id: 'lunges', name: 'Выпады', shares: { legs: 0.9, core: 0.1 } },
  { id: 'leg_press', name: 'Жим ногами', shares: { legs: 1 } },
  { id: 'romanian_deadlift', name: 'Румынская тяга', shares: { legs: 0.6, back: 0.4 } },
  { id: 'db_shoulder_press', name: 'Жим гантелей сидя', shares: { arms: 0.5, back: 0.3, chest: 0.2 } },
  { id: 'db_curl', name: 'Сгибания с гантелями', shares: { arms: 1 } },
  { id: 'french_press', name: 'Французский жим', shares: { arms: 1 } },
  { id: 'plank', name: 'Планка', shares: { core: 1 } },
  { id: 'crunches', name: 'Скручивания', shares: { core: 1 } },
  { id: 'hanging_leg_raise', name: 'Подъём ног в висе', shares: { core: 0.8, arms: 0.2 } },
];

const byId = new Map(EXERCISES.map((e) => [e.id, e]));

export const findExercise = (id: string): Exercise | undefined => byId.get(id);
