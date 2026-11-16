import {
  CanActivate,
  createParamDecorator,
  ExecutionContext,
  ForbiddenException,
  Injectable,
  UnauthorizedException,
} from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '../prisma.service';
import { accessOf, ActiveCache } from './ban';

interface AuthedRequest {
  headers: Record<string, string | undefined>;
  userId?: string;
}

/** Ответ заблокированному: приложение узнаёт его по `banned` и показывает причину. */
export const bannedError = (reason: string | null) =>
  new ForbiddenException({ message: `Account banned: ${reason ?? ''}`, banned: true, reason });

/**
 * Проверяет access-токен из заголовка Authorization: Bearer … и что аккаунт
 * существует и не заблокирован (иначе выданный до бана токен жил бы ещё 15 минут).
 */
@Injectable()
export class AuthGuard implements CanActivate {
  private readonly active = new ActiveCache();

  constructor(
    private readonly jwt: JwtService,
    private readonly db: PrismaService,
  ) {}

  async canActivate(ctx: ExecutionContext): Promise<boolean> {
    const req = ctx.switchToHttp().getRequest<AuthedRequest>();
    const [scheme, token] = (req.headers.authorization ?? '').split(' ');
    if (scheme !== 'Bearer' || !token) throw new UnauthorizedException();
    let userId: string;
    try {
      userId = (await this.jwt.verifyAsync<{ sub: string }>(token)).sub;
    } catch {
      throw new UnauthorizedException();
    }
    await this.assertActive(userId);
    req.userId = userId;
    return true;
  }

  private async assertActive(userId: string): Promise<void> {
    if (this.active.isFresh(userId)) return;
    const access = accessOf(
      await this.db.user.findUnique({ where: { id: userId }, select: { bannedAt: true, banReason: true } }),
    );
    if (access.kind === 'gone') throw new UnauthorizedException();
    if (access.kind === 'banned') {
      this.active.forget(userId);
      throw bannedError(access.reason);
    }
    this.active.remember(userId);
  }
}

/** Id пользователя из проверенного токена. */
export const UserId = createParamDecorator(
  (_: unknown, ctx: ExecutionContext) => ctx.switchToHttp().getRequest<AuthedRequest>().userId,
);
