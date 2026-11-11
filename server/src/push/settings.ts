import { z } from 'zod';

export const NOTIFICATION_TYPES = ['friend_request', 'friend_accepted', 'attacked', 'streak_risk'] as const;
export type NotificationType = (typeof NOTIFICATION_TYPES)[number];

/** Настройки пушей игрока. Всё включено по умолчанию, напоминание в 19:00. */
export const SettingsSchema = z.object({
  friend_request: z.boolean().default(true),
  friend_accepted: z.boolean().default(true),
  attacked: z.boolean().default(true),
  streak_risk: z.boolean().default(true),
  /** Час напоминания о серии по времени игрока. */
  streakReminderHour: z.number().int().min(6).max(23).default(19),
});

export type NotificationSettings = z.infer<typeof SettingsSchema>;

/** Из JSON профиля, с умолчаниями для отсутствующих и битых полей. */
export const parseSettings = (raw: unknown): NotificationSettings => {
  const parsed = SettingsSchema.safeParse(raw ?? {});
  return parsed.success ? parsed.data : SettingsSchema.parse({});
};
