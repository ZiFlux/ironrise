import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { PrismaService } from '../prisma.service';

const CoinsSchema = z.object({ amount: z.number().int().min(1).max(100_000) });

/**
 * Инструменты разработки: только на сервере разработки (DEV_TOOLS=true в
 * docker-compose.yml). На бете и в релизе контроллер не подключается вовсе.
 */
@Controller('dev')
@UseGuards(AuthGuard)
export class DevController {
  constructor(private readonly db: PrismaService) {}

  /** Выдать себе монеты, чтобы проверять магазин и гардероб. */
  @Post('coins')
  @HttpCode(204)
  async coins(@UserId() userId: string, @Body(new ZodPipe(CoinsSchema)) body: z.infer<typeof CoinsSchema>) {
    await this.db.walletTx.create({ data: { userId, amount: body.amount, reason: 'dev' } });
  }
}

export const devToolsEnabled = process.env.DEV_TOOLS === 'true';
