import { BadRequestException, ConflictException, UnprocessableEntityException } from '@nestjs/common';
import { z } from 'zod';
import {
  AURA_KINDS,
  AURA_MAX_SECONDS,
  AURA_MIN_SECONDS,
  auraPulseProblem,
  AURA_SESSIONS_PER_WEEK,
  AuraKind,
  auraLevel,
  auraSessionsToNext,
  readAuras,
} from '../game/aura';
import { mondayOf } from '../game/bots';
import { localDay } from '../common/day';
import { GameConfig } from '../game/config';
import { AURA_NORM_WINDOW_DAYS, AURA_UNLOCK_DAYS, auraNorm, NormWorkout } from '../game/aura-norm';
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

/**
 * Тренировки с пульсом для личной нормы ауры: за окно нормы, но не меньше
 * срока открытия — по первой из них считаем, прошла ли неделя.
 */
async function normWorkouts(db: Tx, userId: string, now: Date): Promise<NormWorkout[]> {
  const days = Math.max(AURA_NORM_WINDOW_DAYS, AURA_UNLOCK_DAYS) * 3;
  const rows = await db.workout.findMany({
    where: { userId, status: 'accepted', startedAt: { gte: new Date(now.getTime() - days * 86_400_000) } },
    select: { startedAt: true, pulse: true, payload: true },
    orderBy: { startedAt: 'desc' },
    take: 120,
  });
  return rows.map((r) => ({
    startedAt: r.startedAt,
    pulse: r.pulse,
    entries: (r.payload as { entries?: NormWorkout['entries'] } | null)?.entries,
  }));
}

/** Уже качал ауры до правила «сначала неделя тренировок» — не запираем снова. */
const grandfathered = (progress: Record<AuraKind, number>) => AURA_KINDS.some((k) => progress[k] > 0);

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
  // Открытие аур одно для всех видов — берём любой вид, пороги здесь не нужны.
  const norm = auraNorm({
    kind: 'fury',
    workouts: await normWorkouts(db, userId, now),
    now,
    grandfathered: grandfathered(progress),
  });
  return {
    unlock: { ready: norm.ready, daysLeft: norm.daysLeft, workoutsLeft: norm.workoutsLeft },
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
 * и показывает нагрузку (auraPulseProblem). Первая открытая — выбирается сама.
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
    const progressBefore = readAuras(p.auras);
    const norm = auraNorm({
      kind: kind as AuraKind,
      workouts: await normWorkouts(tx, userId, now),
      now,
      grandfathered: grandfathered(progressBefore),
    });
    // Сначала неделя обычных тренировок с пульсом: по ним — личная норма.
    if (!norm.ready) {
      throw new ConflictException(`Aura locked: ${norm.daysLeft} days, ${norm.workoutsLeft} workouts left`);
    }
    // Причина — в тексте ошибки, телефон показывает её человеческими словами.
    const problem = p.healthConsentAt
      ? auraPulseProblem(pulse, seconds, GameConfig.minPulseCoverage, norm)
      : 'no_consent';
    if (problem) {
      throw new UnprocessableEntityException(`Aura training needs heart rate from a watch or sensor: ${problem}`);
    }
    const progress = progressBefore;
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
