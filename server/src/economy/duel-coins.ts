import { Prisma } from '../generated/prisma/client';
import { GameConfig as C } from '../game/config';

/**
 * Дневной лимит монет за дуэли (18.11.2026: монеты гриндились повторными
 * боями с ботами). Под лимит — повторные победы, проигрыши и бои с друзьями
 * (reason 'duel'); первая победа над ботом или боссом — прогресс лестницы,
 * идёт полностью и пишется отдельно (reason 'duel_win').
 */
export const capDuelCoins = (coins: number, earnedToday: number): number =>
  Math.max(0, Math.min(coins, C.duelCoinsPerDay - earnedToday));

/** Монеты под лимитом за последние сутки. */
export async function duelCoinsToday(tx: Prisma.TransactionClient, userId: string, now = new Date()) {
  const since = new Date(now.getTime() - 24 * 3600 * 1000);
  const sum = await tx.walletTx.aggregate({
    where: { userId, reason: 'duel', createdAt: { gte: since } },
    _sum: { amount: true },
  });
  return sum._sum.amount ?? 0;
}
