import { Body, Controller, Delete, Get, HttpCode, Param, ParseUUIDPipe, Post, Query, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { FriendRequestSchema, SocialService } from './social.service';

@Controller()
@UseGuards(AuthGuard)
export class SocialController {
  constructor(private readonly social: SocialService) {}

  @Get('users/search')
  search(@UserId() userId: string, @Query('nick') nick = '') {
    return this.social.search(userId, nick);
  }

  @Get('friends')
  list(@UserId() userId: string) {
    return this.social.list(userId);
  }

  @Post('friends/requests')
  request(@UserId() userId: string, @Body(new ZodPipe(FriendRequestSchema)) body: z.infer<typeof FriendRequestSchema>) {
    return this.social.request(userId, body.nickname);
  }

  @Post('friends/requests/:id/accept')
  @HttpCode(204)
  async accept(@UserId() userId: string, @Param('id', ParseUUIDPipe) id: string) {
    await this.social.accept(userId, id);
  }

  @Delete('friends/:id')
  @HttpCode(204)
  async remove(@UserId() userId: string, @Param('id', ParseUUIDPipe) id: string) {
    await this.social.remove(userId, id);
  }

  @Post('duels/users/:id')
  fight(@UserId() userId: string, @Param('id', ParseUUIDPipe) id: string) {
    return this.social.fight(userId, id);
  }

  @Get('duels/incoming')
  incoming(@UserId() userId: string) {
    return this.social.attacksOnMe(userId);
  }

  @Get('league/friends')
  friendsLeague(@UserId() userId: string) {
    return this.social.friendsLeague(userId);
  }
}
