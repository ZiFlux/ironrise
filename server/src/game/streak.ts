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
