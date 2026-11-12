import { Injectable, NotFoundException } from '@nestjs/common';
import { localDay } from '../common/day';
import { PartMap, partMap } from '../game/body-part';
import { laggingParts, levels, power } from '../game/progression';
import { currentStreak, maxRestDaysInRow } from '../game/streak';
import { nextScheduleChangeAt } from '../game/schedule';
import { PrismaService } from '../prisma.service';

/** Клиент Prisma или транзакция — у них одинаковые методы моделей. */
type Db = Pick<PrismaService, 'profile' | 'avatarPart' | 'walletTx' | 'inventoryItem'>;

export interface HeroState {
  nickname: string;
  goal: string;
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
  /** Купленные вещи магазина (бесплатные есть у всех и сюда не входят). */
  ownedItems: string[];
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
    const profile = await db.profile.findUnique({ where: { userId } });
    if (!profile) throw new NotFoundException('Profile not found');
    const xp = await this.xpOf(userId, db);
    const lv = levels(xp);
    const streak = currentStreak({
      streakDays: profile.streakDays,
      lastActiveDay: profile.lastActiveDay,
      today: localDay(now, profile.timezone),
      maxRestDays: maxRestDaysInRow(profile.scheduleDays),
    });
    return {
      nickname: profile.nickname,
      goal: profile.goal,
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
    };
  }
}
