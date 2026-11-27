import { BodyPart } from '../game/body-part';
import { addMusclePoints, MusclePoints, musclePointsOf } from '../game/muscles';
import { SEASON_POINTS, seasonAt } from '../game/season';
import { WorkoutSummary } from '../game/workout';
import { Prisma } from '../generated/prisma/client';

/**
 * Что было в профиле до тренировки — для отката (пишется в payload.undo при записи).
 * Старые тренировки снимка не имеют: у них серия и бустеры не откатываются.
 */
export interface UndoSnapshot {
  streakDays: number;
  lastActiveDay: string | null;
  boosters: unknown;
  heroMilestone: number;
}

export interface UndoResult {
  workoutId: string;
  type: 'strength' | 'cardio';
  day: string;
  xp: Partial<Record<BodyPart, number>>;
  coins: number;
  seasonPoints: number;
  streakRestored: boolean;
}

/**
 * Откатить тренировку целиком (админка, «вернуться к тренировке»): снять опыт по
 * частям тела, монеты за неё и за рубеж серии, очки мышц и сезона, вернуть серию
 * и бустеры, как были до неё, и удалить запись — день снова свободен для тренировки.
 * Журналы опыта и монет — append-only: откат пишется встречными записями.
 * Не откатываются: вещи за рубеж серии и вехи героя, награды уровней сезона, лента.
 * Вызывать в транзакции.
 */
export async function undoWorkout(tx: Prisma.TransactionClient, workoutId: string): Promise<UndoResult> {
  const w = await tx.workout.findUniqueOrThrow({ where: { id: workoutId } });
  const userId = w.userId;
  await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;
  const profile = await tx.profile.findUniqueOrThrow({ where: { userId } });
  const payload = (w.payload ?? {}) as {
    entries?: { exerciseId: string; sets: unknown[] }[];
    planCompleted?: boolean;
    summary?: WorkoutSummary;
    undo?: UndoSnapshot;
  };

  // Опыт: всё, что начислено этой тренировкой (и за рубеж серии), — назад, не ниже 0.
  const events = await tx.xpEvent.findMany({ where: { workoutId } });
  const byPart: Partial<Record<BodyPart, number>> = {};
  for (const e of events) byPart[e.part as BodyPart] = (byPart[e.part as BodyPart] ?? 0) + e.xp;
  const xp: Partial<Record<BodyPart, number>> = {};
  for (const [part, gained] of Object.entries(byPart) as [BodyPart, number][]) {
    const row = await tx.avatarPart.findUnique({ where: { userId_part: { userId, part } } });
    if (!row) continue;
    const next = Math.max(0, row.xp - gained);
    await tx.avatarPart.update({ where: { userId_part: { userId, part } }, data: { xp: next } });
    if (next !== row.xp) {
      await tx.xpEvent.create({ data: { userId, part, xp: next - row.xp, validity: 1, wasLagging: false } });
    }
    xp[part] = next - row.xp;
  }

  // Монеты за тренировку и за рубеж серии — встречной записью.
  const paid = await tx.walletTx.aggregate({ where: { userId, refId: workoutId }, _sum: { amount: true } });
  const coins = paid._sum.amount ?? 0;
  if (coins !== 0) {
    await tx.walletTx.create({ data: { userId, amount: -coins, reason: 'undo', refId: workoutId } });
  }

  // Очки мышц (пропорции героя) — как прибавлялись, так и вычитаем.
  const validity = payload.summary?.validity ?? w.validity;
  const data: Prisma.ProfileUpdateInput = {};
  if (w.type === 'strength' && profile.musclePoints !== null && payload.entries) {
    const minus = Object.fromEntries(
      Object.entries(musclePointsOf(payload.entries, validity)).map(([m, v]) => [m, -(v as number)]),
    ) as MusclePoints;
    const next = addMusclePoints(profile.musclePoints as MusclePoints, minus);
    for (const m of Object.keys(next) as (keyof MusclePoints)[]) next[m] = Math.max(0, next[m] ?? 0);
    data.musclePoints = next as Prisma.InputJsonValue;
  }

  // Очки сезона — если сезон тот же.
  const points =
    w.type === 'strength' ? SEASON_POINTS.strength(validity, payload.planCompleted ?? false) : SEASON_POINTS.cardio(validity);
  let seasonPoints = 0;
  if (profile.seasonNumber === seasonAt(w.endedAt).number) {
    seasonPoints = Math.min(points, profile.seasonPoints);
    data.seasonPoints = profile.seasonPoints - seasonPoints;
  }

  // Серия и бустеры — как до тренировки, если после неё дней с тренировкой не было.
  const snap = payload.undo;
  const later = await tx.workout.count({ where: { userId, id: { not: workoutId }, day: { gte: w.day } } });
  const streakRestored = !!snap && later === 0 && profile.lastActiveDay === w.day;
  if (snap && streakRestored) {
    data.streakDays = snap.streakDays;
    data.lastActiveDay = snap.lastActiveDay;
    data.boosters = snap.boosters as Prisma.InputJsonValue;
  }
  if (Object.keys(data).length) await tx.profile.update({ where: { userId }, data });

  await tx.workout.delete({ where: { id: workoutId } });
  return { workoutId, type: w.type, day: w.day, xp, coins: -coins, seasonPoints: -seasonPoints, streakRestored };
}
