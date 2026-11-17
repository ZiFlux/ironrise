import { z } from 'zod';

export const NOTIFICATION_TYPES = [
  'friend_request',
  'friend_accepted',
  'attacked',
  'streak_risk',
  'daily_tip',
  'duels_refreshed',
  'training_reminder',
  /** Только админу: античит нашёл подозрительную тренировку (п. 113). */
  'admin_alert',
  /** Аккаунт: ник заменён автомодератором и т. п. — не отключается. */
  'account',
] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

/** Настройки пушей игрока. Всё включено по умолчанию, напоминание в 19:00. */
export const SettingsSchema = z.object({
  friend_request: z.boolean().default(true),
  friend_accepted: z.boolean().default(true),
  attacked: z.boolean().default(true),
  streak_risk: z.boolean().default(true),
  /** Час напоминания о серии по времени игрока. */
  streakReminderHour: z.number().int().min(6).max(23).default(19),
  /** «Совет дня готов» — утром в morningHour. */
  daily_tip: z.boolean().default(true),
  /** «Новые соперники в дуэлях» — через 4 часа после morningHour. */
  duels_refreshed: z.boolean().default(true),
  morningHour: z.number().int().min(6).max(12).default(9),
  /** «Скоро твоё время тренировки» — за час до привычного часа, в день по графику. */
  training_reminder: z.boolean().default(true),
  admin_alert: z.boolean().default(true),
  account: z.boolean().default(true),
});

/** Привычный час тренировки: медиана часа начала последних тренировок. Нужно минимум 3. */
export const habitHour = (startHours: number[]): number | null => {
  if (startHours.length < 3) return null;
  const sorted = [...startHours].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
};

/** Ежедневные напоминания — только тем, кто тренировался за последние 14 дней. */
export const DAILY_ACTIVE_DAYS = 14;
/** Новые дуэли напоминаем позже совета, чтобы не слать два пуша сразу. */
export const DUELS_AFTER_MORNING_HOURS = 4;

/** Пора ли слать ежедневное напоминание этого типа. */
export const dailyReminderDue = (args: {
  enabled: boolean;
  sentDay: string | null;
  today: string;
  hour: number;
  atHour: number;
  lastActiveDay: string | null;
}): boolean => {
  if (!args.enabled || args.sentDay === args.today || args.hour < args.atHour || !args.lastActiveDay) return false;
  const days = (Date.parse(args.today) - Date.parse(args.lastActiveDay)) / 86_400_000;
  return days <= DAILY_ACTIVE_DAYS;
};

export type NotificationSettings = z.infer<typeof SettingsSchema>;

/** Из JSON профиля, с умолчаниями для отсутствующих и битых полей. */
export const parseSettings = (raw: unknown): NotificationSettings => {
  const parsed = SettingsSchema.safeParse(raw ?? {});
  return parsed.success ? parsed.data : SettingsSchema.parse({});
};
