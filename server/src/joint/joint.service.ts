import { randomInt } from 'node:crypto';
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { z } from 'zod';
import { GameConfig as C } from '../game/config';
import { countsForSession, jointCode } from '../game/joint';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma.service';

export const JoinSchema = z.object({ code: z.string().trim().regex(/^\d{6}$/) });

export interface JointView {
  id: string;
  /** Код для подключения; null — время подключения вышло. */
  code: string | null;
  codeUntil: string;
  endsAt: string;
  isHost: boolean;
  members: { userId: string; nickname: string; isHost: boolean }[];
}

type Db = PrismaService | Prisma.TransactionClient;

/**
 * Совместная тренировка: хозяин создаёт сессию и показывает код, друзья рядом
 * вводят его. Тренировки участников в течение сессии получают бонус (src/game/joint.ts).
 */
@Injectable()
export class JointService {
  constructor(private readonly db: PrismaService) {}

  async current(userId: string): Promise<JointView | null> {
    const member = await this.db.jointMember.findFirst({
      where: { userId, session: { endsAt: { gt: new Date() } } },
      orderBy: { joinedAt: 'desc' },
      include: { session: { include: { members: { include: { user: { select: { profile: { select: { nickname: true } } } } } } } } },
    });
    if (!member) return null;
    const s = member.session;
    const now = new Date();
    return {
      id: s.id,
      code: s.codeUntil > now ? s.code : null,
      codeUntil: s.codeUntil.toISOString(),
      endsAt: s.endsAt.toISOString(),
      isHost: s.hostId === userId,
      members: s.members
        .sort((a, b) => a.joinedAt.getTime() - b.joinedAt.getTime())
        .map((m) => ({ userId: m.userId, nickname: m.user.profile?.nickname ?? 'Игрок', isHost: m.userId === s.hostId })),
    };
  }

  /** Создать сессию; если уже хозяин активной — выдать новый код к ней. */
  async create(userId: string): Promise<JointView> {
    const now = new Date();
    const codeUntil = new Date(now.getTime() + C.jointCodeMinutes * 60_000);
    const mine = await this.current(userId);
    const code = await this.freeCode();
    if (mine?.isHost) {
      await this.db.jointSession.update({ where: { id: mine.id }, data: { code, codeUntil } });
    } else {
      await this.leave(userId);
      await this.db.jointSession.create({
        data: {
          hostId: userId,
          code,
          codeUntil,
          endsAt: new Date(now.getTime() + C.jointSessionHours * 3600_000),
          members: { create: { userId } },
        },
      });
    }
    return (await this.current(userId))!;
  }

  async join(userId: string, code: string): Promise<JointView> {
    const now = new Date();
    const session = await this.db.jointSession.findFirst({
      where: { code, codeUntil: { gt: now }, endsAt: { gt: now } },
      orderBy: { codeUntil: 'desc' },
      include: { members: true },
    });
    if (!session) throw new NotFoundException('Code not found or expired');
    if (session.members.some((m) => m.userId === userId)) return (await this.current(userId))!;
    if (session.hostId === userId) throw new BadRequestException('Own session');
    if (session.members.length >= C.jointMaxMembers) throw new ConflictException('Session is full');
    await this.leave(userId);
    await this.db.jointMember.create({ data: { sessionId: session.id, userId } });
    return (await this.current(userId))!;
  }

  /** Выйти из активных сессий. Тренировки, уже засчитанные с бонусом, не меняются. */
  async leave(userId: string): Promise<void> {
    await this.db.jointMember.deleteMany({ where: { userId, session: { endsAt: { gt: new Date() } } } });
  }

  /** Ники тех, с кем засчитывается эта тренировка. Пусто — тренировка не совместная. */
  async partnersFor(userId: string, workout: { startedAt: Date; finishedAt: Date }, db: Db = this.db): Promise<string[]> {
    const memberships = await db.jointMember.findMany({
      where: { userId, session: { endsAt: { gte: workout.startedAt } } },
      include: { session: { include: { members: { include: { user: { select: { profile: { select: { nickname: true } } } } } } } } },
    });
    const partners = new Set<string>();
    for (const m of memberships) {
      if (!countsForSession(workout, { joinedAt: m.joinedAt, endsAt: m.session.endsAt })) continue;
      for (const other of m.session.members) {
        if (other.userId !== userId) partners.add(other.user.profile?.nickname ?? 'Игрок');
      }
    }
    return [...partners];
  }

  private async freeCode(): Promise<string> {
    for (;;) {
      const code = jointCode(() => randomInt(0, 1_000_000) / 1_000_000);
      const taken = await this.db.jointSession.count({ where: { code, codeUntil: { gt: new Date() } } });
      if (taken === 0) return code;
    }
  }
}
