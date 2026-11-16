import {
  BadRequestException,
  Body,
  Controller,
  Get,
  Header,
  Headers,
  HttpCode,
  NotFoundException,
  Post,
  Query,
  UnauthorizedException,
} from '@nestjs/common';
import { z } from 'zod';
import { ZodPipe } from '../common/zod';
import { PrismaService } from '../prisma.service';
import { adminPageHtml } from './admin-page';
import { adminToken, tokenMatches } from './admin-token';
import { adminPulseNorms, adminStats, itemGroups, playerInfo, playerWorkouts, run, suspicionLog } from './commands';

const RunSchema = z.object({ args: z.array(z.string().max(200)).min(1).max(40) });

/**
 * Веб-админка: страница /admin и её API /v1/admin/api/*. Вход — ключ ADMIN_TOKEN в заголовке
 * X-Admin-Token. Без ключа в окружении всё отвечает 404. Команды те же, что в
 * консольной админке (commands.ts), и пишутся в тот же журнал.
 */
@Controller('admin')
export class AdminController {
  constructor(private readonly db: PrismaService) {}

  @Get()
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'no-store')
  @Header('X-Frame-Options', 'DENY')
  @Header('Referrer-Policy', 'no-referrer')
  @Header(
    'Content-Security-Policy',
    "default-src 'none'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'",
  )
  page() {
    if (!adminToken()) throw new NotFoundException();
    return adminPageHtml;
  }

  @Get('api/items')
  items(@Headers('x-admin-token') token?: string) {
    this.check(token);
    return itemGroups();
  }

  @Get('api/player')
  async player(@Headers('x-admin-token') token?: string, @Query('who') who = '') {
    this.check(token);
    return this.safely(() => playerInfo(this.db, who.trim()));
  }

  /** Статистика (п. 120): игроки, активность, удержание, тренировки, экономика. */
  @Get('api/stats')
  stats(@Headers('x-admin-token') token?: string) {
    this.check(token);
    return adminStats(this.db);
  }

  /** Нормы пульса по упражнениям (п. 118) — копим для алгоритмов. */
  @Get('api/pulse-norms')
  norms(@Headers('x-admin-token') token?: string) {
    this.check(token);
    return adminPulseNorms(this.db);
  }

  /** Журнал античита (п. 134). */
  @Get('api/suspicions')
  suspicions(
    @Headers('x-admin-token') token?: string,
    @Query('status') status = 'all',
    @Query('kind') kind = '',
    @Query('days') days = '30',
  ) {
    this.check(token);
    const allowed = ['open', 'resolved', 'all'];
    const kinds = ['', 'impossible_set', 'strength_jump', 'flat_pulse'];
    return suspicionLog(this.db, {
      status: allowed.includes(status) ? status : 'all',
      kind: kinds.includes(kind) ? kind : '',
      days: Number.parseInt(days, 10) || 30,
    });
  }

  /** Последние тренировки игрока. */
  @Get('api/player/workouts')
  async workouts(@Headers('x-admin-token') token?: string, @Query('who') who = '') {
    this.check(token);
    return this.safely(() => playerWorkouts(this.db, who.trim()));
  }

  @Post('api/run')
  @HttpCode(200)
  async run(@Headers('x-admin-token') token: string | undefined, @Body(new ZodPipe(RunSchema)) body: z.infer<typeof RunSchema>) {
    this.check(token);
    return this.safely(async () => ({ output: await run(this.db, body.args) }));
  }

  private check(token: unknown) {
    const expected = adminToken();
    if (!expected) throw new NotFoundException();
    if (!tokenMatches(expected, token)) throw new UnauthorizedException('Неверный ключ админки');
  }

  /** Ошибки команд («игрок не найден», «неизвестные вещи») — 400 с текстом. */
  private async safely<T>(fn: () => Promise<T>): Promise<T> {
    try {
      return await fn();
    } catch (e) {
      throw new BadRequestException((e as Error).message);
    }
  }
}
