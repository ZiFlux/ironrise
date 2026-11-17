/** Ответы о самочувствии (п. 81): значения и проверка — без Nest, чтобы тестировать отдельно. */
import { z } from 'zod';
import { findExercise } from '../game/exercises';

export const FEELINGS = ['easy', 'ok', 'hard', 'pain'] as const;
export const PAIN_ZONES = ['shoulder', 'elbowWrist', 'lowerBack', 'knee', 'other'] as const;
export const PAIN_KINDS = ['sharp', 'aching', 'muscle', 'click', 'numb'] as const;

/** Не больше стольких ответов за сутки: после тренировки, а не поток. */
export const WELLBEING_PER_DAY = 3;

export const WellbeingSchema = z
  .object({
    feeling: z.enum(FEELINGS),
    zone: z.enum(PAIN_ZONES).optional(),
    painKind: z.enum(PAIN_KINDS).optional(),
    exercises: z
      .array(z.string().max(40))
      .max(12)
      .default([])
      .refine((ids) => ids.every((id) => findExercise(id) !== undefined), 'unknown exercise'),
  })
  .refine((r) => r.feeling === 'pain' || (r.zone === undefined && r.painKind === undefined), 'zone only with pain');

export const WellbeingConsentSchema = z.object({ granted: z.boolean() });
