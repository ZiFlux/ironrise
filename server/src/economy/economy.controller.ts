import { Body, Controller, Get, HttpCode, Param, Post, Put, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { AppearanceSchema, BuySchema, EconomyService } from './economy.service';

@Controller()
@UseGuards(AuthGuard)
export class EconomyController {
  constructor(private readonly economy: EconomyService) {}

  @Post('tips/reward')
  @HttpCode(200)
  tipReward(@UserId() userId: string) {
    return this.economy.tipReward(userId);
  }

  @Post('shop/buy')
  @HttpCode(200)
  buy(@UserId() userId: string, @Body(new ZodPipe(BuySchema)) body: z.infer<typeof BuySchema>) {
    return this.economy.buy(userId, body);
  }

  @Put('me/appearance')
  appearance(@UserId() userId: string, @Body(new ZodPipe(AppearanceSchema)) body: z.infer<typeof AppearanceSchema>) {
    return this.economy.setAppearance(userId, body.appearance);
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
