import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { localDay } from '../common/day';
import { isStreakAtRisk } from '../game/streak';
import { PrismaService } from '../prisma.service';
import { DAILY_ACTIVE_DAYS, dailyReminderDue, DUELS_AFTER_MORNING_HOURS, habitHour, NotificationType, parseSettings } from './settings';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

export interface PushMessage {
  type: NotificationType;
  title: string;
  body: string;
  /** Куда вести по нажатию: friends | duels | home | tip. */
  screen: 'friends' | 'duels' | 'home' | 'tip' | 'workout';
}

const REMINDER_EVERY_MS = 15 * 60_000;

/**
 * Уведомления: каждое событие пишется в ленту игрока (меню уведомлений в приложении)
 * и, если игрок не выключил этот тип, уходит пушем через FCM HTTP v1.
 * Ключ — JSON сервисного аккаунта Firebase по пути FIREBASE_SERVICE_ACCOUNT;
 * без него лента работает, а пуши выключены. Ошибки не роняют запросы.
 */
@Injectable()
export class PushService implements OnModuleInit, OnModuleDestroy {
  private readonly log = new Logger('Push');
  private account: ServiceAccount | null = null;
  private token: { value: string; expiresAt: number } | null = null;
  private timer?: NodeJS.Timeout;

  constructor(private readonly db: PrismaService) {}

  onModuleInit() {
    this.timer = setInterval(() => {
      void this.remindStreaks().catch((e) => this.log.warn(String(e)));
      void this.remindDaily().catch((e) => this.log.warn(String(e)));
      void this.remindTraining().catch((e) => this.log.warn(String(e)));
    }, REMINDER_EVERY_MS);
    const path = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!path) {
      this.log.log('FIREBASE_SERVICE_ACCOUNT не задан — пуши выключены, лента уведомлений работает');
      return;
    }
    try {
      this.account = JSON.parse(readFileSync(path, 'utf8')) as ServiceAccount;
      this.log.log(`Пуши включены, проект ${this.account.project_id}`);
    } catch (e) {
      this.log.error(`Не удалось прочитать ключ Firebase (${path}): ${(e as Error).message}`);
    }
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  async register(userId: string, token: string, platform: string) {
    await this.db.deviceToken.upsert({
      where: { token },
      create: { token, userId, platform },
      update: { userId, platform },
    });
  }

  async unregister(userId: string, token: string) {
    await this.db.deviceToken.deleteMany({ where: { token, userId } });
  }

  /** Записать в ленту и, если разрешено, отправить пуш. Никогда не бросает исключение. */
  notify(userId: string, msg: PushMessage): void {
    void (async () => {
      await this.db.notification.create({
        data: { userId, type: msg.type, title: msg.title, body: msg.body, screen: msg.screen },
      });
      if (!this.account) return;
      const profile = await this.db.profile.findUnique({ where: { userId }, select: { notificationSettings: true } });
      if (!parseSettings(profile?.notificationSettings)[msg.type]) return;
      const devices = await this.db.deviceToken.findMany({ where: { userId }, select: { token: true } });
      for (const d of devices) await this.send(d.token, msg);
    })().catch((e) => this.log.warn(`notify ${userId}: ${(e as Error).message}`));
  }

