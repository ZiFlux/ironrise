import { stepsXp } from '../game/steps';
import { BadRequestException, ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { z } from 'zod';
import { localDay } from '../common/day';
import { Bot, botsForDay, LEAGUE_WIN_POINTS, LEAGUE_WORKOUT_POINTS, liveLeague, mondayOf } from '../game/bots';
import { addWeeks, DEMOTE_BOTTOM, sundayOf, LEAGUE_TIERS, PROMOTE_TOP, settleWeek, WeekSettlement } from '../game/league';
import { GameConfig as C } from '../game/config';
import { simulateDuel } from '../game/duel';
import { unpaidItems } from '../game/looks';
import { MIN_TRAINING_DAYS, nextScheduleChangeAt } from '../game/schedule';
import { premiumStatus } from '../game/premium';
import { PREMIUM_ITEMS, priceOf, ACHIEVEMENT_ITEMS, Achievement } from '../game/shop';
import { CREATOR_ITEMS, creatorOpen } from '../game/start-look';
import {
  NICKNAME_CHANGE_COINS,
  NicknameSchema,
  isReservedNickname,
  nextNicknameChangeAt,
  nicknameHoldUntil,
  nicknameKey,
} from '../game/nickname';
import { Prisma } from '../generated/prisma/client';
import { HeroService } from '../hero/hero.service';
import { PrismaService } from '../prisma.service';
import { SEASON_POINTS } from '../game/season';
import { addSeasonPoints, seasonState } from '../season/season';

export const BuySchema = z.object({
  itemIds: z.array(z.string().min(1).max(64)).max(20),
  /** Образ после покупки (AvatarLook с клиента). */
  appearance: z.record(z.string(), z.unknown()),
});

/** Итог опроса по советам дня. Старые клиенты шлют пустое тело — один верный ответ. */
export const TipRewardSchema = z
  .object({
    correct: z.number().int().min(0).max(C.tipsPerDayMax).default(1),
    total: z.number().int().min(1).max(C.tipsPerDayMax).default(1),
  })
  .refine((b) => b.correct <= b.total, { message: 'correct > total' });

/** Монеты за опрос: за каждый верный ответ и бонус, если верны все. */
export const tipQuizCoins = (correct: number, total: number) =>
  correct * C.tipCoinsPerAnswer + (correct === total ? C.tipQuizBonus : 0);

/** Витрина профиля: готовая аватарка, фон и поза героя (null — сам меняет позы). */
export const ShowcaseSchema = z.object({
  icon: z.string().regex(/^[a-z_]{1,24}$/),
  background: z.number().int().min(0).max(31),
  pose: z.enum(['relaxed', 'doubleBiceps', 'latSpread', 'handsBehindHead', 'victory']).nullable().optional(),
});

/** Шаги за сегодня из Health Connect (день отдыха). */
export const StepsSchema = z.object({ steps: z.number().int().min(0).max(100_000) });


export const NicknameChangeSchema = z.object({
  nickname: NicknameSchema,
  /** Сменить раньше срока за NICKNAME_CHANGE_COINS монет. */
  paid: z.boolean().optional(),
});

export const ScheduleSchema = z.object({
  trainingFormat: z.string().min(1).max(32),
  scheduleDays: z
    .array(z.number().int().min(0).max(6))
    .min(MIN_TRAINING_DAYS)
    .max(7)
    .refine((d) => new Set(d).size === d.length, 'days must be unique'),
});

export const AppearanceSchema = z.object({ appearance: z.record(z.string(), z.unknown()) });

export const StartLookSchema = z.object({
  appearance: z.record(z.string(), z.unknown()),
  /** true — зафиксировать образ как «Старт» досрочно. */
  lock: z.boolean().default(false),
});

/** Образ разбирается на вещи; некупленные платные — ошибка. */
export const assertLookOwned = (look: Record<string, unknown>, owned: ReadonlySet<string>) => {
  const unpaid = unpaidItems(look, owned);
  if (unpaid === null) throw new BadRequestException('Invalid look');
  if (unpaid.length) throw new BadRequestException(`Items are not owned: ${unpaid.join(', ')}`);
};

const lockProfile = (tx: Prisma.TransactionClient, userId: string) =>
  tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;

/** Купленное и выданное; пока открыт редактор стартового образа — ещё и его вещи. */
const wearable = async (db: Pick<Prisma.TransactionClient, 'inventoryItem' | 'profile'>, userId: string) => {
  const owned = (await db.inventoryItem.findMany({ where: { userId }, select: { itemId: true } })).map((i) => i.itemId);
  const p = await db.profile.findUniqueOrThrow({ where: { userId }, select: { startLockedAt: true, startLookUntil: true } });
  return new Set([...owned, ...(creatorOpen(p) ? CREATOR_ITEMS : [])]);
};

const HOUR = 60 * 60 * 1000;

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
      const profile = await tx.profile.findUniqueOrThrow({ where: { userId }, select: { isTester: true, premiumUntil: true } });

      await this.hero.state(userId, tx); // зафиксирует стартовый образ, если окно уже закрылось
      const all = await wearable(tx, userId);
      const toBuy = [...new Set(input.itemIds)].filter((id) => !all.has(id) && priceOf(id)! > 0);
      if (toBuy.some((id) => PREMIUM_ITEMS.has(id)) && !premiumStatus(profile).active) {
        throw new ForbiddenException('Premium items need a subscription');
      }
      assertLookOwned(input.appearance, new Set([...all, ...toBuy]));
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

  /** Сменить график: раз в 7 дней, первая смена — сразу. 409 с датой, если рано. */
  changeSchedule(userId: string, input: z.infer<typeof ScheduleSchema>) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const p = await tx.profile.findUniqueOrThrow({ where: { userId }, select: { formatChangedAt: true } });
      const now = new Date();
      const next = nextScheduleChangeAt(p.formatChangedAt, now);
      if (next) {
        throw new ConflictException({ message: 'Schedule can be changed once a week', nextScheduleChangeAt: next });
      }
      await tx.profile.update({
        where: { userId },
        data: {
          trainingFormat: input.trainingFormat,
          scheduleDays: [...input.scheduleDays].sort((a, b) => a - b),
          formatChangedAt: now,
        },
      });
      return this.hero.state(userId, tx);
    });
  }

  /**
   * Сменить ник: раз в 30 дней (первая смена — сразу), раньше — за монеты (paid).
   * Ключ без регистра и похожих букв должен быть свободен и не в брони у другого игрока;
   * прежний ник 30 дней закреплён за игроком. Смена только регистра или пробелов — бесплатно и без кулдауна.
   */
  changeNickname(userId: string, input: z.infer<typeof NicknameChangeSchema>) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const p = await tx.profile.findUniqueOrThrow({
        where: { userId },
        select: { nickname: true, nicknameKey: true, nicknameChangedAt: true },
      });
      const now = new Date();
      const key = nicknameKey(input.nickname);
      if (input.nickname === p.nickname) return this.hero.state(userId, tx);
      if (isReservedNickname(input.nickname)) throw new BadRequestException('Nickname is reserved');
      const sameKey = key === p.nicknameKey;
      if (!sameKey) {
        const owner = await tx.profile.findUnique({ where: { nicknameKey: key }, select: { userId: true } });
        const hold = await tx.nicknameHold.findUnique({ where: { key } });
        if (owner || (hold && hold.userId !== userId && hold.until > now)) {
          throw new ConflictException('Nickname is taken');
        }
        const next = nextNicknameChangeAt(p.nicknameChangedAt, now);
        if (next) {
          if (!input.paid) {
            throw new ConflictException({ message: 'Nickname can be changed once in 30 days', nextNicknameChangeAt: next });
          }
          if ((await this.hero.coinsOf(userId, tx)) < NICKNAME_CHANGE_COINS) {
            throw new ConflictException('Not enough coins');
          }
          await tx.walletTx.create({ data: { userId, amount: -NICKNAME_CHANGE_COINS, reason: 'nickname' } });
        }
        if (hold) await tx.nicknameHold.delete({ where: { key } });
        await tx.nicknameHold.upsert({
          where: { key: p.nicknameKey },
          create: { key: p.nicknameKey, userId, until: nicknameHoldUntil(now) },
          update: { userId, until: nicknameHoldUntil(now) },
        });
      }
      await tx.profile.update({
        where: { userId },
        data: { nickname: input.nickname, nicknameKey: key, ...(sameKey ? {} : { nicknameChangedAt: now }) },
      });
      return this.hero.state(userId, tx);
    });
  }

  /**
   * Шаги в день отдыха (PLAN 4.8, п. 3): немного опыта кардио, раз в день и только
   * если сегодня не было тренировки. Серия от шагов не зависит.
   */
  claimSteps(userId: string, steps: number) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const p = await tx.profile.findUniqueOrThrow({
        where: { userId },
        select: { timezone: true, stepsRewardDay: true },
      });
      const day = localDay(new Date(), p.timezone);
      if (p.stepsRewardDay === day) throw new ConflictException('Steps already counted today');
      if (await tx.workout.findFirst({ where: { userId, day }, select: { id: true } })) {
        throw new ConflictException('Steps count only on rest days');
      }
      const xp = stepsXp(steps);
      if (xp > 0) {
        await tx.avatarPart.update({ where: { userId_part: { userId, part: 'cardio' } }, data: { xp: { increment: xp } } });
        await tx.xpEvent.create({ data: { userId, part: 'cardio', xp, validity: 1, wasLagging: false } });
        const coins = Math.round(xp * C.coinsPerXp);
        if (coins > 0) await tx.walletTx.create({ data: { userId, amount: coins, reason: 'steps' } });
      }
      await tx.profile.update({ where: { userId }, data: { stepsRewardDay: day } });
      return { xp, hero: await this.hero.state(userId, tx) };
    });
  }

  async setShowcase(userId: string, showcase: z.infer<typeof ShowcaseSchema>) {
    await this.db.profile.update({ where: { userId }, data: { showcase: showcase as Prisma.InputJsonValue } });
    return this.hero.state(userId);
  }

  /** Сохранить образ: всё надетое должно быть куплено или бесплатно. */
  async setAppearance(userId: string, appearance: Record<string, unknown>) {
    await this.hero.state(userId);
    assertLookOwned(appearance, await wearable(this.db, userId));
    await this.db.profile.update({ where: { userId }, data: { appearance: appearance as Prisma.InputJsonValue } });
    return this.hero.state(userId);
  }

  /**
   * Стартовый образ: пока открыт редактор, вещи редактора бесплатны. lock фиксирует
   * образ как «Старт» досрочно; после фиксации или конца окна — 409.
   */
  setStartLook(userId: string, input: z.infer<typeof StartLookSchema>) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      await this.hero.state(userId, tx);
      const p = await tx.profile.findUniqueOrThrow({ where: { userId }, select: { startLockedAt: true, startLookUntil: true } });
      if (!creatorOpen(p)) throw new ConflictException('Start look is already locked');
      assertLookOwned(input.appearance, await wearable(tx, userId));
      if (input.lock) {
        await this.hero.lockStart(userId, input.appearance as Prisma.JsonValue, new Date(), tx);
      } else {
        await tx.profile.update({ where: { userId }, data: { appearance: input.appearance as Prisma.InputJsonValue } });
      }
      return this.hero.state(userId, tx);
    });
  }

  /** Боты дня и итоги боёв с ними за сегодня. */
  async bots(userId: string) {
    const day = await this.today(userId);
    const hero = await this.hero.state(userId);
    const fought = await this.db.duel.findMany({
      where: { attackerId: userId, day, opponentKind: 'bot' },
      select: { opponentId: true, attackerWon: true, createdAt: true },
      orderBy: { createdAt: 'asc' },
    });
    // Исход — последнего боя; следующий бой — через duelCooldownHours после него.
    const results: Record<string, boolean> = {};
    const fights: Record<string, number> = {};
    const nextFightAt: Record<string, string> = {};
    for (const f of fought) {
      results[f.opponentId] = f.attackerWon;
      fights[f.opponentId] = (fights[f.opponentId] ?? 0) + 1;
      const next = new Date(f.createdAt.getTime() + C.duelCooldownHours * HOUR);
      if (next > new Date()) nextFightAt[f.opponentId] = next.toISOString();
    }
    return { day, bots: botsForDay(hero, day), results, fights, nextFightAt };
  }

  /**
   * Бой с ботом дня: исход, лог и монеты считает сервер. С тем же ботом — снова
   * через duelCooldownHours; повторные бои за сутки дают duelRepeatCoinFactor монет.
   */
  async fightBot(userId: string, botId: string) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const profile = await tx.profile.findUniqueOrThrow({ where: { userId } });
      const day = localDay(new Date(), profile.timezone);
      const hero = await this.hero.state(userId, tx);
      const bot: Bot | undefined = botsForDay(hero, day).find((b) => b.id === botId);
      if (!bot) throw new BadRequestException('No such bot today');
      const earlier = await tx.duel.findMany({
        where: { attackerId: userId, opponentId: botId, day },
        select: { createdAt: true },
        orderBy: { createdAt: 'desc' },
      });
      const last = earlier[0];
      if (last) {
        const next = new Date(last.createdAt.getTime() + C.duelCooldownHours * HOUR);
        if (next > new Date()) {
          throw new ConflictException({ message: 'Bot is on cooldown', nextFightAt: next.toISOString() });
        }
      }
      const repeat = earlier.length > 0;

      const attacker = { id: userId, name: hero.nickname, levels: hero.levels, streakDays: hero.streakDays };
      const seed = Math.floor(Math.random() * 2 ** 31);
      const result = simulateDuel(attacker, bot, seed);
      const base = result.attackerWon ? C.duelWinCoins : C.duelLossCoins;
      const coins = repeat ? Math.round(base * C.duelRepeatCoinFactor) : base;
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
      if (coins > 0) await tx.walletTx.create({ data: { userId, amount: coins, reason: 'duel', refId: duel.id } });
      // Повторный бой за сутки очков сезона не даёт — иначе их фармят у одного бота.
      if (!repeat) {
        await addSeasonPoints(tx, userId, result.attackerWon ? SEASON_POINTS.duelWin : SEASON_POINTS.duelLoss);
      }
      return { duelId: duel.id, attacker, defender: bot, ...result, coins, repeat, hero: await this.hero.state(userId, tx) };
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

  /** Очки за неделю всех живых игроков лиги [tier], кроме [exceptId]: активные за 4 недели. */
  private async tierPlayers(tier: number, monday: string, today: string, exceptId: string) {
    const since = addWeeks(monday, -4);
    const profiles = await this.db.profile.findMany({
      where: { leagueTier: tier, lastActiveDay: { gte: since }, userId: { not: exceptId }, user: { bannedAt: null } },
      select: { userId: true, nickname: true },
      take: 30,
    });
    if (profiles.length === 0) return [];
    const ids = profiles.map((p) => p.userId);
    const days = await this.db.workout.groupBy({
      by: ['userId', 'day'],
      where: { userId: { in: ids }, day: { gte: monday, lte: today } },
    });
    const wins = await this.db.duel.groupBy({
      by: ['attackerId'],
      where: { attackerId: { in: ids }, attackerWon: true, day: { gte: monday, lte: today } },
      _count: { _all: true },
    });
    return profiles.map((p) => ({
      id: p.userId,
      name: p.nickname,
      points:
        days.filter((d) => d.userId === p.userId).length * LEAGUE_WORKOUT_POINTS +
        (wins.find((w) => w.attackerId === p.userId)?._count._all ?? 0) * LEAGUE_WIN_POINTS,
    }));
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
      entries: liveLeague({
        today: day,
        me: { id: userId, name: hero.nickname, points },
        players: await this.tierPlayers(tier, mondayOf(day), day, userId),
        tier,
      }),
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
      const table = liveLeague({
        today: sunday,
        me: { id: userId, name: nickname, points: stats.points },
        players: await this.tierPlayers(tier, week, sunday, userId),
        tier,
      });
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

  /** Сезон: прогресс и дорожки наград (заодно выдаёт то, что причитается). */
  season(userId: string) {
    return seasonState(this.db, userId);
  }

  /** Вещь за достижение в приложении (гайд, первые часы): один раз, повтор — без ошибки. */
  async achievement(userId: string, kind: Achievement) {
    const itemId = ACHIEVEMENT_ITEMS[kind];
    const { count } = await this.db.inventoryItem.createMany({ data: [{ userId, itemId }], skipDuplicates: true });
    return { itemId, granted: count > 0 };
  }

  /** Награда за «Совет дня»: раз в календарный день пользователя. */
  async tipReward(userId: string, quiz: z.infer<typeof TipRewardSchema> = { correct: 1, total: 1 }) {
    const day = await this.today(userId);
    return this.db.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;
      const profile = await tx.profile.findUniqueOrThrow({ where: { userId }, select: { tipRewardDay: true } });
      if (profile.tipRewardDay === day) throw new ConflictException('Награда за совет сегодня уже получена');
      const coins = tipQuizCoins(quiz.correct, quiz.total);
      if (coins > 0) await tx.walletTx.create({ data: { userId, amount: coins, reason: 'tip' } });
      await tx.profile.update({ where: { userId }, data: { tipRewardDay: day } });
      await addSeasonPoints(tx, userId, SEASON_POINTS.tip);
      return { coins };
    });
  }

  async today(userId: string): Promise<string> {
    const p = await this.db.profile.findUniqueOrThrow({ where: { userId }, select: { timezone: true } });
    return localDay(new Date(), p.timezone);
  }
}
