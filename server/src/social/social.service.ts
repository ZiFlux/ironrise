import { nicknameKey } from '../game/nickname';
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { z } from 'zod';
import { localDay } from '../common/day';
import { mondayOf } from '../game/bots';
import { GameConfig as C } from '../game/config';
import { FighterSnapshot, simulateDuel } from '../game/duel';
import { Prisma } from '../generated/prisma/client';
import { capDuelCoins, duelCoinsToday } from '../economy/duel-coins';
import { EconomyService } from '../economy/economy.service';
import { HeroService, HeroState } from '../hero/hero.service';
import { PrismaService } from '../prisma.service';
import { PushService } from '../push/push.service';
import { mondayOfDay, pairStreak } from '../game/social-progress';
import { auraSnapshot } from '../season/aura-service';

/** Боёв с друзьями в день (ТЗ 4.5: «не больше N атак в день»). */
export const FRIEND_DUELS_PER_DAY = 5;

export const FriendRequestSchema = z.object({ nickname: z.string().trim().min(3).max(20) });

type Tx = Prisma.TransactionClient;

const isFemale = (appearance: unknown) =>
  typeof appearance === 'object' && appearance !== null && (appearance as { sex?: unknown }).sex === 'female';

/** Снимок для боя: уровни, серия и образ на момент дуэли (PLAN 1, принцип 3). */
const snapshotOf = (userId: string, h: HeroState) => ({
  id: userId,
  name: h.nickname,
  levels: h.levels,
  streakDays: h.streakDays,
  isFemale: isFemale(h.appearance),
  appearance: h.appearance,
});

@Injectable()
export class SocialService {
  constructor(
    private readonly db: PrismaService,
    private readonly hero: HeroService,
    private readonly economy: EconomyService,
    private readonly push: PushService,
  ) {}

  private async nicknameOf(userId: string): Promise<string> {
    const p = await this.db.profile.findUnique({ where: { userId }, select: { nickname: true } });
    return p?.nickname ?? 'Игрок';
  }

  /** Поиск по нику (без учёта регистра), себя не показываем. */
  async search(userId: string, query: string) {
    const q = query.trim();
    if (q.length < 2) return [];
    const found = await this.db.profile.findMany({
      where: { nickname: { contains: q, mode: 'insensitive' }, userId: { not: userId } },
      select: { userId: true, nickname: true },
      take: 10,
      orderBy: { nickname: 'asc' },
    });
    return found;
  }

  private relation(a: string, b: string, db: Tx | PrismaService = this.db) {
    return db.friendship.findFirst({
      where: {
        OR: [
          { requesterId: a, addresseeId: b },
          { requesterId: b, addresseeId: a },
        ],
      },
    });
  }

  /** Заявка по нику. Если тот уже звал нас — сразу дружба. */
  async request(userId: string, nickname: string) {
    const target = await this.db.profile.findFirst({
      where: { nicknameKey: nicknameKey(nickname) },
      select: { userId: true, nickname: true },
    });
    if (!target) throw new NotFoundException('Player not found');
    if (target.userId === userId) throw new BadRequestException('Cannot add yourself');

    const existing = await this.relation(userId, target.userId);
    if (existing?.status === 'accepted') throw new ConflictException('Already friends');
    if (existing && existing.requesterId === target.userId) {
      await this.accept(userId, target.userId);
      return { status: 'accepted', nickname: target.nickname };
    }
    if (!existing) {
      await this.db.friendship.create({ data: { requesterId: userId, addresseeId: target.userId } });
      this.push.notify(target.userId, {
        type: 'friend_request',
        title: 'Заявка в друзья',
        body: `${await this.nicknameOf(userId)} хочет добавить тебя в друзья`,
        screen: 'friends',
      });
    }
    return { status: 'pending', nickname: target.nickname };
  }

  async accept(userId: string, requesterId: string) {
    const { count } = await this.db.friendship.updateMany({
      where: { requesterId, addresseeId: userId, status: 'pending' },
      data: { status: 'accepted' },
    });
    if (count === 0) throw new NotFoundException('No such request');
    this.push.notify(requesterId, {
      type: 'friend_accepted',
      title: 'Новый друг',
      body: `${await this.nicknameOf(userId)} принял заявку. Можно вызывать на дуэль`,
      screen: 'duels',
    });
  }