  private async send(deviceToken: string, msg: PushMessage) {
    const account = this.account!;
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${account.project_id}/messages:send`, {
      method: 'POST',
      headers: { authorization: `Bearer ${await this.accessToken()}`, 'content-type': 'application/json' },
      body: JSON.stringify({
        message: {
          token: deviceToken,
          notification: { title: msg.title, body: msg.body },
          data: { screen: msg.screen, type: msg.type },
          android: { priority: 'high' },
        },
      }),
    });
    if (res.ok) return;
    const text = await res.text();
    // Приложение удалено или токен устарел — больше не шлём на него.
    if (res.status === 404 || text.includes('UNREGISTERED')) {
      await this.db.deviceToken.deleteMany({ where: { token: deviceToken } });
      return;
    }
    this.log.warn(`FCM ${res.status}: ${text.slice(0, 200)}`);
  }

  /** OAuth-токен Google по JWT, подписанному ключом сервисного аккаунта (RS256). */
  private async accessToken(): Promise<string> {
    if (this.token && this.token.expiresAt > Date.now() + 60_000) return this.token.value;
    const account = this.account!;
    const now = Math.floor(Date.now() / 1000);
    const b64 = (o: object) => Buffer.from(JSON.stringify(o)).toString('base64url');
    const unsigned = `${b64({ alg: 'RS256', typ: 'JWT' })}.${b64({
      iss: account.client_email,
      scope: 'https://www.googleapis.com/auth/firebase.messaging',
      aud: 'https://oauth2.googleapis.com/token',
      iat: now,
      exp: now + 3600,
    })}`;
    const signature = createSign('RSA-SHA256').update(unsigned).sign(account.private_key, 'base64url');
    const res = await fetch('https://oauth2.googleapis.com/token', {
      method: 'POST',
      headers: { 'content-type': 'application/x-www-form-urlencoded' },
      body: new URLSearchParams({
        grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
        assertion: `${unsigned}.${signature}`,
      }),
    });
    if (!res.ok) throw new Error(`Google OAuth ${res.status}: ${(await res.text()).slice(0, 200)}`);
    const json = (await res.json()) as { access_token: string; expires_in: number };
    this.token = { value: json.access_token, expiresAt: Date.now() + json.expires_in * 1000 };
    return this.token.value;
  }

  /**
   * В выбранный игроком час напомнить, если сегодня последний допустимый день отдыха:
   * без тренировки серия сгорит завтра. Раз в день; выключается в настройках.
   */
  async remindStreaks(now = new Date()) {
    const profiles = await this.db.profile.findMany({
      where: { streakDays: { gt: 0 }, lastActiveDay: { not: null } },
      select: {
        userId: true,
        timezone: true,
        lastActiveDay: true,
        scheduleDays: true,
        streakDays: true,
        streakReminderDay: true,
        notificationSettings: true,
      },
    });
    for (const p of profiles) {
      const settings = parseSettings(p.notificationSettings);
      const today = localDay(now, p.timezone);
      if (!settings.streak_risk || p.streakReminderDay === today) continue;
      if (!isStreakAtRisk(p.lastActiveDay!, today, p.scheduleDays)) continue;
      if (localHour(now, p.timezone) < settings.streakReminderHour) continue;
      await this.db.profile.update({ where: { userId: p.userId }, data: { streakReminderDay: today } });
      this.notify(p.userId, {
        type: 'streak_risk',
        title: `Серия ${p.streakDays} дн. под угрозой`,
        body: 'Сегодня последний день отдыха. Короткая тренировка или 20 минут кардио сохранят серию',
        screen: 'home',
      });
    }
  }

  /**
   * Напоминание по привычке (PLAN 4.8, п. 10): в день тренировки по графику, если
   * сегодня ещё не тренировался, — за час до часа, когда человек обычно начинает.
   */
  async remindTraining(now = new Date()) {
    const profiles = await this.db.profile.findMany({
      where: { lastActiveDay: { not: null } },
      select: {
        userId: true,
        timezone: true,
        lastActiveDay: true,
        scheduleDays: true,
        trainingReminderDay: true,
        notificationSettings: true,
      },
    });
    for (const p of profiles) {
      const s = parseSettings(p.notificationSettings);
      const today = localDay(now, p.timezone);
      if (!s.training_reminder || p.trainingReminderDay === today) continue;
      const days = (Date.parse(today) - Date.parse(p.lastActiveDay!)) / 86_400_000;
      if (days > DAILY_ACTIVE_DAYS) continue;
      // 0 — понедельник, как scheduleDays.
      const weekday = (new Date(`${today}T12:00:00Z`).getUTCDay() + 6) % 7;
      if (!p.scheduleDays.includes(weekday)) continue;
      if (await this.db.workout.findFirst({ where: { userId: p.userId, day: today }, select: { id: true } })) continue;
      const recent = await this.db.workout.findMany({
        where: { userId: p.userId },
        orderBy: { startedAt: 'desc' },
        take: 10,
        select: { startedAt: true },
      });
      // Привычки ещё нет (меньше 3 тренировок) — напоминаем вечером, к 19:00.
      const habit = habitHour(recent.map((w) => localHour(w.startedAt, p.timezone))) ?? DEFAULT_TRAINING_HOUR;
      if (localHour(now, p.timezone) !== habit - 1) continue;
      await this.db.profile.update({ where: { userId: p.userId }, data: { trainingReminderDay: today } });
      this.notify(p.userId, {
        type: 'training_reminder',
        title: 'Через час — твоё время тренировки',
        body: recent.length >= 3
          ? `Ты обычно начинаешь около ${habit}:00. План на сегодня уже ждёт`
          : 'Сегодня тренировка по графику — план уже ждёт',
        screen: 'workout',
      });
    }
  }

  async remindDaily(now = new Date()) {
    const profiles = await this.db.profile.findMany({
      where: { lastActiveDay: { not: null } },
      select: {
        userId: true,
        timezone: true,
        lastActiveDay: true,
        tipRewardDay: true,
        tipReminderDay: true,
        duelsReminderDay: true,
        notificationSettings: true,
      },
    });
    for (const p of profiles) {
      const s = parseSettings(p.notificationSettings);
      const today = localDay(now, p.timezone);
      const hour = localHour(now, p.timezone);
      const common = { today, hour, lastActiveDay: p.lastActiveDay };
      // Совет уже разобран сегодня — напоминать не о чем.
      if (
        p.tipRewardDay !== today &&
        dailyReminderDue({ ...common, enabled: s.daily_tip, sentDay: p.tipReminderDay, atHour: s.morningHour })
      ) {
        await this.db.profile.update({ where: { userId: p.userId }, data: { tipReminderDay: today } });
        this.notify(p.userId, dailyMessages.tip);
      }
      if (
        dailyReminderDue({
          ...common,
          enabled: s.duels_refreshed,
          sentDay: p.duelsReminderDay,
          atHour: s.morningHour + DUELS_AFTER_MORNING_HOURS,
        })
      ) {
        await this.db.profile.update({ where: { userId: p.userId }, data: { duelsReminderDay: today } });
        this.notify(p.userId, dailyMessages.duels(today));
      }
    }
  }
}

/** Утренние напоминания: совет дня и новые соперники в дуэлях. Не чаще раза в день каждое. */
const DUEL_LINES = [
  'Четыре новых соперника уже разминаются. Кто-то из них явно пропустил день ног',
  'Свежие боты в зале: один на массе, другой на сушке. Проверь, кто сильнее',
  'Новые соперники пришли в зал и заняли твою скамью. Разберись',
];

export const dailyMessages = {
  tip: {
    type: 'daily_tip' as const,
    title: 'Совет дня готов',
    body: 'Минута чтения и вопрос — за правильный ответ монеты',
    screen: 'tip' as const,
  },
  duels: (day: string): PushMessage => ({
    type: 'duels_refreshed',
    title: 'Новые соперники в дуэлях',
    body: DUEL_LINES[Number(day.replaceAll('-', '')) % DUEL_LINES.length],
    screen: 'duels',
  }),
};

/** Час тренировки по умолчанию, пока привычка не сложилась. */
const DEFAULT_TRAINING_HOUR = 19;

const localHour = (at: Date, timeZone: string): number =>
  Number(new Intl.DateTimeFormat('en-GB', { timeZone, hour: '2-digit', hourCycle: 'h23' }).format(at));
