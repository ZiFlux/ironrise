import { Body, Controller, HttpCode, Injectable, Logger, OnModuleDestroy, OnModuleInit, Post, Req } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { z } from 'zod';
import { ZodPipe } from '../common/zod';
import { PrismaService } from '../prisma.service';

const KEEP_DAYS = 14;

export const LogBatchSchema = z.object({
  installId: z.string().min(8).max(64),
  appVersion: z.string().max(32),
  os: z.string().max(120),
  env: z.string().max(16),
  entries: z
    .array(
      z.object({
        at: z.coerce.date(),
        level: z.enum(['error', 'warn', 'info']),
        message: z.string().max(4000),
        stack: z.string().max(8000).optional(),
      }),
    )
    .min(1)
    .max(200),
});

/** Чистит логи старше 14 дней раз в сутки. */
@Injectable()
export class LogRetention implements OnModuleInit, OnModuleDestroy {
  private timer?: NodeJS.Timeout;
  private readonly log = new Logger('Logs');

  constructor(private readonly db: PrismaService) {}

  onModuleInit() {
    const prune = () =>
      this.db.clientLog
        .deleteMany({ where: { createdAt: { lt: new Date(Date.now() - KEEP_DAYS * 86_400_000) } } })
        .catch((e) => this.log.warn(`очистка логов: ${(e as Error).message}`));
    void prune();
    this.timer = setInterval(() => void prune(), 86_400_000);
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }
}

/**
 * Приём логов приложения (docs/BETA.md, «Логи тестеров»). Работает и без входа:
 * падения до регистрации тоже важны. Токен, если есть, связывает лог с игроком.
 */
@Controller('logs')
export class LogsController {
  constructor(
    private readonly db: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  @Post()
  @HttpCode(204)
  async receive(
    @Req() req: { headers: Record<string, string | undefined> },
    @Body(new ZodPipe(LogBatchSchema)) body: z.infer<typeof LogBatchSchema>,
  ) {
    // Просроченный или чужой токен — лог всё равно сохраняем, просто без привязки к игроку.
    const userId = await this.userIdOf(req.headers.authorization);
    await this.db.clientLog.createMany({
      data: body.entries.map((e) => ({
        userId,
        installId: body.installId,
        appVersion: body.appVersion,
        os: body.os,
        env: body.env,
        at: e.at,
        level: e.level,
        message: e.message,
        stack: e.stack,
      })),
    });
    // Игрок вошёл — его анонимные логи с этой установки тоже его.
    if (userId) {
      await this.db.clientLog.updateMany({ where: { installId: body.installId, userId: null }, data: { userId } });
    }
  }

  private async userIdOf(header?: string): Promise<string | undefined> {
    const [scheme, token] = (header ?? '').split(' ');
    if (scheme !== 'Bearer' || !token) return undefined;
    try {
      return (await this.jwt.verifyAsync<{ sub: string }>(token)).sub;
    } catch {
      return undefined;
    }
  }
}
