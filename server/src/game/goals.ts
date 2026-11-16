import { z } from 'zod';

/**
 * Цели игрока (п. 100, TRAINING_SYSTEM.md 13.1). Совпадает с enum Goal в
 * app/lib/state/hero.dart. Главная задаёт путь тренировок, дополнительные (до двух) —
 * акценты в советах и напоминаниях.
 */
export const GOALS = ['mass', 'strength', 'fatLoss', 'endurance', 'consistency'] as const;
export type GoalId = (typeof GOALS)[number];

export const MAX_EXTRA_GOALS = 2;

export const GoalSchema = z.enum(GOALS);

/** Дополнительные цели: без повторов и без главной. */
export const extraGoalsOk = (goal: string, goals: readonly string[]) =>
  goals.length <= MAX_EXTRA_GOALS && new Set(goals).size === goals.length && !goals.includes(goal);

export const GoalsChangeSchema = z
  .object({ goal: GoalSchema, goals: z.array(GoalSchema).max(MAX_EXTRA_GOALS).default([]) })
  .refine((b) => extraGoalsOk(b.goal, b.goals), { message: 'goals must be unique and differ from the main goal' });
