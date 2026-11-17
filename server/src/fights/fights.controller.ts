import { Body, Controller, Get, HttpCode, Param, ParseUUIDPipe, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { FightsService, RoundSchema } from './fights.service';

/** Бой по раундам (docs/COMBAT.md). Только свои бои; числа и награды считает сервер. */
@Controller('fights')
@UseGuards(AuthGuard)
export class FightsController {
  constructor(private readonly fights: FightsService) {}

  @Get('current')
  current(@UserId() userId: string) {
    return this.fights.current(userId);
  }

  @Post('bots/:botId')
  startBot(@UserId() userId: string, @Param('botId') botId: string) {
    return this.fights.startBot(userId, botId.slice(0, 40));
  }

  @Post('users/:id')
  startFriend(@UserId() userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.fights.startFriend(userId, id);
  }

  @Post(':id/round')
  @HttpCode(200)
  round(
    @UserId() userId: string,
    @Param('id', ParseUUIDPipe) id: string,
    @Body(new ZodPipe(RoundSchema)) body: z.infer<typeof RoundSchema>,
  ) {
    return this.fights.round(userId, id, body);
  }
}
