import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { createSign } from 'node:crypto';
import { readFileSync } from 'node:fs';
import { localDay } from '../common/day';
import { isStreakAtRisk } from '../game/streak';
import { PrismaService } from '../prisma.service';

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

export interface PushMessage {
  title: string;
  body: string;
  /** Куда вести по нажатию: friends | duels | home. */
  screen: 'friends' | 'duels' | 'home';
}

const REMINDER_HOUR = 19;
const REMINDER_EVERY_MS = 15 * 60_000;

/**
 * Пуши через FCM HTTP v1. Ключ — JSON сервисного аккаунта Firebase по пути
 * FIREBASE_SERVICE_ACCOUNT. Без ключа сервис молча выключен: приложение работает,
 * просто без уведомлений. Ошибки отправки не роняют запросы — пуш не критичен.
 */
@Injectable()
export class PushService implements OnModuleInit, OnModuleDestroy {
  private readonly log = new Logger('Push');
  private account: ServiceAccount | null = null;
  private token: { value: string; expiresAt: number } | null = null;
  private timer?: NodeJS.Timeout;

  constructor(private readonly db: PrismaService) {}

  onModuleInit() {
    const path = process.env.FIREBASE_SERVICE_ACCOUNT;
    if (!path) {
      this.log.log('FIREBASE_SERVICE_ACCOUNT не задан — пуши выключены');
      return;
    }
    try {
      this.account = JSON.parse(readFileSync(path, 'utf8')) as ServiceAccount;
      this.log.log(`Пуши включены, проект ${this.account.project_id}`);
      this.timer = setInterval(() => void this.remindStreaks(), REMINDER_EVERY_MS);
    } catch (e) {
      this.log.error(`Не удалось прочитать ключ Firebase (${path}): ${(e as Error).message}`);
    }
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }

  get enabled(): boolean {
    return this.account !== null;
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

  /** Отправить на все устройства пользователя. Никогда не бросает исключение. */
  notify(userId: string, msg: PushMessage): void {
    if (!this.account) return;
    void (async () => {
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
          data: { screen: msg.screen },
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
   * Вечером напомнить тем, у кого сегодня последний допустимый день отдыха:
   * без тренировки серия сгорит завтра. Раз в день на пользователя.
   */
  async remindStreaks(now = new Date()) {
    const profiles = await this.db.profile.findMany({
      where: { streakDays: { gt: 0 }, lastActiveDay: { not: null }, user: { devices: { some: {} } } },
      select: { userId: true, timezone: true, lastActiveDay: true, scheduleDays: true, streakDays: true, streakReminderDay: true },
    });
    for (const p of profiles) {
      const today = localDay(now, p.timezone);
      if (p.streakReminderDay === today || !isStreakAtRisk(p.lastActiveDay!, today, p.scheduleDays)) continue;
      if (localHour(now, p.timezone) < REMINDER_HOUR) continue;
      await this.db.profile.update({ where: { userId: p.userId }, data: { streakReminderDay: today } });
      this.notify(p.userId, {
        title: `Серия ${p.streakDays} дн. под угрозой`,
        body: 'Сегодня последний день отдыха. Короткая тренировка или 20 минут кардио сохранят серию',
        screen: 'home',
      });
    }
  }
}

const localHour = (at: Date, timeZone: string): number =>
  Number(new Intl.DateTimeFormat('en-GB', { timeZone, hour: '2-digit', hourCycle: 'h23' }).format(at));
