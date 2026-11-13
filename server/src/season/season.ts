import { premiumStatus } from '../game/premium';
import {
  SEASON_LEVEL_POINTS,
  SEASON_MAX_LEVEL,
  seasonAt,
  seasonLevel,
  seasonReward,
  seasonRewardsBetween,
} from '../game/season';
import { readBoosters } from '../game/streak-rewards';
import { Prisma, PrismaClient } from '../generated/prisma/client';

type Tx = Prisma.TransactionClient | PrismaClient;

/**
 * Начислить очки сезона и выдать награды набранных уровней. Вызывается внутри
 * транзакции тренировки, дуэли или совета; с [points] = 0 — только переход на
 * новый сезон и выдача премиум-дорожки купившим премиум позже.
 */
export async function addSeasonPoints(tx: Tx, userId: string, points: number, now = new Date()) {
  const season = seasonAt(now);
  const p = await tx.profile.findUniqueOrThrow({
    where: { userId },
    select: {
      seasonNumber: true,
      seasonPoints: true,
      seasonFree: true,
      seasonPremium: true,
      boosters: true,
      isTester: true,
      premiumUntil: true,
    },
  });
  const fresh = p.seasonNumber !== season.number;
  const total = (fresh ? 0 : p.seasonPoints) + Math.max(0, points);
  const level = seasonLevel(total);
  const freeFrom = fresh ? 0 : p.seasonFree;
  const premiumFrom = fresh ? 0 : p.seasonPremium;
  const premium = premiumStatus(p, now).active;
  const free = seasonRewardsBetween(season.number, 'free', freeFrom, level);
  const paid = premium
    ? seasonRewardsBetween(season.number, 'premium', premiumFrom, level)
    : { coins: 0, items: [], boosters: { xp: 0, coins: 0 } };

  const coins = free.coins + paid.coins;
  if (coins > 0) {
    await tx.walletTx.create({ data: { userId, amount: coins, reason: `season:${season.number}` } });
  }
  const items = [...free.items, ...paid.items];
  if (items.length) {
    await tx.inventoryItem.createMany({ data: items.map((itemId) => ({ userId, itemId })), skipDuplicates: true });
  }
  const boosters = readBoosters(p.boosters);
  boosters.xp += free.boosters.xp + paid.boosters.xp;
  boosters.coins += free.boosters.coins + paid.boosters.coins;

  await tx.profile.update({
    where: { userId },
    data: {
      seasonNumber: season.number,
      seasonPoints: total,
      seasonFree: level,
      seasonPremium: premium ? level : premiumFrom,
      boosters: boosters as unknown as Prisma.InputJsonValue,
    },
  });
  return { season, points: total, level, granted: { coins, items } };
}

/** Состояние сезона для экрана: прогресс, обе дорожки и что уже выдано. */
export async function seasonState(db: PrismaClient, userId: string, now = new Date()) {
  const s = await addSeasonPoints(db, userId, 0, now);
  const p = await db.profile.findUniqueOrThrow({
    where: { userId },
    select: { seasonFree: true, seasonPremium: true, isTester: true, premiumUntil: true },
  });
  const levels = Array.from({ length: SEASON_MAX_LEVEL }, (_, i) => i + 1);
  return {
    number: s.season.number,
    name: s.season.name,
    startsAt: s.season.startsAt,
    endsAt: s.season.endsAt,
    points: s.points,
    level: s.level,
    levelPoints: SEASON_LEVEL_POINTS,
    maxLevel: SEASON_MAX_LEVEL,
    premium: premiumStatus(p, now).active,
    freeGranted: p.seasonFree,
    premiumGranted: p.seasonPremium,
    tracks: levels.map((level) => ({
      level,
      free: seasonReward(s.season.number, 'free', level),
      premium: seasonReward(s.season.number, 'premium', level),
    })),
  };
}