  /** Отклонить заявку, отозвать свою или удалить из друзей. */
  async remove(userId: string, otherId: string) {
    await this.db.friendship.deleteMany({
      where: {
        OR: [
          { requesterId: userId, addresseeId: otherId },
          { requesterId: otherId, addresseeId: userId },
        ],
      },
    });
  }

  /** Друзья с их силой и образом, входящие и исходящие заявки, итоги боёв за сегодня. */
  async list(userId: string) {
    const rows = await this.db.friendship.findMany({
      where: { OR: [{ requesterId: userId }, { addresseeId: userId }] },
      include: {
        requester: { select: { profile: { select: { nickname: true } } } },
        addressee: { select: { profile: { select: { nickname: true } } } },
      },
      orderBy: { createdAt: 'asc' },
    });
    const day = await this.economy.today(userId);
    const fought = await this.db.duel.findMany({
      where: { attackerId: userId, opponentKind: 'user', day, finished: true },
      select: { opponentId: true, attackerWon: true },
    });
    const results = Object.fromEntries(fought.map((f) => [f.opponentId, f.attackerWon]));

    const friends: ReturnType<typeof snapshotOf>[] = [];
    const incoming: { userId: string; nickname: string }[] = [];
    const outgoing: { userId: string; nickname: string }[] = [];
    for (const r of rows) {
      const mine = r.requesterId === userId;
      const otherId = mine ? r.addresseeId : r.requesterId;
      const nickname = (mine ? r.addressee : r.requester).profile?.nickname ?? '—';
      if (r.status === 'accepted') friends.push(snapshotOf(otherId, await this.hero.state(otherId)));
      else (mine ? outgoing : incoming).push({ userId: otherId, nickname });
    }
    return {
      friends,
      incoming,
      outgoing,
      results,
      fightsLeft: Math.max(0, FRIEND_DUELS_PER_DAY - fought.length),
    };
  }

  /**
   * Проверки перед боем с другом: дружба, раз в день с каждым, дневной лимит.
   * Друг может быть офлайн — бой идёт против снимка его героя.
   */
  async prepareFriendFight(tx: Prisma.TransactionClient, userId: string, friendId: string) {
    const rel = await this.relation(userId, friendId, tx);
    if (rel?.status !== 'accepted') throw new BadRequestException('Not friends');
    const profile = await tx.profile.findUniqueOrThrow({ where: { userId } });
    const day = localDay(new Date(), profile.timezone);
    if (await tx.duel.findFirst({ where: { attackerId: userId, opponentId: friendId, day }, select: { id: true } })) {
      throw new ConflictException('Already fought this friend today');
    }
    const today = await tx.duel.count({ where: { attackerId: userId, opponentKind: 'user', day } });
    if (today >= FRIEND_DUELS_PER_DAY) throw new ConflictException('Daily friend duel limit reached');
    const attacker = { ...snapshotOf(userId, await this.hero.state(userId, tx)), aura: await auraSnapshot(tx, userId) };
    const defender = { ...snapshotOf(friendId, await this.hero.state(friendId, tx)), aura: await auraSnapshot(tx, friendId) };
    return { day, attacker: attacker as FighterSnapshot & typeof attacker, defender: defender as FighterSnapshot & typeof defender };
  }

  /** Награда за бой с другом и пуш ему: напали и победили / ты отбился. */
  async settleFriendFight(
    tx: Prisma.TransactionClient,
    userId: string,
    args: { friendId: string; attackerName: string; won: boolean; duelId: string },
  ) {
    // Бои с друзьями — под дневным лимитом монет за дуэли.
    const coins = capDuelCoins(args.won ? C.duelWinCoins : C.duelLossCoins, await duelCoinsToday(tx, userId));
    if (coins > 0) await tx.walletTx.create({ data: { userId, amount: coins, reason: 'duel', refId: args.duelId } });
    this.push.notify(args.friendId, {
      type: 'attacked',
      title: args.won ? 'На тебя напали и победили' : 'Ты отбился!',
      body: args.won
        ? `${args.attackerName} одолел тебя в дуэли. Вызови в ответ`
        : `${args.attackerName} напал, но твой герой выстоял`,
      screen: 'duels',
    });
    return { coins };
  }

