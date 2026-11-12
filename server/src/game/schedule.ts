/**
 * Смена графика тренировок (PLAN 4.3): не чаще раза в 7 дней, чтобы нельзя было
 * «подстроить» график под пропуск и спасти серию. Первая смена — в любой момент:
 * при регистрации легко ошибиться с днями.
 */
export const SCHEDULE_CHANGE_COOLDOWN_DAYS = 7;
export const MIN_TRAINING_DAYS = 3;

/** Когда можно сменить график в следующий раз; null — уже можно. */
export const nextScheduleChangeAt = (lastChange: Date | null, now: Date): Date | null => {
  if (lastChange === null) return null;
  const next = new Date(lastChange.getTime() + SCHEDULE_CHANGE_COOLDOWN_DAYS * 86_400_000);
  return next > now ? next : null;
};
