import { Body, Controller, Get, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { HeroService } from '../hero/hero.service';
import { CardioSchema, StrengthSchema, WorkoutsService } from './workouts.service';

@Controller()
@UseGuards(AuthGuard)
export class WorkoutsController {
  constructor(
    private readonly workouts: WorkoutsService,
    private readonly hero: HeroService,
  ) {}

  /** Состояние героя: опыт, уровни, сила, серия, монеты. */
  @Get('me')
  me(@UserId() userId: string) {
    return this.hero.state(userId);
  }

  @Post('workouts/strength')
  strength(@UserId() userId: string, @Body(new ZodPipe(StrengthSchema)) body: z.infer<typeof StrengthSchema>) {
    return this.workouts.submitStrength(userId, body);
  }

  @Post('workouts/cardio')
  cardio(@UserId() userId: string, @Body(new ZodPipe(CardioSchema)) body: z.infer<typeof CardioSchema>) {
    return this.workouts.submitCardio(userId, body);
  }
}
