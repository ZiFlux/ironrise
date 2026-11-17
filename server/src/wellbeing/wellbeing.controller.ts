/**
 * Самочувствие после тренировки (п. 81). Ответы о боли — данные о здоровье
 * (152-ФЗ, ст. 10): принимаются только с отдельным согласием wellbeingConsentAt,
 * при отзыве согласия удаляются. Подстройка плана работает на телефоне и без них —
 * сервер копит ответы, чтобы находить упражнения, после которых чаще болит.
 */
import { Body, Controller, ForbiddenException, HttpCode, HttpException, Post, Put, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { WELLBEING_PER_DAY, WellbeingConsentSchema, WellbeingSchema } from './wellbeing-schema';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma.service';

@Controller()
@UseGuards(AuthGuard)
export class WellbeingController {
  constructor(private readonly db: PrismaService) {}

  /** Дать или отозвать согласие. Отзыв удаляет все сохранённые ответы. */
  @Put('me/consent/wellbeing')
  @HttpCode(204)
  async consent(@UserId() userId: string, @Body(new ZodPipe(WellbeingConsentSchema)) body: z.infer<typeof WellbeingConsentSchema>) {
    await this.db.$transaction(async (tx) => {
      await tx.profile.update({
        where: { userId },
        data: { wellbeingConsentAt: body.granted ? new Date() : null },
      });
      if (!body.granted) await tx.wellbeingReport.deleteMany({ where: { userId } });
    });
  }

  @Post('wellbeing')
  @HttpCode(204)
  async report(@UserId() userId: string, @Body(new ZodPipe(WellbeingSchema)) body: z.infer<typeof WellbeingSchema>) {
    const profile = await this.db.profile.findUniqueOrThrow({ where: { userId }, select: { wellbeingConsentAt: true } });
    if (!profile.wellbeingConsentAt) throw new ForbiddenException('No wellbeing consent');
    const today = await this.db.wellbeingReport.count({
      where: { userId, createdAt: { gte: new Date(Date.now() - 86_400_000) } },
    });
    if (today >= WELLBEING_PER_DAY) throw new HttpException('Too many wellbeing reports', 429);
    await this.db.wellbeingReport.create({
      data: {
        userId,
        feeling: body.feeling,
        zone: body.zone ?? null,
        painKind: body.painKind ?? null,
        exercises: body.exercises as unknown as Prisma.InputJsonValue,
      },
    });
  }
}
