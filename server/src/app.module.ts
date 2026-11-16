import { DevController, devToolsEnabled } from './dev/dev.controller';
import { Controller, Get, MiddlewareConsumer, Module, NestModule } from '@nestjs/common';
import { RateLimitMiddleware } from './common/rate-limit.middleware';
import { JwtModule } from '@nestjs/jwt';
import { AdminController } from './admin/admin.controller';
import { AuthController } from './auth/auth.controller';
import { AuthGuard } from './auth/auth.guard';
import { AuthService } from './auth/auth.service';
import { EconomyController } from './economy/economy.controller';
import { EconomyService } from './economy/economy.service';
import { HeroService } from './hero/hero.service';
import { JointController } from './joint/joint.controller';
import { JointService } from './joint/joint.service';
import { LegalController } from './legal/legal.controller';
import { LogRetention, LogsController } from './logs/logs.controller';
import { PrismaService } from './prisma.service';
import { NotificationsController } from './push/notifications.controller';
import { PushController } from './push/push.controller';
import { PushService } from './push/push.service';
import { SocialController } from './social/social.controller';
import { SocialService } from './social/social.service';
import { WorkoutsController } from './workouts/workouts.controller';
import { WorkoutsService } from './workouts/workouts.service';

@Controller('health')
class HealthController {
  @Get()
  check() {
    return { status: 'ok' };
  }
}

const jwtSecret = () => {
  const secret = process.env.JWT_SECRET;
  if (!secret || secret.length < 32) throw new Error('JWT_SECRET must be set and at least 32 characters long');
  return secret;
};

@Module({
  imports: [
    JwtModule.registerAsync({
      useFactory: () => ({ secret: jwtSecret(), signOptions: { expiresIn: '15m' } }),
    }),
  ],
  controllers: [
    LogsController, LegalController, AdminController,
    HealthController, AuthController, WorkoutsController, EconomyController, SocialController, PushController, NotificationsController, JointController,
    // Только на сервере разработки: выдача монет и прочие инструменты.
    ...(devToolsEnabled ? [DevController] : []),
  ],
  providers: [PrismaService, AuthService, AuthGuard, HeroService, WorkoutsService, EconomyService, SocialService, PushService, JointService, LogRetention],
})
export class AppModule implements NestModule {
  /** Ограничение частоты: перебор паролей и заваливание запросами (common/rate-limit.ts). */
  configure(consumer: MiddlewareConsumer) {
    consumer.apply(RateLimitMiddleware).forRoutes('*path');
  }
}
