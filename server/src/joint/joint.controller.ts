import { Body, Controller, Delete, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { JoinSchema, JointService } from './joint.service';

@Controller('joint')
@UseGuards(AuthGuard)
export class JointController {
  constructor(private readonly joint: JointService) {}

  /** Текущая совместная тренировка или null. */
  @Get()
  async current(@UserId() userId: string) {
    return { session: await this.joint.current(userId) };
  }

  @Post()
  create(@UserId() userId: string) {
    return this.joint.create(userId);
  }

  @Post('join')
  join(@UserId() userId: string, @Body(new ZodPipe(JoinSchema)) body: z.infer<typeof JoinSchema>) {
    return this.joint.join(userId, body.code);
  }

  @Delete()
  @HttpCode(204)
  async leave(@UserId() userId: string) {
    await this.joint.leave(userId);
  }
}
