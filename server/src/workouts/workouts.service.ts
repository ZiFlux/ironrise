import { BadRequestException, ConflictException, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { localDay } from '../common/day';
import { PulseSample, strengthValidity } from '../game/anti-fraud';
import { CardioSummary, scoreCardio } from '../game/cardio';
import { currentStreak, maxRestDaysInRow, streakAfterActivity } from '../game/streak';
import { StreakReward, readBoosters, streakReward, withCoinBoost, withXpBoost } from '../game/streak-rewards';
import { BodyPart } from '../game/body-part';
import { levels } from '../game/progression';
import { heroLevel, heroMilestonesDue } from '../game/social-progress';
import { addMusclePoints, MusclePoints, musclePointsOf } from '../game/muscles';
import { scoreStrength, UnknownExerciseError, WorkoutSummary, applyDailyCap, withPlanBonus } from '../game/workout';
import { Prisma } from '../generated/prisma/client';
import { withJointBonus } from '../game/joint';
import { premiumStatus, unverifiedValidityFor, withPremiumCoins } from '../game/premium';
import { HeroService, HeroState } from '../hero/hero.service';
import { JointService } from '../joint/joint.service';
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
  /** Все упражнения дня программы сделаны: +20% монет. */
  planCompleted: z.boolean().optional(),
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
    private readonly joint: JointService,
  ) {}

  submitStrength(userId: string, input: z.infer<typeof StrengthSchema>): Promise<WorkoutResult> {
    // В payload — только подходы: пульс хранится отдельно и лишь при согласии.
    const payload = { entries: input.entries, planCompleted: input.planCompleted };
    return this.submit(userId, input, 'strength', payload, input.planCompleted ?? false, async (xpBefore, restingHr, _age, isTester, pulse) => {
      const validity = strengthValidity({
        startedAt: input.startedAt,
        finishedAt: input.finishedAt,
        totalSets: input.entries.reduce((n, e) => n + e.sets.length, 0),
        pulse,
        restingHeartRate: restingHr ?? undefined,
        unverified: unverifiedValidityFor(isTester),
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
    return this.submit(userId, input, 'cardio', { activity: input.activity }, false, async (xpBefore, restingHr, age, isTester, pulse) =>
      scoreCardio({
        startedAt: input.startedAt,
        finishedAt: input.finishedAt,
        pulse,
        xpBefore,
        restingHeartRate: restingHr ?? undefined,
        maxHeartRate: age ? 220 - age : undefined,
        unverified: unverifiedValidityFor(isTester),
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
    planCompleted: boolean,
    score: (
      xpBefore: Awaited<ReturnType<HeroService['xpOf']>>,
      restingHr: number | null,
      age: number | null,
      isTester: boolean,
      /** Пульс, только если пользователь дал согласие на данные о здоровье. */
      pulse: PulseSample[],
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
      // Лимит: одна силовая и одна кардио за календарный день пользователя.
      const sameDay = await tx.workout.findFirst({
        where: { userId, type, day: localDay(finishedAt, profile.timezone), status: 'accepted' },
        select: { id: true },
      });
      if (sameDay) throw new ConflictException(`Daily limit: one ${type} workout per day`);
      // Без согласия на данные о здоровье пульс не учитывается и не сохраняется (152-ФЗ, ст. 10).
      const pulse = profile.healthConsentAt ? base.pulse : [];
      const xpBefore = await this.hero.xpOf(userId, tx);
      const day = localDay(finishedAt, profile.timezone);
      const earnedToday = await tx.xpEvent.aggregate({
        _sum: { xp: true },
        where: { userId, workout: { day } },
      });
      const partners = await this.joint.partnersFor(userId, { startedAt, finishedAt }, tx);
      // Бустеры за серию: опыт ×1,5 (до дневного потолка) и монеты ×2, по одному за тренировку.
      const boosters = readBoosters(profile.boosters);
      // Квест возвращения: была серия, но сгорела — первая тренировка после паузы +25% опыта.
      const comeback =
        profile.lastActiveDay !== null &&
        currentStreak({
          streakDays: profile.streakDays,
          lastActiveDay: profile.lastActiveDay,
          today: day,
          maxRestDays: maxRestDaysInRow(profile.scheduleDays),
        }) === 0;
      const summary = withCoinBoost(
        withPremiumCoins(
          withPlanBonus(
            applyDailyCap(
              withXpBoost(
                withJointBonus(await score(xpBefore, profile.restingHr, profile.age, profile.isTester, pulse), xpBefore, partners),
                xpBefore,
                boosters.xp > 0,
                comeback,
              ),
              xpBefore,
              earnedToday._sum.xp ?? 0,
            ),
            planCompleted,
          ),
          premiumStatus(profile).active,
        ),
        boosters.coins > 0,
      );
      const usedBoosters = { xp: boosters.xp > 0, coins: boosters.coins > 0 };
      boosters.xp = Math.max(0, boosters.xp - 1);
      boosters.coins = Math.max(0, boosters.coins - 1);

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
          pulse: pulse.map((s) => ({ at: s.at.toISOString(), bpm: s.bpm })),
        },
      });

      if (type === 'strength' && profile.musclePoints !== null) {
        const entries = (payload as { entries: { exerciseId: string; sets: unknown[] }[] }).entries;
        await tx.profile.update({
          where: { userId },
          data: {
            musclePoints: addMusclePoints(
              profile.musclePoints as MusclePoints,
              musclePointsOf(entries, summary.validity),
            ) as Prisma.InputJsonValue,
          },
        });
      }

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
      let streak: StreakReward | null = null;
      if (last === null || day >= last) {
        const maxRest = maxRestDaysInRow(profile.scheduleDays);
        const after = streakAfterActivity({
          currentStreak: profile.streakDays,
          lastActiveDay: last,
          today: day,
          maxRestDays: maxRest,
        });
        // Сгоревшая серия начинается заново: награды — с первого дня.
        const before = currentStreak({ streakDays: profile.streakDays, lastActiveDay: last, today: day, maxRestDays: maxRest });
        streak = streakReward(before, after);
        if (streak) {
          boosters.xp += streak.boosters.xp;
          boosters.coins += streak.boosters.coins;
          await tx.walletTx.create({ data: { userId, amount: streak.coins, reason: 'streak', refId: workout.id } });
          if (streak.items.length) {
            await tx.inventoryItem.createMany({
              data: streak.items.map((itemId) => ({ userId, itemId })),
              skipDuplicates: true,
            });
          }
          if (streak.xp > 0) {
            // Опыт за рубеж — самой отстающей части.
            const xpNow = await this.hero.xpOf(userId, tx);
            const part = (Object.entries(xpNow) as [BodyPart, number][]).reduce((a, b) => (b[1] < a[1] ? b : a))[0];
            await tx.avatarPart.update({ where: { userId_part: { userId, part } }, data: { xp: { increment: streak.xp } } });
            await tx.xpEvent.create({
              data: { userId, workoutId: workout.id, part, xp: streak.xp, validity: 1, wasLagging: true },
            });
          }
        }
        await tx.profile.update({
          where: { userId },
          data: { streakDays: after, lastActiveDay: day },
        });
      }
      // Лента друзей: новые уровни, рубежи серии, возвращение. Без пульса и подходов.
      const feed: { kind: string; data: object }[] = [];
      for (const g of summary.gains) {
        if (g.levelAfter > g.levelBefore) feed.push({ kind: 'level_up', data: { part: g.part, level: g.levelAfter } });
      }
      for (const d of streak?.milestones ?? []) feed.push({ kind: 'streak', data: { days: d } });
      if (comeback) feed.push({ kind: 'comeback', data: {} });

      // Вехи героя: средний уровень 5/10/20 — вещь в подарок, поза победы, аватарки.
      const level = heroLevel(levels(await this.hero.xpOf(userId, tx)));
      const due = heroMilestonesDue(profile.heroMilestone, level);
      if (due.length) {
        await tx.inventoryItem.createMany({
          data: due.map((m) => ({ userId, itemId: m.item })),
          skipDuplicates: true,
        });
        await tx.profile.update({ where: { userId }, data: { heroMilestone: due[due.length - 1].level } });
        for (const m of due) feed.push({ kind: 'hero_level', data: { level: m.level, item: m.item } });
      }
      if (feed.length) {
        await tx.feedEvent.createMany({
          data: feed.map((e) => ({ userId, kind: e.kind, data: e.data as Prisma.InputJsonValue })),
        });
      }

      if (usedBoosters.xp || usedBoosters.coins || streak) {
        await tx.profile.update({ where: { userId }, data: { boosters: boosters as unknown as Prisma.InputJsonValue } });
      }

      return {
        workoutId: workout.id,
        summary,
        streakReward: streak,
        boostersUsed: usedBoosters,
        comeback,
        heroMilestones: due,
        hero: await this.hero.state(userId, tx),
        duplicate: false,
      };
    });
  }
}
