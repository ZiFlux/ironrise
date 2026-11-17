import { stepsXp } from '../game/steps';
import { BadRequestException, ConflictException, ForbiddenException, Injectable } from '@nestjs/common';
import { heroLevel } from '../game/social-progress';
import { GoalsChangeSchema } from '../game/goals';
import { EntryTestSchema, entryTestCoins } from '../game/entry-test';
import { showcaseLock } from '../game/showcase';
import { z } from 'zod';
import { localDay } from '../common/day';
import { Bot, fillLeague, LEAGUE_WIN_POINTS, LEAGUE_WORKOUT_POINTS, liveLeague, MIN_LEAGUE_PLAYERS, mondayOf } from '../game/bots';
import { addWeeks, DEMOTE_BOTTOM, sundayOf, LEAGUE_TIERS, minTrainedDaysToPromote, promoteTopFor, settleWeek, TOP_TIER, WeekSettlement } from '../game/league';
import { GameConfig as C } from '../game/config';
import { simulateDuel } from '../game/duel';
import { BOSS_UNLOCK_WINS, LADDER, LADDER_BOTS, bossUnlocked, clampTier, isBossId, ladderCoins, ladderTier, readBeaten, tierWins } from '../game/bot-ladder';
import { unpaidItems } from '../game/looks';
import { MIN_TRAINING_DAYS, nextScheduleChangeAt } from '../game/schedule';
import { premiumStatus } from '../game/premium';
import { PREMIUM_ITEMS, priceOf, ACHIEVEMENT_ITEMS, Achievement } from '../game/shop';
import { CREATOR_ITEMS, creatorOpen } from '../game/start-look';
import {
  NICKNAME_CHANGE_COINS,
  NicknameSchema,
  isOffensiveNickname,
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
import { AuraTrainingSchema, auraSnapshot, auraState, equipAura, trainAura } from '../season/aura-service';

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

export const lockProfile = (tx: Prisma.TransactionClient, userId: string) =>
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
  /**
   * Входная тренировка (п. 116): сохраняем результаты, +50 монет не чаще раза в 25 дней.
   * Повтор с тем же clientId (обрыв связи) ничего не начисляет второй раз.
   */
  async submitEntryTest(userId: string, input: z.infer<typeof EntryTestSchema>) {
    const now = new Date();
    if (input.at.getTime() > now.getTime() + 60_000) throw new BadRequestException('Entry test from the future');
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const existing = await tx.entryTest.findUnique({
        where: { userId_clientId: { userId, clientId: input.clientId } },
        select: { coins: true },
      });
      if (existing) return { coins: existing.coins, duplicate: true, hero: await this.hero.state(userId, tx) };
      const last = await tx.entryTest.findFirst({
        where: { userId, coins: { gt: 0 } },
        orderBy: { createdAt: 'desc' },
        select: { createdAt: true },
      });
      const coins = entryTestCoins(last?.createdAt ?? null, now);
      await tx.entryTest.create({
        data: {
          userId,
          clientId: input.clientId,
          at: input.at,
          level: input.level,
          results: input.results as Prisma.InputJsonValue,
          coins,
        },
      });
      if (coins > 0) await tx.walletTx.create({ data: { userId, amount: coins, reason: 'entry_test' } });
      return { coins, duplicate: false, hero: await this.hero.state(userId, tx) };
    });
  }

  async changeGoals(userId: string, input: z.infer<typeof GoalsChangeSchema>) {
    await this.db.profile.update({ where: { userId }, data: { goal: input.goal, goals: input.goals } });
    return this.hero.state(userId);
  }

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
      if (isOffensiveNickname(input.nickname)) throw new BadRequestException('Nickname is not allowed');
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
    // Аватарки-достижения и поза победы — только если они действительно открыты.
    const hero = await this.hero.state(userId);
    const lock = showcaseLock(showcase, {
      heroLevel: heroLevel(hero.levels),
      streak: hero.streakDays,
      workouts: await this.db.workout.count({ where: { userId } }),
    });
    if (lock) throw new ForbiddenException(lock);
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
    const profile = await this.db.profile.findUniqueOrThrow({
      where: { userId },
      select: { botTier: true, botBeaten: true },
    });
    const beaten = readBeaten(profile.botBeaten);
    const ladder = ladderTier(profile.botTier);
    const unlocked = bossUnlocked(ladder.tier, beaten);
    const fought = await this.db.duel.findMany({
      where: { attackerId: userId, day, opponentKind: 'bot', finished: true },
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
    return {
      day,
      // Боты ступени и босс последним (старые версии приложения покажут его обычным ботом).
      bots: [...ladder.bots, ladder.boss],
      results,
      fights,
      nextFightAt,
      ladder: {
        tier: ladder.tier,
        tiers: LADDER.length,
        name: ladder.name,
        bossId: ladder.boss.id,
        bossUnlocked: unlocked,
        wins: tierWins(ladder.tier, beaten),
        winsToBoss: BOSS_UNLOCK_WINS,
        botsInTier: LADDER_BOTS,
        beaten: beaten.filter((id) => id.startsWith(`lad_${ladder.tier}_`)),
        nextName: LADDER[ladder.tier + 1]?.name ?? null,
      },
    };
  }

  /**
   * Проверки перед боем с ботом лестницы: бот своей ступени, босс открыт,
   * перезарядка прошла. Возвращает снимки бойцов и контекст для наград.
   */
  async prepareBotFight(tx: Prisma.TransactionClient, userId: string, botId: string) {
    const profile = await tx.profile.findUniqueOrThrow({ where: { userId } });
    const day = localDay(new Date(), profile.timezone);
    const hero = await this.hero.state(userId, tx);
    // Драться можно только с ботами своей ступени лестницы; босс — после 3 побед.
    const ladder = ladderTier(profile.botTier);
    const beaten = readBeaten(profile.botBeaten);
    const bot: Bot | undefined = [...ladder.bots, ladder.boss].find((b) => b.id === botId);
    if (!bot) throw new BadRequestException('No such bot today');
    if (isBossId(bot.id) && !bossUnlocked(ladder.tier, beaten)) throw new ForbiddenException('Boss is locked');
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
    const attacker = {
      id: userId,
      name: hero.nickname,
      levels: hero.levels,
      streakDays: hero.streakDays,
      aura: await auraSnapshot(tx, userId),
    };
    return { day, bot, attacker, repeat: earlier.length > 0 };
  }

  /**
   * Награды боя с ботом лестницы: первая победа — полные монеты и отметка, босс —
   * ступень выше; повторные — 30 %. Очки сезона — только за первый бой с ботом за сутки.
   */
  async settleBotFight(
    tx: Prisma.TransactionClient,
    userId: string,
    args: { botId: string; won: boolean; repeat: boolean; duelId: string },
  ) {
    const profile = await tx.profile.findUniqueOrThrow({ where: { userId }, select: { botTier: true, botBeaten: true } });
    const ladder = ladderTier(profile.botTier);
    const beaten = readBeaten(profile.botBeaten);
    const boss = isBossId(args.botId);
    // Бот не своей ступени (ступень сменилась, пока шёл бой) — без отметки и подъёма.
    const ofTier = args.botId.startsWith(`lad_${ladder.tier}_`);
    const firstWin = args.won && ofTier && !beaten.includes(args.botId);
    const coins = ladderCoins({ tier: ladder.tier, won: args.won, firstWin, boss });
    let tierUp = false;
    if (firstWin) {
      tierUp = boss && ladder.tier < LADDER.length - 1;
      await tx.profile.update({
        where: { userId },
        data: {
          botBeaten: [...beaten, args.botId],
          ...(tierUp ? { botTier: clampTier(ladder.tier + 1) } : {}),
        },
      });
    }
    if (coins > 0) await tx.walletTx.create({ data: { userId, amount: coins, reason: 'duel', refId: args.duelId } });
    // Повторный бой за сутки очков сезона не даёт — иначе их фармят у одного бота.
    if (!args.repeat) {
      await addSeasonPoints(tx, userId, args.won ? SEASON_POINTS.duelWin : SEASON_POINTS.duelLoss);
    }
    return { coins, firstWin, boss, tierUp };
  }

  /**
   * Автобой с ботом (версии приложения до боя по раундам): исход, лог и монеты
   * считает сервер. С тем же ботом — снова через duelCooldownHours.
   */
  async fightBot(userId: string, botId: string) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const { day, bot, attacker, repeat } = await this.prepareBotFight(tx, userId, botId);
      const seed = Math.floor(Math.random() * 2 ** 31);
      const result = simulateDuel(attacker, bot, seed);
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
          coins: 0,
        },
      });
      const reward = await this.settleBotFight(tx, userId, { botId: bot.id, won: result.attackerWon, repeat, duelId: duel.id });
      await tx.duel.update({ where: { id: duel.id }, data: { coins: reward.coins } });
      return {
        duelId: duel.id,
        attacker,
        defender: bot,
        ...result,
        ...reward,
        repeat,
        hero: await this.hero.state(userId, tx),
      };
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
  private async tierPlayers(tier: number, monday: string, today: string, exceptId: string, fill = true) {
    const since = addWeeks(monday, -4);
    const active = { lastActiveDay: { gte: since }, userId: { not: exceptId }, user: { bannedAt: null } };
    const select = { userId: true, nickname: true, leagueTier: true } as const;
    const own = await this.db.profile.findMany({ where: { ...active, leagueTier: tier }, select, take: 30 });
    // Мало своих — добираем соседей (fillLeague): в бете иначе каждый один в своей лиге.
    const others =
      !fill || own.length >= MIN_LEAGUE_PLAYERS
        ? []
        : await this.db.profile.findMany({ where: { ...active, leagueTier: { not: tier } }, select, take: 200 });
    const profiles = fillLeague(
      own.map((p) => ({ ...p, tier: p.leagueTier })),
      others.map((p) => ({ ...p, tier: p.leagueTier })),
      tier,
    );
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
      promoteTop: promoteTopFor(tier),
      minDaysToPromote: minTrainedDaysToPromote(tier),
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
   * Чужая лига (п. 108): таблица лиги [tier] этой недели, только посмотреть. Без добора
   * соседей — видно, кто на самом деле в этой лиге; мой ник отмечен, если я в ней.
   */
  async leagueView(userId: string, tier: number) {
    if (!Number.isInteger(tier) || tier < 0 || tier > TOP_TIER) throw new BadRequestException('Unknown league');
    const day = await this.today(userId);
    const players = await this.tierPlayers(tier, mondayOf(day), day, '00000000-0000-0000-0000-000000000000', false);
    return {
      tier,
      tierName: LEAGUE_TIERS[tier],
      promoteTop: promoteTopFor(tier),
      entries: liveLeague({ today: day, players, tier, viewerId: userId }),
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

  auras(userId: string) {
    return auraState(this.db, userId);
  }

  trainAura(userId: string, kind: string, input: z.infer<typeof AuraTrainingSchema>) {
    return trainAura(this.db, userId, kind, input);
  }

  equipAura(userId: string, kind: string | null) {
    return equipAura(this.db, userId, kind);
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
