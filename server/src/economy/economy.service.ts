import { BadRequestException, ConflictException, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { localDay } from '../common/day';
import { Bot, botsForDay, LEAGUE_WIN_POINTS, LEAGUE_WORKOUT_POINTS, mondayOf, weeklyLeague } from '../game/bots';
import { GameConfig as C } from '../game/config';
import { simulateDuel } from '../game/duel';
import { priceOf } from '../game/shop';
import { Prisma } from '../generated/prisma/client';
import { HeroService } from '../hero/hero.service';
import { PrismaService } from '../prisma.service';

export const BuySchema = z.object({
  itemIds: z.array(z.string().min(1).max(64)).max(20),
  /** Образ после покупки (AvatarLook с клиента). */
  appearance: z.record(z.string(), z.unknown()),
});

export const AppearanceSchema = z.object({ appearance: z.record(z.string(), z.unknown()) });

const lockProfile = (tx: Prisma.TransactionClient, userId: string) =>
  tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;

@Injectable()
export class EconomyService {
  constructor(
    private readonly db: PrismaService,
    private readonly hero: HeroService,
  ) {}

  /**
   * Купить вещи и надеть образ. Цены — только серверные; уже купленные и
   * бесплатные не списываются. Профиль блокируется, чтобы две покупки не ушли в минус.
   */
  buy(userId: string, input: z.infer<typeof BuySchema>) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const unknown = input.itemIds.filter((id) => priceOf(id) === undefined);
      if (unknown.length) throw new BadRequestException(`Unknown items: ${unknown.join(', ')}`);

      const owned = new Set(
        (await tx.inventoryItem.findMany({ where: { userId }, select: { itemId: true } })).map((i) => i.itemId),
      );
      const toBuy = [...new Set(input.itemIds)].filter((id) => !owned.has(id) && priceOf(id)! > 0);
      const total = toBuy.reduce((s, id) => s + priceOf(id)!, 0);
      if (total > (await this.hero.coinsOf(userId, tx))) throw new ConflictException('Not enough coins');

      if (toBuy.length) {
        await tx.inventoryItem.createMany({ data: toBuy.map((itemId) => ({ userId, itemId })) });
        await tx.walletTx.createMany({
          data: toBuy.map((id) => ({ userId, amount: -priceOf(id)!, reason: 'shop', refId: id })),
        });
      }
      await tx.profile.update({
        where: { userId },
        data: { appearance: input.appearance as Prisma.InputJsonValue },
      });
      return this.hero.state(userId, tx);
    });
  }

  /**
   * Сохранить образ из купленного. Сервер пока не сверяет образ с инвентарём:
   * косметика не влияет на силу, проверка появится вместе с серверным каталогом образов.
   */
  async setAppearance(userId: string, appearance: Record<string, unknown>) {
    await this.db.profile.update({ where: { userId }, data: { appearance: appearance as Prisma.InputJsonValue } });
    return this.hero.state(userId);
  }

  private async today(userId: string): Promise<string> {
    const p = await this.db.profile.findUniqueOrThrow({ where: { userId }, select: { timezone: true } });
    return localDay(new Date(), p.timezone);
  }

  /** Боты дня и итоги боёв с ними за сегодня. */
  async bots(userId: string) {
    const day = await this.today(userId);
    const hero = await this.hero.state(userId);
    const fought = await this.db.duel.findMany({
      where: { attackerId: userId, day, opponentKind: 'bot' },
      select: { opponentId: true, attackerWon: true },
    });
    const results = Object.fromEntries(fought.map((f) => [f.opponentId, f.attackerWon]));
    return { day, bots: botsForDay(hero, day), results };
  }

  /** Бой с ботом дня: исход, лог и монеты считает сервер. Каждого бота — раз в день. */
  async fightBot(userId: string, botId: string) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const profile = await tx.profile.findUniqueOrThrow({ where: { userId } });
      const day = localDay(new Date(), profile.timezone);
      const hero = await this.hero.state(userId, tx);
      const bot: Bot | undefined = botsForDay(hero, day).find((b) => b.id === botId);
      if (!bot) throw new BadRequestException('No such bot today');
      if (await tx.duel.findUnique({ where: { attackerId_opponentId_day: { attackerId: userId, opponentId: botId, day } } })) {
        throw new ConflictException('Already fought this bot today');
      }

      const attacker = { id: userId, name: hero.nickname, levels: hero.levels, streakDays: hero.streakDays };
      const seed = Math.floor(Math.random() * 2 ** 31);
      const result = simulateDuel(attacker, bot, seed);
      const coins = result.attackerWon ? C.duelWinCoins : C.duelLossCoins;
      const duel = await tx.duel.create({
        data: {
          attackerId: userId,
          opponentKind: 'bot',
          opponentId: bot.id,
          day,
          seed,
          snapshotA: attacker as unknown as Prisma.InputJsonValue,
          snapshotD: bot as unknown as Prisma.InputJsonValue,
          powerA: result.powerA,
          powerD: result.powerD,
          log: result.log as unknown as Prisma.InputJsonValue,
          attackerWon: result.attackerWon,
          coins,
        },
      });
      await tx.walletTx.create({ data: { userId, amount: coins, reason: 'duel', refId: duel.id } });
      return { duelId: duel.id, attacker, defender: bot, ...result, coins, hero: await this.hero.state(userId, tx) };
    });
  }

  /** Недельная лига по настоящим тренировочным дням и победам. */
  async league(userId: string) {
    const day = await this.today(userId);
    const monday = mondayOf(day);
    const hero = await this.hero.state(userId);
    const trainedDays = (
      await this.db.workout.findMany({
        where: { userId, day: { gte: monday, lte: day } },
        distinct: ['day'],
        select: { day: true },
      })
    ).length;
    const wins = await this.db.duel.count({ where: { attackerId: userId, attackerWon: true, day: { gte: monday, lte: day } } });
    const playerPoints = trainedDays * LEAGUE_WORKOUT_POINTS + wins * LEAGUE_WIN_POINTS;
    return {
      day,
      trainedDays,
      wins,
      entries: weeklyLeague({ today: day, playerName: hero.nickname, playerPoints }),
    };
  }
}
