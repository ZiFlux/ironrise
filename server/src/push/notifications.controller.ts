import { Body, Controller, Get, HttpCode, Post, Put, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { PrismaService } from '../prisma.service';
import { parseSettings, SettingsSchema } from './settings';

const ReadSchema = z.object({
  /** Не указаны — прочитать все. */
  ids: z.array(z.uuid()).max(100).optional(),
});

/** Меню уведомлений: лента событий и настройки пушей. */
@Controller()
@UseGuards(AuthGuard)
export class NotificationsController {
  constructor(private readonly db: PrismaService) {}

  @Get('notifications')
  async list(@UserId() userId: string) {
    const [items, unread] = await Promise.all([
      this.db.notification.findMany({
        where: { userId },
        orderBy: { createdAt: 'desc' },
        take: 50,
        select: { id: true, type: true, title: true, body: true, screen: true, readAt: true, createdAt: true },
      }),
      this.db.notification.count({ where: { userId, readAt: null } }),
    ]);
    return {
      unread,
      items: items.map(({ readAt, ...n }) => ({ ...n, read: readAt !== null })),
    };
  }

  @Post('notifications/read')
  @HttpCode(204)
  async read(@UserId() userId: string, @Body(new ZodPipe(ReadSchema)) body: z.infer<typeof ReadSchema>) {
    await this.db.notification.updateMany({
      where: { userId, readAt: null, ...(body.ids ? { id: { in: body.ids } } : {}) },
      data: { readAt: new Date() },
    });
  }

  @Get('me/notification-settings')
  async settings(@UserId() userId: string) {
    const p = await this.db.profile.findUniqueOrThrow({ where: { userId }, select: { notificationSettings: true } });
    return parseSettings(p.notificationSettings);
  }

  @Put('me/notification-settings')
  async save(@UserId() userId: string, @Body(new ZodPipe(SettingsSchema)) body: z.infer<typeof SettingsSchema>) {
    await this.db.profile.update({ where: { userId }, data: { notificationSettings: body } });
    return body;
  }
}
