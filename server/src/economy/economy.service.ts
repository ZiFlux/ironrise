import { BadRequestException, ConflictException, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { localDay } from '../common/day';
import { Bot, botsForDay, LEAGUE_WIN_POINTS, LEAGUE_WORKOUT_POINTS, mondayOf, weeklyLeague } from '../game/bots';
import { addWeeks, DEMOTE_BOTTOM, sundayOf, LEAGUE_TIERS, PROMOTE_TOP, settleWeek, WeekSettlement } from '../game/league';
import { GameConfig as C } from '../game/config';
import { simulateDuel } from '../game/duel';
import { unpaidItems } from '../game/looks';
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

/** Образ разбирается на вещи; некупленные платные — ошибка. */
export const assertLookOwned = (look: Record<string, unknown>, owned: ReadonlySet<string>) => {
  const unpaid = unpaidItems(look, owned);
  if (unpaid === null) throw new BadRequestException('Invalid look');
  if (unpaid.length) throw new BadRequestException(`Items are not owned: ${unpaid.join(', ')}`);
};

const lockProfile = (tx: Prisma.TransactionClient, userId: string) =>
  tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;

/** Дольше не подводим по неделям: человек начинает лигу заново. */
const MAX_WEEKS_TO_SETTLE = 26;

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
      assertLookOwned(input.appearance, new Set([...owned, ...toBuy]));
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

  /** Сохранить образ: всё надетое должно быть куплено или бесплатно. */
  async setAppearance(userId: string, appearance: Record<string, unknown>) {
    const owned = await this.db.inventoryItem.findMany({ where: { userId }, select: { itemId: true } });
    assertLookOwned(appearance, new Set(owned.map((i) => i.itemId)));
    await this.db.profile.update({ where: { userId }, data: { appearance: appearance as Prisma.InputJsonValue } });
    return this.hero.state(userId);
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

  /** Тренировочные дни и победы в дуэлях за неделю [monday; today]. */
  async weeklyStats(userId: string, monday: string, today: string) {
    const trainedDays = (
      await this.db.workout.findMany({
        where: { userId, day: { gte: monday, lte: today } },
        distinct: ['day'],
        select: { day: true },
      })
    ).length;
    const wins = await this.db.duel.count({
      where: { attackerId: userId, attackerWon: true, day: { gte: monday, lte: today } },
    });
    return { trainedDays, wins, points: trainedDays * LEAGUE_WORKOUT_POINTS + wins * LEAGUE_WIN_POINTS };
  }

  /** Недельная лига по настоящим тренировочным дням и победам, с уровнем лиги. */
  async league(userId: string) {
    const day = await this.today(userId);
    const hero = await this.hero.state(userId);
    const { tier, last } = await this.settleLeague(userId, hero.nickname, mondayOf(day));
    const { trainedDays, wins, points } = await this.weeklyStats(userId, mondayOf(day), day);
    return {
      day,
      trainedDays,
      wins,
      tier,
      tierName: LEAGUE_TIERS[tier],
      promoteTop: PROMOTE_TOP,
      demoteBottom: DEMOTE_BOTTOM,
      lastWeek: last,
      entries: weeklyLeague({ today: day, playerName: hero.nickname, playerPoints: points, tier }),
    };
  }

  /**
   * Подвести все прошедшие недели по очереди, по настоящим тренировкам каждой.
   * Так лига сдвигается правильно, даже если человек не открывал приложение месяц.
   */
  private async settleLeague(userId: string, nickname: string, currentMonday: string) {
    const profile = await this.db.profile.findUniqueOrThrow({
      where: { userId },
      select: { leagueTier: true, leagueWeek: true, leagueLast: true },
    });
    let tier = profile.leagueTier;
    let last = profile.leagueLast as WeekSettlement | null;
    if (profile.leagueWeek === null) {
      await this.db.profile.update({ where: { userId }, data: { leagueWeek: currentMonday } });
      return { tier, last };
    }
    let week = profile.leagueWeek;
    for (let n = 0; week < currentMonday && n < MAX_WEEKS_TO_SETTLE; n++) {
      const sunday = sundayOf(week);
      const stats = await this.weeklyStats(userId, week, sunday);
      const table = weeklyLeague({ today: sunday, playerName: nickname, playerPoints: stats.points, tier });
      const rank = table.findIndex((e) => e.isPlayer) + 1;
      last = settleWeek({ week, tier, rank, size: table.length, trainedDays: stats.trainedDays });
      tier = last.tierAfter;
      week = addWeeks(week, 1);
    }
    if (week < currentMonday) tier = 0; // полгода без входа — снова с бронзы
    if (profile.leagueWeek !== currentMonday) {
      await this.db.profile.update({
        where: { userId },
        data: {
          leagueTier: tier,
          leagueWeek: currentMonday,
          leagueLast: last === null ? Prisma.DbNull : (last as unknown as Prisma.InputJsonValue),
        },
      });
    }
    return { tier, last };
  }

  /** Награда за «Совет дня»: раз в календарный день пользователя. */
  async tipReward(userId: string) {
    const day = await this.today(userId);
    return this.db.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;
      const profile = await tx.profile.findUniqueOrThrow({ where: { userId }, select: { tipRewardDay: true } });
      if (profile.tipRewardDay === day) throw new ConflictException('Награда за совет сегодня уже получена');
      await tx.walletTx.create({ data: { userId, amount: C.tipCoins, reason: 'tip' } });
      await tx.profile.update({ where: { userId }, data: { tipRewardDay: day } });
      return { coins: C.tipCoins };
    });
  }

  async today(userId: string): Promise<string> {
    const p = await this.db.profile.findUniqueOrThrow({ where: { userId }, select: { timezone: true } });
    return localDay(new Date(), p.timezone);
  }
}
