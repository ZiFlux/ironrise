import { BadRequestException, ConflictException } from '@nestjs/common';
import {
  AURA_KINDS,
  AURA_SESSIONS_PER_WEEK,
  AuraKind,
  auraLevel,
  auraSessionsToNext,
  readAuras,
} from '../game/aura';
import { mondayOf } from '../game/bots';
import { localDay } from '../common/day';
import { Prisma, PrismaClient } from '../generated/prisma/client';

type Tx = Prisma.TransactionClient | PrismaClient;

/** Аура бойца для дуэли: выбранная и её уровень; нет — null. */
export async function auraSnapshot(db: Tx, userId: string) {
  const p = await db.profile.findUnique({ where: { userId }, select: { auras: true, auraEquipped: true } });
  if (!p?.auraEquipped || !AURA_KINDS.includes(p.auraEquipped as AuraKind)) return null;
  const kind = p.auraEquipped as AuraKind;
  const level = auraLevel(readAuras(p.auras)[kind]);
  return level > 0 ? { kind, level } : null;
}

/** Экран аур: уровни, прогресс, выбранная и сколько тренировок осталось на неделе. */
export async function auraState(db: Tx, userId: string, now = new Date()) {
  const p = await db.profile.findUniqueOrThrow({
    where: { userId },
    select: { auras: true, auraEquipped: true, auraWeek: true, auraSessions: true, timezone: true },
  });
  const week = mondayOf(localDay(now, p.timezone));
  const used = p.auraWeek === week ? p.auraSessions : 0;
  const progress = readAuras(p.auras);
  return {
    equipped: p.auraEquipped,
    sessionsThisWeek: used,
    perWeek: AURA_SESSIONS_PER_WEEK,
    auras: AURA_KINDS.map((kind) => ({
      kind,
      sessions: progress[kind],
      level: auraLevel(progress[kind]),
      toNext: auraSessionsToNext(progress[kind]),
    })),
  };
}

/** Тренировка ауры: +1 к её прогрессу, не больше двух в неделю. Первая открытая — выбирается сама. */
export async function trainAura(db: PrismaClient, userId: string, kind: string, now = new Date()) {
  if (!AURA_KINDS.includes(kind as AuraKind)) throw new BadRequestException('Unknown aura');
  return db.$transaction(async (tx) => {
    await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;
    const p = await tx.profile.findUniqueOrThrow({
      where: { userId },
      select: { auras: true, auraEquipped: true, auraWeek: true, auraSessions: true, timezone: true },
    });
    const week = mondayOf(localDay(now, p.timezone));
    const used = p.auraWeek === week ? p.auraSessions : 0;
    if (used >= AURA_SESSIONS_PER_WEEK) throw new ConflictException('Aura training limit for this week');
    const progress = readAuras(p.auras);
    progress[kind as AuraKind] += 1;
    await tx.profile.update({
      where: { userId },
      data: {
        auras: progress as unknown as Prisma.InputJsonValue,
        auraWeek: week,
        auraSessions: used + 1,
        auraEquipped: p.auraEquipped ?? kind,
      },
    });
    return auraState(tx, userId, now);
  });
}

/** Выбрать ауру для дуэлей (только открытую) или снять (null). */
export async function equipAura(db: PrismaClient, userId: string, kind: string | null) {
  if (kind !== null) {
    if (!AURA_KINDS.includes(kind as AuraKind)) throw new BadRequestException('Unknown aura');
    const p = await db.profile.findUniqueOrThrow({ where: { userId }, select: { auras: true } });
    if (auraLevel(readAuras(p.auras)[kind as AuraKind]) === 0) throw new ConflictException('Aura is locked');
  }
  await db.profile.update({ where: { userId }, data: { auraEquipped: kind } });
  return auraState(db, userId);
}
