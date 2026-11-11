import { ConflictException, Injectable, UnauthorizedException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { z } from 'zod';
import { isValidTimeZone } from '../common/day';
import { assertLookOwned } from '../economy/economy.service';
import { BODY_PARTS } from '../game/body-part';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma.service';
import { hashPassword, newRefreshToken, sha256, verifyPassword } from './passwords';

const REFRESH_TTL_DAYS = 30;

export const RegisterSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  password: z.string().min(8).max(128),
  /** ТЗ: приложение 18+, без подтверждения аккаунт не создаётся. */
  adultConfirmed: z.literal(true),
  nickname: z.string().trim().min(3).max(20).regex(/^[\p{L}\d_ ]+$/u),
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
});

export const LoginSchema = z.object({
  email: z.email().transform((e) => e.toLowerCase()),
  password: z.string().min(1).max(128),
});

export const RefreshSchema = z.object({ refreshToken: z.string().min(10) });

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
    // Новый герой — только в бесплатных вещах.
    assertLookOwned(appearance, new Set());
    try {
      const user = await this.db.user.create({
        data: {
          email,
          passwordHash: await hashPassword(password),
          adultConfirmedAt: new Date(),
          profile: {
            create: {
              nickname,
              goal,
              trainingFormat,
              scheduleDays,
              appearance: appearance as Prisma.InputJsonValue,
              timezone,
              age,
              restingHr,
            },
          },
          avatarParts: { create: BODY_PARTS.map((part) => ({ part })) },
        },
      });
      return this.issue(user.id);
    } catch (e) {
      if (e instanceof Prisma.PrismaClientKnownRequestError && e.code === 'P2002') {
        throw new ConflictException('Email or nickname is already taken');
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
    return this.issue(user.id);
  }

  /** Ротация: старый refresh-токен гасится, выдаётся новая пара. */
  async refresh(refreshToken: string): Promise<Tokens> {
    const stored = await this.db.refreshToken.findUnique({ where: { tokenHash: sha256(refreshToken) } });
    if (!stored || stored.revokedAt || stored.expiresAt < new Date()) {
      throw new UnauthorizedException('Refresh token is invalid');
    }
    await this.db.refreshToken.update({ where: { id: stored.id }, data: { revokedAt: new Date() } });
    return this.issue(stored.userId);
  }

  async logout(refreshToken: string): Promise<void> {
    await this.db.refreshToken.updateMany({
      where: { tokenHash: sha256(refreshToken), revokedAt: null },
      data: { revokedAt: new Date() },
    });
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
