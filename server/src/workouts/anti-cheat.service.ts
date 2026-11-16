import { Injectable, Logger } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import {
  BLOCK_REASON,
  bestByExercise,
  findCheats,
  HISTORY_DAYS,
  shouldBlock,
  WINDOW_DAYS,
} from '../game/anti-cheat';
import { PulseSummary } from '../game/pulse-summary';
import { PrismaService } from '../prisma.service';
import { PushService } from '../push/push.service';

type Entries = { exerciseId: string; sets: { weight: number; reps: number }[] }[];

const KIND_TEXT: Record<string, string> = {
  impossible_set: 'невозможный подход',
  strength_jump: 'скачок силы',
  flat_pulse: 'плоский пульс',
};

/**
 * Античит после принятой тренировки (п. 113): подозрения — в таблицу Suspicion, при
 * серьёзном или трёх за 14 дней — временная блокировка и пуш админу. Решает админ:
 * веб-админка → «Подозрительные». Ошибки здесь не ломают приём тренировки.
 */
@Injectable()
export class AntiCheatService {
  private readonly log = new Logger('AntiCheat');

  constructor(
    private readonly db: PrismaService,
    private readonly push: PushService,
  ) {}

  async checkStrength(userId: string, workoutId: string, now = new Date()): Promise<void> {
    const workout = await this.db.workout.findUnique({
      where: { id: workoutId },
      select: { payload: true, pulse: true, startedAt: true },
    });
    if (!workout) return;
    const entries = ((workout.payload as { entries?: Entries } | null)?.entries ?? []) as Entries;
    const since = new Date(workout.startedAt.getTime() - HISTORY_DAYS * 86_400_000);
    const history = await this.db.workout.findMany({
      where: { userId, type: 'strength', id: { not: workoutId }, startedAt: { gte: since, lt: workout.startedAt } },
      select: { payload: true },
    });
    const pulse = workout.pulse as unknown as PulseSummary | null;
    const findings = findCheats({
      entries,
      best: bestByExercise(history.map((h) => ((h.payload as { entries?: Entries } | null)?.entries ?? []) as Entries)),
      pulse: pulse && pulse.n > 0 ? pulse : null,
    });
    if (findings.length === 0) return;

    const recent = await this.db.suspicion.count({
      where: { userId, resolvedAt: null, createdAt: { gte: new Date(now.getTime() - WINDOW_DAYS * 86_400_000) } },
    });
    const block = shouldBlock(findings, recent);
    await this.db.suspicion.createMany({
      data: findings.map((f) => ({
        userId,
        workoutId,
        kind: f.kind,
        severe: f.severe,
        details: f.details as Prisma.InputJsonValue,
        blocked: block,
      })),
    });
    if (block) {
      const user = await this.db.user.findUnique({ where: { id: userId }, select: { bannedAt: true } });
      if (user && !user.bannedAt) {
        await this.db.$transaction([
          this.db.user.update({ where: { id: userId }, data: { bannedAt: now, banReason: BLOCK_REASON } }),
          this.db.refreshToken.updateMany({ where: { userId, revokedAt: null }, data: { revokedAt: now } }),
        ]);
      }
    }
    await this.alertAdmin(userId, findings.map((f) => f.kind), block);
  }

  /** Пуш админу — аккаунту с e-mail из ADMIN_NOTIFY_EMAIL (если задан). */
  private async alertAdmin(userId: string, kinds: string[], blocked: boolean) {
    const email = process.env.ADMIN_NOTIFY_EMAIL?.trim().toLowerCase();
    if (!email) return;
    const [admin, player] = await Promise.all([
      this.db.user.findUnique({ where: { email }, select: { id: true } }),
      this.db.profile.findUnique({ where: { userId }, select: { nickname: true } }),
    ]);
    if (!admin) return;
    this.push.notify(admin.id, {
      type: 'admin_alert',
      title: `Античит: ${player?.nickname ?? 'игрок'}${blocked ? ' — заблокирован' : ''}`,
      body: `${kinds.map((k) => KIND_TEXT[k] ?? k).join(', ')}. Разобраться — веб-админка → «Подозрительные».`,
      screen: 'home',
    });
  }

  /** Проверка без падений: ошибка античита не должна мешать тренировке. */
  run(userId: string, workoutId: string) {
    this.checkStrength(userId, workoutId).catch((e) => this.log.warn(`check ${userId}: ${(e as Error).message}`));
  }
}
