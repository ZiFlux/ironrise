import { GameConfig } from '../game/config';
import { BadRequestException, ConflictException, ForbiddenException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { z } from 'zod';
import { isValidTimeZone } from '../common/day';
import { assertLookOwned } from '../economy/economy.service';
import { BODY_PARTS } from '../game/body-part';
import { CREATOR_ITEMS } from '../game/start-look';
import { NicknameSchema, isReservedNickname, nicknameKey } from '../game/nickname';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma.service';
import { hashPassword, newRefreshToken, sha256, verifyPassword } from './passwords';

const REFRESH_TTL_DAYS = 30;

export const RegisterSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  password: z.string().min(8).max(128),
  /** ТЗ: приложение 18+, без подтверждения аккаунт не создаётся. */
  adultConfirmed: z.literal(true),
  nickname: NicknameSchema,
  goal: z.string().min(1).max(32),
  trainingFormat: z.string().min(1).max(32),
  scheduleDays: z
    .array(z.number().int().min(0).max(6))
    .min(3)
    .max(7)
    .refine((d) => new Set(d).size === d.length, 'days must be unique'),
  appearance: z.record(z.string(), z.unknown()),
  timezone: z.string().refine(isValidTimeZone, 'unknown time zone').default('UTC'),
  age: z.number().int().min(18).max(90).optional(),
  restingHr: z.number().int().min(35).max(110).optional(),
  /** Согласие на данные о пульсе, данное в приложении до регистрации. */
  healthConsent: z.boolean().optional(),
  policyVersion: z.string().min(1).max(40).optional(),
});

export const DeleteAccountSchema = z.object({
  password: z.string().min(1).max(128),
});

export const LoginSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  password: z.string().min(1).max(128),
});

export const RefreshSchema = z.object({ refreshToken: z.string().min(10) });

/** Заблокированному — 403 с причиной: приложение покажет её и выйдет из аккаунта. */
const assertNotBanned = (user: { bannedAt: Date | null; banReason: string | null }) => {
  if (user.bannedAt) {
    throw new ForbiddenException({ message: `Account banned: ${user.banReason ?? ''}`, banned: true, reason: user.banReason });
  }
};

export interface Tokens {
  accessToken: string;
  refreshToken: string;
}

@Injectable()
export class AuthService {
  constructor(
    private readonly db: PrismaService,
    private readonly jwt: JwtService,
  ) {}

  async register(input: z.infer<typeof RegisterSchema>): Promise<Tokens> {
    const { email, password, nickname, goal, trainingFormat, scheduleDays, appearance, timezone, age, restingHr } =
      input;
    const consentAt = input.healthConsent ? new Date() : null;
    // У нового героя открыт редактор старта: можно всё, что в нём бесплатно.
    assertLookOwned(appearance, CREATOR_ITEMS);
    if (isReservedNickname(nickname)) throw new BadRequestException('Nickname is reserved');
    const key = nicknameKey(nickname);
    if (await this.db.user.findUnique({ where: { email }, select: { id: true } })) {
      throw new ConflictException('Email is taken');
    }
    const held = await this.db.nicknameHold.findFirst({ where: { key, until: { gt: new Date() } } });
    if (held || (await this.db.profile.findUnique({ where: { nicknameKey: key }, select: { userId: true } }))) {
      throw new ConflictException('Nickname is taken');
    }
    try {
      const user = await this.db.user.create({
        data: {
          email,
          passwordHash: await hashPassword(password),
          adultConfirmedAt: new Date(),
          profile: {
            create: {
              nickname,
              nicknameKey: key,
              goal,
              trainingFormat,
              scheduleDays,
              appearance: appearance as Prisma.InputJsonValue,
              timezone,
              age,
              restingHr,
              healthConsentAt: consentAt,
              consentPolicy: input.policyVersion,
            },
          },
          avatarParts: { create: BODY_PARTS.map((part) => ({ part })) },
          walletTx: { create: { amount: GameConfig.welcomeCoins, reason: 'welcome' } },
        },
      });
      return this.issue(user.id);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        // Гонка двух регистраций: что именно заняли, уже не важно.
        throw new ConflictException('Email or nickname is taken');
      }
      throw e;
    }
  }

  async login(input: z.infer<typeof LoginSchema>): Promise<Tokens> {
    const user = await this.db.user.findUnique({ where: { email: input.email } });
    // Одинаковый ответ для «нет такого e-mail» и «неверный пароль».
    if (!user || !(await verifyPassword(input.password, user.passwordHash))) {
      throw new UnauthorizedException('Wrong email or password');
    }
    assertNotBanned(user);
    return this.issue(user.id);
  }

  /** Ротация: старый refresh-токен гасится, выдаётся новая пара. */
  async refresh(refreshToken: string): Promise<Tokens> {
    const stored = await this.db.refreshToken.findUnique({ where: { tokenHash: sha256(refreshToken) } });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token is invalid');
    }
    await this.db.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
    assertNotBanned(await this.db.user.findUniqueOrThrow({ where: { id: stored.userId } }));
    return this.issue(stored.userId);
  }

  async logout(refreshToken: string): Promise<void> {
    await this.db.refreshToken.updateMany({
      where: { tokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
  }

  /**
   * Удаление аккаунта (требование Google Play и 152-ФЗ / GDPR). Всё, что связано
   * с пользователем, удаляется каскадом; дуэли, где он был соперником, — явно.
   */
  async deleteAccount(userId: string, password: string): Promise<void> {
    const user = await this.db.user.findUnique({ where: { id: userId } });
    if (!user || !(await verifyPassword(password, user.passwordHash))) {
      throw new UnauthorizedException('Неверный пароль');
    }
    await this.db.$transaction([
      this.db.duel.deleteMany({ where: { opponentKind: 'user', opponentId: userId } }),
      this.db.user.delete({ where: { id: userId } }),
    ]);
  }

  private async issue(userId: string): Promise<Tokens> {
    const refreshToken = newRefreshToken();
    await this.db.refreshToken.create({
      data: {
        userId,
        tokenHash: sha256(refreshToken),
        expiresAt: new Date(Date.now() + REFRESH_TTL_DAYS * 86_400_000),
      },
    });
    return { accessToken: await this.jwt.signAsync({ sub: userId }), refreshToken };
  }
}