  /** Автобой с другом (версии приложения до боя по раундам). */
  fight(userId: string, friendId: string) {
    return this.db.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;
      const { day, attacker, defender } = await this.prepareFriendFight(tx, userId, friendId);
      const seed = Math.floor(Math.random() * 2 ** 31);
      const result = simulateDuel(attacker, defender, seed);
      const duel = await tx.duel.create({
        data: {
          attackerId: userId,
          opponentKind: 'user',
          opponentId: friendId,
          day,
          seed,
          snapshotA: attacker as unknown as Prisma.InputJsonValue,
          snapshotD: defender as unknown as Prisma.InputJsonValue,
          powerA: result.powerA,
          powerD: result.powerD,
          log: result.log as unknown as Prisma.InputJsonValue,
          attackerWon: result.attackerWon,
          coins: 0,
        },
      });
      const { coins } = await this.settleFriendFight(tx, userId, {
        friendId,
        attackerName: attacker.name,
        won: result.attackerWon,
        duelId: duel.id,
      });
      await tx.duel.update({ where: { id: duel.id }, data: { coins } });
      return { duelId: duel.id, attacker, defender, ...result, coins, hero: await this.hero.state(userId, tx) };
    });
  }

  /** Кто нападал на меня за неделю: защита не требует действий, но интересно знать. */
  async attacksOnMe(userId: string) {
    const since = new Date(Date.now() - 7 * 86_400_000);
    const duels = await this.db.duel.findMany({
      where: { opponentKind: 'user', opponentId: userId, createdAt: { gte: since }, finished: true },
      include: { attacker: { select: { profile: { select: { nickname: true } } } } },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return duels.map((d) => ({
      attacker: d.attacker.profile?.nickname ?? '—',
      attackerId: d.attackerId,
      attackerWon: d.attackerWon,
      powerA: d.powerA,
      powerD: d.powerD,
      at: d.createdAt,
    }));
  }

  /** Лига среди друзей: я и друзья по недельным очкам активности. */
  /**
   * Витрина друга: герой, сила, серия, аватарка и поза, итоги. Только друзьям —
   * чужой профиль по id не открыть. Пульс и тренировки по дням не показываются.
   */
  async profile(userId: string, otherId: string) {
    if (otherId !== userId) {
      const rel = await this.relation(userId, otherId, this.db);
      if (rel?.status !== 'accepted') throw new NotFoundException('Not a friend');
    }
    const h = await this.hero.state(otherId);
    const [workouts, wins, user] = await Promise.all([
      this.db.workout.count({ where: { userId: otherId, status: 'accepted' } }),
      this.db.duel.count({ where: { attackerId: otherId, attackerWon: true } }),
      this.db.user.findUniqueOrThrow({ where: { id: otherId }, select: { createdAt: true } }),
    ]);
    return {
      id: otherId,
      nickname: h.nickname,
      levels: h.levels,
      xp: h.xp,
      power: h.power,
      streakDays: h.streakDays,
      appearance: h.appearance,
      muscles: h.muscles,
      showcase: h.showcase,
      premium: h.premium,
      stats: { workouts, duelWins: wins, since: user.createdAt },
    };
  }

  /** id друзей (принятые заявки). */
  private async friendIds(userId: string): Promise<string[]> {
    const rows = await this.db.friendship.findMany({
      where: { status: 'accepted', OR: [{ requesterId: userId }, { addresseeId: userId }] },
      select: { requesterId: true, addresseeId: true },
    });
    return rows.map((r) => (r.requesterId === userId ? r.addresseeId : r.requesterId));
  }

  /** Лента: свои события и друзей за две недели, с «кулаками». */
  async feed(userId: string) {
    const ids = [userId, ...(await this.friendIds(userId))];
    const events = await this.db.feedEvent.findMany({
      where: { userId: { in: ids }, createdAt: { gte: new Date(Date.now() - 14 * 86_400_000) } },
      orderBy: { createdAt: 'desc' },
      take: 60,
      include: {
        user: { select: { profile: { select: { nickname: true, showcase: true } } } },
        fists: { select: { userId: true } },
      },
    });
    return events.map((e) => ({
      id: e.id,
      userId: e.userId,
      nickname: e.user.profile?.nickname ?? '—',
      showcase: e.user.profile?.showcase ?? null,
      kind: e.kind,
      data: e.data,
      at: e.createdAt,
      fists: e.fists.length,
      myFist: e.fists.some((f) => f.userId === userId),
      mine: e.userId === userId,
    }));
  }

  /** «Кулак» на событие друга — поставить или убрать. */
  async toggleFist(userId: string, eventId: string) {
    const e = await this.db.feedEvent.findUnique({ where: { id: eventId }, select: { userId: true } });
    if (!e) throw new NotFoundException('No such event');
    if (e.userId !== userId && !(await this.friendIds(userId)).includes(e.userId)) {
      throw new NotFoundException('No such event');
    }
    const key = { eventId_userId: { eventId, userId } };
    if (await this.db.feedFist.findUnique({ where: key })) {
      await this.db.feedFist.delete({ where: key });
      return { myFist: false };
    }
    await this.db.feedFist.create({ data: { eventId, userId } });
    return { myFist: true };
  }

  private pairOf(userId: string) {
    return this.db.streakPair.findFirst({
      where: { OR: [{ aId: userId }, { bId: userId }] },
      orderBy: { createdAt: 'desc' },
    });
  }

  /** Напарник по серии: кто, статус, общая серия в неделях и эта неделя. */
  async pair(userId: string) {
    const p = await this.pairOf(userId);
    if (!p) return { pair: null };
    const otherId = p.aId === userId ? p.bId : p.aId;
    const other = await this.db.profile.findUnique({
      where: { userId: otherId },
      select: { nickname: true, showcase: true },
    });
    const base = {
      id: p.id,
      partnerId: otherId,
      nickname: other?.nickname ?? '—',
      showcase: other?.showcase ?? null,
      status: p.status,
      invitedByMe: p.aId === userId,
    };
    if (p.status !== 'active' || !p.since) return { pair: base };
    const today = await this.economy.today(userId);
    const days = async (id: string) =>
      (await this.db.workout.findMany({ where: { userId: id, day: { gte: p.since! } }, select: { day: true } })).map(
        (w) => w.day,
      );
    const streak = pairStreak(await days(userId), await days(otherId), p.since, today);
    return { pair: { ...base, ...streak } };
  }

  /** Позвать друга в напарники. У каждого — один напарник. */
  async invitePair(userId: string, friendId: string) {
    if (!(await this.friendIds(userId)).includes(friendId)) throw new BadRequestException('Not friends');
    if (await this.pairOf(userId)) throw new ConflictException('You already have a partner');
    if (await this.pairOf(friendId)) throw new ConflictException('Friend already has a partner');
    await this.db.streakPair.create({ data: { aId: userId, bId: friendId } });
    this.push.notify(friendId, {
      type: 'friend_request',
      title: 'Тебя зовут в напарники по серии',
      body: `${await this.nicknameOf(userId)} хочет держать общую серию: по 2 тренировки в неделю у каждого`,
      screen: 'friends',
    });
    return this.pair(userId);
  }

  async acceptPair(userId: string) {
    const p = await this.pairOf(userId);
    if (!p || p.bId !== userId || p.status !== 'pending') throw new NotFoundException('No invitation');
    const today = await this.economy.today(userId);
    await this.db.streakPair.update({ where: { id: p.id }, data: { status: 'active', since: mondayOfDay(today) } });
    this.push.notify(p.aId, {
      type: 'friend_accepted',
      title: 'Напарник согласился',
      body: `${await this.nicknameOf(userId)} держит с тобой общую серию. Не подведи!`,
      screen: 'friends',
    });
    return this.pair(userId);
  }

  async leavePair(userId: string) {
    const p = await this.pairOf(userId);
    if (p) await this.db.streakPair.delete({ where: { id: p.id } });
    return { pair: null };
  }

  async friendsLeague(userId: string) {
    const day = await this.economy.today(userId);
    const monday = mondayOf(day);
    const rows = await this.db.friendship.findMany({
      where: { status: 'accepted', OR: [{ requesterId: userId }, { addresseeId: userId }] },
      select: { requesterId: true, addresseeId: true },
    });
    const ids = [userId, ...rows.map((r) => (r.requesterId === userId ? r.addresseeId : r.requesterId))];
    const profiles = await this.db.profile.findMany({
      where: { userId: { in: ids } },
      select: { userId: true, nickname: true },
    });
    const entries = await Promise.all(
      profiles.map(async (p) => ({
        name: p.nickname,
        points: (await this.economy.weeklyStats(p.userId, monday, day)).points,
        isPlayer: p.userId === userId,
        // Только друзья: их профиль и так открыт (users/:id/profile) — по нажатию на строку.
        friendId: p.userId === userId ? undefined : p.userId,
      })),
    );
    return { day, entries: entries.sort((a, b) => b.points - a.points || Number(b.isPlayer) - Number(a.isPlayer)) };
  }
}
