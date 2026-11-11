import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { EconomyService } from '../economy/economy.service';
import { mondayOf } from '../game/bots';
import { addWeeks, tierAfter } from '../game/league';
import { PrismaService } from '../prisma.service';

const CoinsSchema = z.object({ amount: z.number().int().min(1).max(100_000) });
const LeagueSchema = z.object({ shift: z.union([z.literal(1), z.literal(-1)]) });

/**
 * Инструменты разработки: только на сервере разработки (DEV_TOOLS=true в
 * docker-compose.yml). На бете и в релизе контроллер не подключается вовсе.
 */
@Controller('dev')
@UseGuards(AuthGuard)
export class DevController {
  constructor(
    private readonly db: PrismaService,
    private readonly economy: EconomyService,
  ) {}

  /** Выдать себе монеты, чтобы проверять магазин и гардероб. */
  @Post('coins')
  @HttpCode(204)
  async coins(@UserId() userId: string, @Body(new ZodPipe(CoinsSchema)) body: z.infer<typeof CoinsSchema>) {
    await this.db.walletTx.create({ data: { userId, amount: body.amount, reason: 'dev' } });
  }

  /**
   * Сдвинуть лигу на одну вверх или вниз, как будто неделя уже подведена:
   * видно новую лигу и плашку итога прошлой недели.
   */
  @Post('league')
  @HttpCode(204)
  async league(@UserId() userId: string, @Body(new ZodPipe(LeagueSchema)) body: z.infer<typeof LeagueSchema>) {
    const profile = await this.db.profile.findUniqueOrThrow({ where: { userId }, select: { leagueTier: true } });
    const monday = mondayOf(await this.economy.today(userId));
    const outcome = body.shift > 0 ? 'up' : 'down';
    const result = {
      week: addWeeks(monday, -1),
      rank: outcome === 'up' ? 1 : 8,
      outcome,
      tierBefore: profile.leagueTier,
      tierAfter: tierAfter(profile.leagueTier, outcome),
    };
    await this.db.profile.update({
      where: { userId },
      data: { leagueTier: result.tierAfter, leagueWeek: monday, leagueLast: result },
    });
  }
}

export const devToolsEnabled = process.env.DEV_TOOLS === 'true';
