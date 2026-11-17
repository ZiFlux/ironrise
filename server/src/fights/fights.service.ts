/**
 * Бой по раундам (п. 149, docs/COMBAT.md). Бой — запись Duel с finished = false:
 * игрок присылает цепочку из 5 действий на раунд, сервер разыгрывает раунд против ИИ
 * соперника и пишет шаги в лог. На последнем раунде — итог и награды (как в автобое).
 * Одновременно идёт не больше одного боя; брошенный дольше [FIGHT_STALE_MS] бой
 * доигрывается случайными действиями при следующем запросе игрока.
 */
import { BadRequestException, ConflictException, Injectable, NotFoundException } from '@nestjs/common';
import { z } from 'zod';
import {
  COMBAT_ACTIONS,
  COMBAT_ROUNDS,
  COMBAT_STEPS,
  ChainSchema,
  CombatAction,
  CombatState,
  CombatStep,
  MAX_HEAVY_PER_ROUND,
  MAX_SAME_IN_ROW,
  playRound,
  randomChain,
  startCombat,
} from '../game/combat';
import { FighterSnapshot, seededRandom } from '../game/duel';
import { EconomyService, lockProfile } from '../economy/economy.service';
import { Prisma } from '../generated/prisma/client';
import { HeroService } from '../hero/hero.service';
import { PrismaService } from '../prisma.service';
import { SocialService } from '../social/social.service';

export const RoundSchema = z.object({ actions: ChainSchema });

/** Бой без хода дольше этого — доигрывается сам. */
export const FIGHT_STALE_MS = 10 * 60 * 1000;

type Tx = Prisma.TransactionClient;
type DuelRow = NonNullable<Awaited<ReturnType<Tx['duel']['findFirst']>>>;

@Injectable()
export class FightsService {
  constructor(
    private readonly db: PrismaService,
    private readonly hero: HeroService,
    private readonly economy: EconomyService,
    private readonly social: SocialService,
  ) {}

  /** Правила для экрана: сколько раундов и шагов, ограничения цепочки. */
  static rules = {
    rounds: COMBAT_ROUNDS,
    steps: COMBAT_STEPS,
    actions: COMBAT_ACTIONS,
    maxHeavy: MAX_HEAVY_PER_ROUND,
    maxSameInRow: MAX_SAME_IN_ROW,
  };

