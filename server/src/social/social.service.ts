import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { z } from 'zod';
import { localDay } from '../common/day';
import { mondayOf } from '../game/bots';
import { GameConfig as C } from '../game/config';
import { FighterSnapshot, simulateDuel } from '../game/duel';
import { Prisma } from '../generated/prisma/client';
import { EconomyService } from '../economy/economy.service';
import { HeroService, HeroState } from '../hero/hero.service';
import { PrismaService } from '../prisma.service';
import { PushService } from '../push/push.service';

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
      where: { nickname: { equals: nickname, mode: 'insensitive' } },
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
      where: { attackerId: userId, opponentKind: 'user', day },
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
   * Дуэль с другом: друг может быть офлайн — бой идёт против снимка его героя.
   * С каждым другом — раз в день, всего не больше FRIEND_DUELS_PER_DAY.
   */
  fight(userId: string, friendId: string) {
    return this.db.$transaction(async (tx) => {
      await tx.$executeRaw`SELECT 1 FROM "Profile" WHERE "userId" = ${userId}::uuid FOR UPDATE`;
      const rel = await this.relation(userId, friendId, tx);
      if (rel?.status !== 'accepted') throw new BadRequestException('Not friends');

      const profile = await tx.profile.findUniqueOrThrow({ where: { userId } });
      const day = localDay(new Date(), profile.timezone);
      const duelKey = { attackerId_opponentId_day: { attackerId: userId, opponentId: friendId, day } };
      if (await tx.duel.findUnique({ where: duelKey })) throw new ConflictException('Already fought this friend today');
      const today = await tx.duel.count({ where: { attackerId: userId, opponentKind: 'user', day } });
      if (today >= FRIEND_DUELS_PER_DAY) throw new ConflictException('Daily friend duel limit reached');

      const attacker = snapshotOf(userId, await this.hero.state(userId, tx));
      const defender = snapshotOf(friendId, await this.hero.state(friendId, tx));
      const seed = Math.floor(Math.random() * 2 ** 31);
      const result = simulateDuel(attacker as FighterSnapshot, defender as FighterSnapshot, seed);
      const coins = result.attackerWon ? C.duelWinCoins : C.duelLossCoins;
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
          coins,
        },
      });
      await tx.walletTx.create({ data: { userId, amount: coins, reason: 'duel', refId: duel.id } });
      this.push.notify(friendId, {
        type: 'attacked',
        title: result.attackerWon ? 'На тебя напали и победили' : 'Ты отбился!',
        body: result.attackerWon
          ? `${attacker.name} одолел тебя в дуэли. Вызови в ответ`
          : `${attacker.name} напал, но твой герой выстоял`,
        screen: 'duels',
      });
      return { duelId: duel.id, attacker, defender, ...result, coins, hero: await this.hero.state(userId, tx) };
    });
  }

  /** Кто нападал на меня за неделю: защита не требует действий, но интересно знать. */
  async attacksOnMe(userId: string) {
    const since = new Date(Date.now() - 7 * 86_400_000);
    const duels = await this.db.duel.findMany({
      where: { opponentKind: 'user', opponentId: userId, createdAt: { gte: since } },
      include: { attacker: { select: { profile: { select: { nickname: true } } } } },
      orderBy: { createdAt: 'desc' },
      take: 20,
    });
    return duels.map((d) => ({
      attacker: d.attacker.profile?.nickname ?? '—',
      attackerWon: d.attackerWon,
      powerA: d.powerA,
      powerD: d.powerD,
      at: d.createdAt,
    }));
  }

  /** Лига среди друзей: я и друзья по недельным очкам активности. */
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
      })),
    );
    return { day, entries: entries.sort((a, b) => b.points - a.points || Number(b.isPlayer) - Number(a.isPlayer)) };
  }
}
