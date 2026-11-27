import { Body, Controller, Get, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { HeroService } from '../hero/hero.service';
import { CardioSchema, StrengthSchema, UndoSchema, WorkoutsService } from './workouts.service';

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

  /** Личные нормы пульса кардио по видам (калибровка, затем своя норма). */
  @Get('cardio/norms')
  cardioNorms(@UserId() userId: string) {
    return this.workouts.cardioNorms(userId);
  }

  /** Откатить только что завершённую тренировку (5 минут), чтобы продолжить её. */
  @Post('workouts/undo')
  @HttpCode(200)
  undo(@UserId() userId: string, @Body(new ZodPipe(UndoSchema)) body: z.infer<typeof UndoSchema>) {
    return this.workouts.undoRecent(userId, body.clientId);
  }

  @Post('workouts/cardio')
  cardio(@UserId() userId: string, @Body(new ZodPipe(CardioSchema)) body: z.infer<typeof CardioSchema>) {
    return this.workouts.submitCardio(userId, body);
  }
}