  startBot(userId: string, botId: string) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      await this.closeOpen(tx, userId);
      const { day, bot, attacker } = await this.economy.prepareBotFight(tx, userId, botId);
      return this.create(tx, userId, { kind: 'bot', opponentId: bot.id, day, attacker, defender: bot });
    });
  }

  startFriend(userId: string, friendId: string) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      await this.closeOpen(tx, userId);
      const { day, attacker, defender } = await this.social.prepareFriendFight(tx, userId, friendId);
      return this.create(tx, userId, { kind: 'user', opponentId: friendId, day, attacker, defender });
    });
  }

  /** Незаконченный бой игрока (продолжить после перезапуска) или null. */
  current(userId: string) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      await this.closeStale(tx, userId);
      const duel = await tx.duel.findFirst({ where: { attackerId: userId, finished: false } });
      return duel ? this.view(duel) : null;
    });
  }

  /** Раунд: цепочка игрока против ИИ. Только свой незаконченный бой. */
  round(userId: string, fightId: string, input: z.infer<typeof RoundSchema>) {
    return this.db.$transaction(async (tx) => {
      await lockProfile(tx, userId);
      const duel = await tx.duel.findFirst({ where: { id: fightId, attackerId: userId } });
      if (!duel) throw new NotFoundException('No such fight');
      if (duel.finished || !duel.state) throw new ConflictException('Fight is finished');
      const { steps, chainD, state } = this.play(duel, input.actions);
      const settled = await this.save(tx, userId, duel, state, steps);
      return {
        fightId: duel.id,
        round: state.round,
        steps,
        chainD,
        hpA: state.a.hp,
        hpD: state.d.hp,
        finished: state.finished,
        attackerWon: state.finished ? state.attackerWon : null,
        ...(settled ?? {}),
        ...(state.finished ? { hero: await this.hero.state(userId, tx) } : {}),
      };
    });
  }

  // ── внутреннее ────────────────────────────────────────────────────────────

  private async create(
    tx: Tx,
    userId: string,
    f: { kind: 'bot' | 'user'; opponentId: string; day: string; attacker: FighterSnapshot; defender: FighterSnapshot },
  ) {
    const seed = Math.floor(Math.random() * 2 ** 31);
    const state = startCombat(f.attacker, f.defender, seed);
    const duel = await tx.duel.create({
      data: {
        attackerId: userId,
        opponentKind: f.kind,
        opponentId: f.opponentId,
        day: f.day,
        seed,
        snapshotA: f.attacker as unknown as Prisma.InputJsonValue,
        snapshotD: f.defender as unknown as Prisma.InputJsonValue,
        powerA: state.powerA,
        powerD: state.powerD,
        log: [],
        attackerWon: false,
        coins: 0,
        finished: false,
        state: state as unknown as Prisma.InputJsonValue,
      },
    });
    return this.view(duel);
  }

  /** Что видит телефон: бойцы, здоровье, раунд, сыгранные шаги и правила. */
  private view(duel: DuelRow) {
    const state = duel.state as unknown as CombatState | null;
    return {
      fightId: duel.id,
      opponentKind: duel.opponentKind,
      attacker: duel.snapshotA,
      defender: duel.snapshotD,
      powerA: duel.powerA,
      powerD: duel.powerD,
      hpA: state?.a.hp ?? 0,
      hpD: state?.d.hp ?? 0,
      round: state?.round ?? 0,
      log: duel.log,
      rules: FightsService.rules,
    };
  }

  private play(duel: DuelRow, chain: readonly CombatAction[]) {
    const state = duel.state as unknown as CombatState;
    return playRound(state, duel.snapshotA as unknown as FighterSnapshot, duel.snapshotD as unknown as FighterSnapshot, chain);
  }

  /** Сохранить раунд; на последнем — награды (бот лестницы или друг). */
  private async save(tx: Tx, userId: string, duel: DuelRow, state: CombatState, steps: CombatStep[]) {
    const log = [...((duel.log as unknown as CombatStep[]) ?? []), ...steps];
    let settled: Record<string, unknown> | null = null;
    let coins = 0;
    if (state.finished) {
      const won = state.attackerWon === true;
      if (duel.opponentKind === 'bot') {
        const repeat =
          (await tx.duel.count({
            where: { attackerId: userId, opponentId: duel.opponentId, day: duel.day, id: { not: duel.id } },
          })) > 0;
        const r = await this.economy.settleBotFight(tx, userId, { botId: duel.opponentId, won, repeat, duelId: duel.id });
        coins = r.coins;
        settled = { ...r, repeat };
      } else {
        const name = (duel.snapshotA as unknown as FighterSnapshot).name;
        const r = await this.social.settleFriendFight(tx, userId, {
          friendId: duel.opponentId,
          attackerName: name,
          won,
          duelId: duel.id,
        });
        coins = r.coins;
        settled = r;
      }
    }
    await tx.duel.update({
      where: { id: duel.id },
      data: {
        log: log as unknown as Prisma.InputJsonValue,
        state: state as unknown as Prisma.InputJsonValue,
        finished: state.finished,
        attackerWon: state.attackerWon === true,
        coins,
      },
    });
    return settled;
  }

  /** Перед новым боем: брошенный — доиграть, свежий незаконченный — не даём начать второй. */
  private async closeOpen(tx: Tx, userId: string) {
    await this.closeStale(tx, userId);
    if (await tx.duel.findFirst({ where: { attackerId: userId, finished: false }, select: { id: true } })) {
      throw new ConflictException('Finish the current fight first');
    }
  }

  /** Бои без хода дольше FIGHT_STALE_MS доигрываются случайными действиями (детерминированно). */
  private async closeStale(tx: Tx, userId: string) {
    const stale = await tx.duel.findMany({
      where: { attackerId: userId, finished: false, updatedAt: { lt: new Date(Date.now() - FIGHT_STALE_MS) } },
    });
    for (const duel of stale) {
      let state = duel.state as unknown as CombatState | null;
      if (!state) throw new BadRequestException('Broken fight');
      const rnd = seededRandom(duel.seed ^ 0x5bd1e995);
      const steps: CombatStep[] = [];
      while (!state.finished) {
        const r = playRound(
          state,
          duel.snapshotA as unknown as FighterSnapshot,
          duel.snapshotD as unknown as FighterSnapshot,
          randomChain(rnd),
        );
        steps.push(...r.steps);
        state = r.state;
      }
      await this.save(tx, userId, duel, state, steps);
    }
  }
}
