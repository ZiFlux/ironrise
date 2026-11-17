/** Автомодератор ников как задача сервера: при запуске и раз в сутки (nick-moderation.ts). */
import { Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaService } from '../prisma.service';
import { PushService } from '../push/push.service';
import { moderateNicknames } from './nick-moderation';

/** Проверка при запуске сервера (после выкладки с новым списком) и раз в сутки. */
@Injectable()
export class NickModerator implements OnModuleInit, OnModuleDestroy {
  private timer?: NodeJS.Timeout;
  private readonly log = new Logger('Nicknames');

  constructor(
    private readonly db: PrismaService,
    private readonly push: PushService,
  ) {}

  onModuleInit() {
    const run = () =>
      moderateNicknames(this.db, {
        apply: true,
        notify: (userId, _old, next) =>
          this.push.notify(userId, {
            type: 'account',
            title: 'Ник заменён',
            body: `Прежний ник нарушал правила (мат, оскорбления или политика). Теперь ты «${next}» — смени ник в профиле, сейчас это бесплатно.`,
            screen: 'profile',
          }),
      })
        .then((list) => {
          if (list.length) this.log.warn(`заменено ников: ${list.length}`);
        })
        .catch((e) => this.log.warn(`проверка ников: ${(e as Error).message}`));
    // Не мешаем старту: чуть позже, когда всё поднялось.
    setTimeout(() => void run(), 30_000).unref?.();
    this.timer = setInterval(() => void run(), 86_400_000);
    this.timer.unref?.();
  }

  onModuleDestroy() {
    if (this.timer) clearInterval(this.timer);
  }
}
