import { BadRequestException, ConflictException, UnprocessableEntityException } from '@nestjs/common';
import { z } from 'zod';
import {
  AURA_KINDS,
  AURA_MAX_SECONDS,
  AURA_MIN_AVG_BPM,
  AURA_MIN_SECONDS,
  AURA_SESSIONS_PER_WEEK,
  AuraKind,
  auraLevel,
  auraSessionsToNext,
  readAuras,
} from '../game/aura';
import { mondayOf } from '../game/bots';
import { localDay } from '../common/day';
import { hasEnoughPulse } from '../game/anti-fraud';
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
    select: { auras: true, auraEquipped: true, auraWeek: true, auraSessions: true, auraLastDay: true, timezone: true },
  });
  const today = localDay(now, p.timezone);
  const week = mondayOf(today);
  const used = p.auraWeek === week ? p.auraSessions : 0;
  const progress = readAuras(p.auras);
  return {
    equipped: p.auraEquipped,
    trainedToday: p.auraLastDay === today,
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

export const AuraTrainingSchema = z.object({
  startedAt: z.coerce.date(),
  finishedAt: z.coerce.date(),
  pulse: z
    .array(z.object({ at: z.coerce.date(), bpm: z.number().int().min(30).max(230) }))
    .max(5_000)
    .default([]),
});

/**
 * Тренировка ауры: +1 к её прогрессу. Не больше одной в день и двух в неделю;
 * засчитывается только с пульсом (часы или датчик): он покрывает тренировку
 * и в среднем не ниже [AURA_MIN_AVG_BPM]. Первая открытая — выбирается сама.
 */
export async function trainAura(
  db: PrismaClient,
  userId: string,
  kind: string,
  input: z.infer<typeof AuraTrainingSchema>,
  now = new Date(),
) {
  if (!AURA_KINDS.includes(kind as AuraKind)) throw new BadRequestException('Unknown aura');
  const seconds = (input.finishedAt.getTime() - input.startedAt.getTime()) / 1000;
  if (seconds < AURA_MIN_SECONDS || seconds > AURA_MAX_SECONDS || input.finishedAt > new Date(now.getTime() + 60_000)) {
    throw new UnprocessableEntityException('Aura training must last 6-40 minutes');
  }
  return db.$transaction(async (tx) => {
    await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;
    const p = await tx.profile.findUniqueOrThrow({
      where: { userId },
      select: {
        auras: true,
        auraEquipped: true,
        auraWeek: true,
        auraSessions: true,
        auraLastDay: true,
        timezone: true,
        healthConsentAt: true,
      },
    });
    // День — по окончанию тренировки, а не по отправке: тренировку из зала без сети
    // телефон досылает позже (п. 114), и она должна лечь в свой день.
    const today = localDay(input.finishedAt < now ? input.finishedAt : now, p.timezone);
    const week = mondayOf(today);
    const used = p.auraWeek === week ? p.auraSessions : 0;
    if (p.auraLastDay === today) throw new ConflictException('Aura training already done today');
    if (used >= AURA_SESSIONS_PER_WEEK) throw new ConflictException('Aura training limit for this week');
    // Без согласия на данные о здоровье пульс не обрабатываем (152-ФЗ) — и тренировку не засчитать.
    const pulse = p.healthConsentAt
      ? input.pulse
          .filter((s) => s.at >= input.startedAt && s.at <= input.finishedAt)
          .sort((x, y) => x.at.getTime() - y.at.getTime())
      : [];
    const avg = pulse.length ? pulse.reduce((sum, s) => sum + s.bpm, 0) / pulse.length : 0;
    if (!hasEnoughPulse(pulse, seconds) || avg < AURA_MIN_AVG_BPM) {
      throw new UnprocessableEntityException('Aura training needs heart rate from a watch or sensor');
    }
    const progress = readAuras(p.auras);
    progress[kind as AuraKind] += 1;
    await tx.profile.update({
      where: { userId },
      data: {
        auras: progress as unknown as Prisma.InputJsonValue,
        auraWeek: week,
        auraSessions: used + 1,
        auraLastDay: today,
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
