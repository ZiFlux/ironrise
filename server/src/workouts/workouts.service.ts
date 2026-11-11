import { BadRequestException, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { localDay } from '../common/day';
import { PulseSample, strengthValidity } from '../game/anti-fraud';
import { CardioSummary, scoreCardio } from '../game/cardio';
import { maxRestDaysInRow, streakAfterActivity } from '../game/streak';
import { scoreStrength, UnknownExerciseError, WorkoutSummary, applyDailyCap } from '../game/workout';
import { Prisma } from '../generated/prisma/client';
import { HeroService, HeroState } from '../hero/hero.service';
import { PrismaService } from '../prisma.service';

const MAX_DURATION_MS = 6 * 3600_000;
const CLOCK_SKEW_MS = 5 * 60_000;

const PulseSchema = z
  .array(z.object({ at: z.coerce.date(), bpm: z.number().int().min(30).max(230) }))
  .max(20_000)
  .default([]);

const Base = z.object({
  /** Id тренировки на телефоне: повторная отправка не начислит опыт дважды. */
  clientId: z.string().min(8).max(64),
  startedAt: z.coerce.date(),
  finishedAt: z.coerce.date(),
  pulse: PulseSchema,
});

export const StrengthSchema = Base.extend({
  entries: z
    .array(
      z.object({
        exerciseId: z.string().min(1).max(64),
        sets: z
          .array(z.object({ weight: z.number().min(0).max(1000), reps: z.number().int().min(1).max(1000) }))
          .min(1)
          .max(50),
      }),
    )
    .min(1)
    .max(30),
});

export const CardioSchema = Base.extend({
  activity: z.enum(['run', 'walk', 'bike', 'elliptical', 'other']),
});

export interface WorkoutResult {
  workoutId: string;
  summary: WorkoutSummary | CardioSummary;
  hero: HeroState;
  /** true — эта тренировка уже была принята раньше, ничего не начислено повторно. */
  duplicate: boolean;
}

@Injectable()
export class WorkoutsService {
  constructor(
    private readonly db: PrismaService,
    private readonly hero: HeroService,
  ) {}

  submitStrength(userId: string, input: z.infer<typeof StrengthSchema>): Promise<WorkoutResult> {
    return this.submit(userId, input, 'strength', input, async (xpBefore, restingHr) => {
      const validity = strengthValidity({
        startedAt: input.startedAt,
        finishedAt: input.finishedAt,
        totalSets: input.entries.reduce((n, e) => n + e.sets.length, 0),
        pulse: input.pulse,
        restingHeartRate: restingHr ?? undefined,
      });
      try {
        return scoreStrength(input, xpBefore, validity);
      } catch (e) {
        if (e instanceof UnknownExerciseError) throw new BadRequestException(e.message);
        throw e;
      }
    });
  }

  submitCardio(userId: string, input: z.infer<typeof CardioSchema>): Promise<WorkoutResult> {
    return this.submit(userId, input, 'cardio', { activity: input.activity }, async (xpBefore, restingHr, age) =>
      scoreCardio({
        startedAt: input.startedAt,
        finishedAt: input.finishedAt,
        pulse: input.pulse,
        xpBefore,
        restingHeartRate: restingHr ?? undefined,
        maxHeartRate: age ? 220 - age : undefined,
      }),
    );
  }

  /**
   * Общий путь: проверка времени, блокировка профиля (параллельные отправки не гонятся
   * за опытом), идемпотентность по clientId, расчёт на сервере и запись журналов.
   */
  private async submit(
    userId: string,
    base: { clientId: string; startedAt: Date; finishedAt: Date; pulse: PulseSample[] },
    type: 'strength' | 'cardio',
    payload: object,
    score: (
      xpBefore: Awaited<ReturnType<HeroService['xpOf']>>,
      restingHr: number | null,
      age: number | null,
    ) => Promise<WorkoutSummary | CardioSummary>,
  ): Promise<WorkoutResult> {
    const { startedAt, finishedAt } = base;
    const now = Date.now();
    if (finishedAt <= startedAt) throw new BadRequestException('finishedAt must be after startedAt');
    if (finishedAt.getTime() - startedAt.getTime() > MAX_DURATION_MS) {
      throw new BadRequestException('Workout is longer than 6 hours');
    }
    if (finishedAt.getTime() > now + CLOCK_SKEW_MS) throw new BadRequestException('finishedAt is in the future');

    return this.db.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;

      const existing = await tx.workout.findUnique({
        where: { userId_clientId: { userId, clientId: base.clientId } },
      });
      if (existing) {
        const stored = existing.payload as unknown as { summary: WorkoutSummary | CardioSummary };
        return { workoutId: existing.id, summary: stored.summary, hero: await this.hero.state(userId, tx), duplicate: true };
      }

      const profile = await tx.profile.findUniqueOrThrow({ where: { userId } });
      const xpBefore = await this.hero.xpOf(userId, tx);
      const day = localDay(finishedAt, profile.timezone);
      const earnedToday = await tx.xpEvent.aggregate({
        _sum: { xp: true },
        where: { userId, workout: { day } },
      });
      const summary = applyDailyCap(
        await score(xpBefore, profile.restingHr, profile.age),
        xpBefore,
        earnedToday._sum.xp ?? 0,
      );

      const workout = await tx.workout.create({
        data: {
          userId,
          clientId: base.clientId,
          type,
          startedAt,
          endedAt: finishedAt,
          day,
          validity: summary.validity,
          payload: { ...payload, summary } as unknown as Prisma.InputJsonValue,
          pulse: base.pulse.map((s) => ({ at: s.at.toISOString(), bpm: s.bpm })),
        },
      });

      for (const g of summary.gains) {
        await tx.avatarPart.update({
          where: { userId_part: { userId, part: g.part } },
          data: { xp: { increment: g.xp } },
        });
      }
      if (summary.gains.length > 0) {
        await tx.xpEvent.createMany({
          data: summary.gains.map((g) => ({
            userId,
            workoutId: workout.id,
            part: g.part,
            xp: g.xp,
            validity: summary.validity,
            wasLagging: g.wasLagging,
          })),
        });
      }
      if (summary.coins > 0) {
        await tx.walletTx.create({ data: { userId, amount: summary.coins, reason: `workout:${type}`, refId: workout.id } });
      }

      // Тренировка, присланная задним числом, не двигает серию назад.
      const last = profile.lastActiveDay;
      if (last === null || day >= last) {
        await tx.profile.update({
          where: { userId },
          data: {
            streakDays: streakAfterActivity({
              currentStreak: profile.streakDays,
              lastActiveDay: last,
              today: day,
              maxRestDays: maxRestDaysInRow(profile.scheduleDays),
            }),
            lastActiveDay: day,
          },
        });
      }

      return { workoutId: workout.id, summary, hero: await this.hero.state(userId, tx), duplicate: false };
    });
  }
}
