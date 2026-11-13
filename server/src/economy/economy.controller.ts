import { Body, Controller, Get, HttpCode, Param, Post, Put, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { AppearanceSchema, BuySchema, EconomyService, NicknameChangeSchema, ScheduleSchema, ShowcaseSchema, StepsSchema, StartLookSchema, TipRewardSchema } from './economy.service';

@Controller()
@UseGuards(AuthGuard)
export class EconomyController {
  constructor(private readonly economy: EconomyService) {}

  @Post('tips/reward')
  @HttpCode(200)
  tipReward(@UserId() userId: string, @Body(new ZodPipe(TipRewardSchema)) body: z.infer<typeof TipRewardSchema>) {
    return this.economy.tipReward(userId, body);
  }

  @Post('shop/buy')
  @HttpCode(200)
  buy(@UserId() userId: string, @Body(new ZodPipe(BuySchema)) body: z.infer<typeof BuySchema>) {
    return this.economy.buy(userId, body);
  }

  /** Сменить формат и дни тренировок — не чаще раза в 7 дней. */
  @Put('me/schedule')
  schedule(@UserId() userId: string, @Body(new ZodPipe(ScheduleSchema)) body: z.infer<typeof ScheduleSchema>) {
    return this.economy.changeSchedule(userId, body);
  }

  /** Сменить ник — раз в 30 дней, раньше — за монеты (paid). */
  @Put('me/nickname')
  nickname(@UserId() userId: string, @Body(new ZodPipe(NicknameChangeSchema)) body: z.infer<typeof NicknameChangeSchema>) {
    return this.economy.changeNickname(userId, body);
  }

  /** Шаги дня отдыха — опыт кардио, раз в день. */
  @Post('me/steps')
  @HttpCode(200)
  steps(@UserId() userId: string, @Body(new ZodPipe(StepsSchema)) body: z.infer<typeof StepsSchema>) {
    return this.economy.claimSteps(userId, body.steps);
  }

  @Put('me/showcase')
  showcase(@UserId() userId: string, @Body(new ZodPipe(ShowcaseSchema)) body: z.infer<typeof ShowcaseSchema>) {
    return this.economy.setShowcase(userId, body);
  }

  @Put('me/appearance')
  appearance(@UserId() userId: string, @Body(new ZodPipe(AppearanceSchema)) body: z.infer<typeof AppearanceSchema>) {
    return this.economy.setAppearance(userId, body.appearance);
  }

  /** Стартовый образ: первые 14 дней бесплатно, lock — зафиксировать как «Старт». */
  @Put('me/start-look')
  startLook(@UserId() userId: string, @Body(new ZodPipe(StartLookSchema)) body: z.infer<typeof StartLookSchema>) {
    return this.economy.setStartLook(userId, body);
  }

  @Get('duels/bots')
  bots(@UserId() userId: string) {
    return this.economy.bots(userId);
  }

  @Post('duels/bots/:botId')
  fight(@UserId() userId: string, @Param('botId') botId: string) {
    return this.economy.fightBot(userId, botId);
  }

  @Get('league')
  league(@UserId() userId: string) {
    return this.economy.league(userId);
  }
}
