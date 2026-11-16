/**
 * Серия в днях (PLAN 4.3). Отдых в пределах формата не прерывает серию и засчитывается в неё.
 * Даты — календарные дни пользователя в формате YYYY-MM-DD (часовой пояс учитывает вызывающий).
 */
const dayIndex = (day: string): number => Math.round(Date.parse(`${day}T00:00:00Z`) / 86_400_000);

export const daysBetween = (from: string, to: string): number => dayIndex(to) - dayIndex(from);

export const streakAfterActivity = (args: {
  currentStreak: number;
  lastActiveDay: string | null;
  today: string;
  maxRestDays: number;
}): number => {
  if (args.lastActiveDay === null) return 1;
  const restDays = daysBetween(args.lastActiveDay, args.today) - 1;
  if (restDays < 0) return args.currentStreak;
  if (restDays > args.maxRestDays) return 1;
  return args.currentStreak + restDays + 1;
};

/** Серия на сегодня: сгорает, если отдых уже превысил лимит. */
export const currentStreak = (args: {
  streakDays: number;
  lastActiveDay: string | null;
  today: string;
  maxRestDays: number;
}): number => {
  if (args.lastActiveDay === null) return 0;
  return daysBetween(args.lastActiveDay, args.today) - 1 > args.maxRestDays ? 0 : args.streakDays;
};

/** Самый длинный перерыв между тренировочными днями (0 = Пн … 6 = Вс) с переходом через неделю. */
export const maxRestDaysInRow = (days: number[]): number => {
  if (days.length === 0) return 7;
  const sorted = [...days].sort((a, b) => a - b);
  let max = 0;
  sorted.forEach((d, i) => {
    const next = i + 1 < sorted.length ? sorted[i + 1] : sorted[0] + 7;
    max = Math.max(max, next - d - 1);
  });
  return max;
};

/**
 * «Минимум» (п. 100): за днём загрузки идёт день восстановления. Как recoveryDaysOf в
 * app/lib/game/training_format.dart: пары по порядку недели, с переходом через воскресенье.
 */
export const recoveryDaysOf = (format: string, days: readonly number[]): Set<number> => {
  if (format !== 'minimum') return new Set();
  const all = new Set(days);
  const start = [0, 1, 2, 3, 4, 5, 6].find((d) => all.has(d) && !all.has((d + 6) % 7));
  const recovery = new Set<number>();
  if (start === undefined) return recovery;
  for (let i = 0; i < 7; i++) {
    const d = (start + i) % 7;
    if (!all.has(d) || recovery.has(d)) continue;
    if (all.has((d + 1) % 7)) recovery.add((d + 1) % 7);
  }
  return recovery;
};

/**
 * Сколько дней подряд можно отдыхать без потери серии. Кардио и восстановление в дни
 * отдыха — необязательны (п. 131): у «Минимума» считаем по дням загрузки, иначе
 * пропущенный день восстановления сжигал бы серию.
 */
export const restLimit = (format: string, scheduleDays: readonly number[]): number => {
  const recovery = recoveryDaysOf(format, scheduleDays);
  return maxRestDaysInRow(scheduleDays.filter((d) => !recovery.has(d)));
};

/** Сегодня без активности серия сгорит завтра: отдых уже на пределе формата. */
export const isStreakAtRisk = (lastActiveDay: string, today: string, scheduleDays: number[], format = ''): boolean =>
  daysBetween(lastActiveDay, today) === restLimit(format, scheduleDays) + 1;
