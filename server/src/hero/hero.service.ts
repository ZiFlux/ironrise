import { Injectable, NotFoundException } from '@nestjs/common';
import { localDay } from '../common/day';
import { PartMap, partMap } from '../game/body-part';
import { laggingParts, levels, power } from '../game/progression';
import { currentStreak, restLimit } from '../game/streak';
import { premiumStatus, PremiumStatus } from '../game/premium';
import { nextScheduleChangeAt } from '../game/schedule';
import { Boosters, readBoosters } from '../game/streak-rewards';
import { NICKNAME_CHANGE_COINS, nextNicknameChangeAt } from '../game/nickname';
import { creatorItemsToGrant } from '../game/start-look';
import { addMusclePoints, MusclePoints, musclePointsOf } from '../game/muscles';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma.service';

/** Клиент Prisma или транзакция — у них одинаковые методы моделей. */
type Db = Pick<PrismaService, 'profile' | 'avatarPart' | 'walletTx' | 'inventoryItem' | 'workout'>;

export interface HeroState {
  nickname: string;
  /** Когда можно бесплатно сменить ник; null — уже можно. Раньше — за nicknameChangeCoins. */
  nextNicknameChangeAt: Date | null;
  nicknameChangeCoins: number;
  /** Витрина профиля; null — не настроена. */
  showcase: unknown;
  /** Бустеры за серию на следующие тренировки. */
  boosters: Boosters;
  goal: string;
  goals: string[];
  trainingFormat: string;
  /** Когда можно сменить график; null — уже можно (docs/PLAN.md 4.3). */
  nextScheduleChangeAt: Date | null;
  scheduleDays: number[];
  appearance: unknown;
  age: number | null;
  restingHr: number | null;
  timezone: string;
  xp: PartMap<number>;
  levels: PartMap<number>;
  lagging: string[];
  power: number;
  streakDays: number;
  lastActiveDay: string | null;
  coins: number;
  /** Купленные и выданные вещи (бесплатные есть у всех и сюда не входят). */
  ownedItems: string[];
  premium: PremiumStatus;
  /** Образ «Старт» для экрана прогресса; null — ещё собирается. */
  startAppearance: unknown;
  /** До какого момента образ собирается бесплатно; null — уже зафиксирован. */
  startLookUntil: Date | null;
  /** Очки отдельных мышц: как опыт распределён внутри частей тела. */
  muscles: MusclePoints;
  /** Дано ли согласие на данные о пульсе: без него пульс не принимается. */
  healthConsent: boolean;
  /** Отдельное согласие на ответы о самочувствии (п. 81). */
  wellbeingConsent: boolean;
}

@Injectable()
export class HeroService {
  constructor(private readonly db: PrismaService) {}

  async xpOf(userId: string, db: Db = this.db): Promise<PartMap<number>> {
    const rows = await db.avatarPart.findMany({ where: { userId } });
    const byPart = new Map(rows.map((r) => [r.part, r.xp]));
    return partMap((p) => byPart.get(p) ?? 0);
  }

  async coinsOf(userId: string, db: Db = this.db): Promise<number> {
    const agg = await db.walletTx.aggregate({ where: { userId }, _sum: { amount: true } });
    return agg._sum.amount ?? 0;
  }

  async state(userId: string, db: Db = this.db, now = new Date()): Promise<HeroState> {
    let profile = await db.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException('Profile not found');
    if (!profile.startLockedAt && now >= profile.startLookUntil) {
      profile = await this.lockStart(userId, profile.appearance, profile.startLookUntil, db);
    }
    const xp = await this.xpOf(userId, db);
    const lv = levels(xp);
    const streak = currentStreak({
      streakDays: profile.streakDays,
      lastActiveDay: profile.lastActiveDay,
      today: localDay(now, profile.timezone),
      maxRestDays: restLimit(profile.trainingFormat, profile.scheduleDays),
    });
    return {
      nickname: profile.nickname,
      nextNicknameChangeAt: nextNicknameChangeAt(profile.nicknameChangedAt, now),
      nicknameChangeCoins: NICKNAME_CHANGE_COINS,
      showcase: profile.showcase,
      boosters: readBoosters(profile.boosters),
      goal: profile.goal,
      goals: profile.goals,
      trainingFormat: profile.trainingFormat,
      nextScheduleChangeAt: nextScheduleChangeAt(profile.formatChangedAt, now),
      scheduleDays: profile.scheduleDays,
      appearance: profile.appearance,
      age: profile.age,
      restingHr: profile.restingHr,
      timezone: profile.timezone,
      xp,
      levels: lv,
      lagging: laggingParts(lv),
      power: power(lv, streak),
      streakDays: streak,
      lastActiveDay: profile.lastActiveDay,
      coins: await this.coinsOf(userId, db),
      ownedItems: (await db.inventoryItem.findMany({ where: { userId }, select: { itemId: true } })).map(
        (i) => i.itemId,
      ),
      premium: premiumStatus(profile, now),
      startAppearance: profile.startAppearance,
      startLookUntil: profile.startLockedAt ? null : profile.startLookUntil,
      healthConsent: profile.healthConsentAt !== null,
      wellbeingConsent: profile.wellbeingConsentAt !== null,
      muscles: (profile.musclePoints as MusclePoints | null) ?? (await this.backfillMuscles(userId, db)),
    };
  }

  /** Очки мышц по всей истории силовых тренировок — один раз, дальше копятся при отправке. */
  private async backfillMuscles(userId: string, db: Db): Promise<MusclePoints> {
    const rows = await db.workout.findMany({
      where: { userId, type: 'strength', status: 'accepted' },
      select: { payload: true, validity: true },
    });
    let points: MusclePoints = {};
    for (const w of rows) {
      const entries = (w.payload as { entries?: { exerciseId: string; sets: unknown[] }[] }).entries ?? [];
      points = addMusclePoints(points, musclePointsOf(entries, w.validity));
    }
    await db.profile.update({ where: { userId }, data: { musclePoints: points } });
    return points;
  }

  /** Зафиксировать стартовый образ: он становится «Стартом», надетые вещи редактора — навсегда за игроком. */
  async lockStart(userId: string, appearance: Prisma.JsonValue, at: Date, db: Db = this.db) {
    const look = (appearance ?? {}) as Record<string, unknown>;
    const owned = new Set(
      (await db.inventoryItem.findMany({ where: { userId }, select: { itemId: true } })).map((i) => i.itemId),
    );
    const grant = creatorItemsToGrant(look, owned);
    if (grant.length) {
      await db.inventoryItem.createMany({ data: grant.map((itemId) => ({ userId, itemId })), skipDuplicates: true });
    }
    return db.profile.update({
      where: { userId },
      data: { appearance: look as Prisma.InputJsonValue, startAppearance: look as Prisma.InputJsonValue, startLockedAt: at },
    });
  }
}
