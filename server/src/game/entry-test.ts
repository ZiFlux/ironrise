import { z } from 'zod';

/**
 * Входная тренировка (п. 116, TRAINING_SYSTEM.md 13.3): результаты с телефона и награда.
 * Уровень считает телефон (app/lib/game/entry_test.dart); сервер хранит результаты для
 * статистики и выдаёт монеты — не чаще раза в [ENTRY_TEST_REPEAT_DAYS] дней.
 */
export const ENTRY_TEST_COINS = 50;
export const ENTRY_TEST_REPEAT_DAYS = 25;

const reps = z.number().int().min(0).max(300);

export const EntryTestSchema = z.object({
  clientId: z.string().min(8).max(64),
  at: z.coerce.date(),
  level: z.enum(['novice', 'intermediate', 'advanced']),
  results: z.object({
    pushUps: reps,
    kneePushUps: z.boolean(),
    squats60: reps,
    crunches60: reps,
    burpees60: reps,
    plankSec: z.number().int().min(0).max(600),
    pullUps: reps.nullable(),
  }),
});

/** Монеты за тест: 0, если прошлая награда была меньше [ENTRY_TEST_REPEAT_DAYS] дней назад. */
export const entryTestCoins = (lastRewardedAt: Date | null, now: Date): number =>
  lastRewardedAt && now.getTime() - lastRewardedAt.getTime() < ENTRY_TEST_REPEAT_DAYS * 86_400_000 ? 0 : ENTRY_TEST_COINS;
