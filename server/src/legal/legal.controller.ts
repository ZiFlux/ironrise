import { Body, Controller, Get, Header, HttpCode, Put, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { PrismaService } from '../prisma.service';
import { renderPolicyHtml } from './privacy-page';

export const ConsentSchema = z.object({
  /** Согласие на обработку данных о пульсе (здоровье, 152-ФЗ ст. 10). */
  health: z.boolean(),
  /** Дата версии политики, на которую дано согласие (privacyPolicyUpdated в приложении). */
  policyVersion: z.string().min(1).max(40),
});

/**
 * Политика конфиденциальности по ссылке (её требует Google Play) и согласие
 * на данные о пульсе. Без согласия сервер не принимает и не хранит пульс.
 */
@Controller()
export class LegalController {
  constructor(private readonly db: PrismaService) {}

  @Get('privacy')
  @Header('Content-Type', 'text/html; charset=utf-8')
  @Header('Cache-Control', 'public, max-age=3600')
  privacy() {
    return renderPolicyHtml();
  }

  @Put('me/consent')
  @UseGuards(AuthGuard)
  @HttpCode(204)
  async consent(@UserId() userId: string, @Body(new ZodPipe(ConsentSchema)) body: z.infer<typeof ConsentSchema>) {
    await this.db.profile.update({
      where: { userId },
      data: {
        healthConsentAt: body.health ? new Date() : null,
        consentPolicy: body.policyVersion,
      },
    });
  }
}
