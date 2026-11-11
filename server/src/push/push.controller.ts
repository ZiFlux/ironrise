import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { AuthGuard, UserId } from '../auth/auth.guard';
import { ZodPipe } from '../common/zod';
import { PushService } from './push.service';

const DeviceSchema = z.object({
  token: z.string().min(20).max(4096),
  platform: z.enum(['android', 'ios']).default('android'),
});

@Controller('me/devices')
@UseGuards(AuthGuard)
export class PushController {
  constructor(private readonly push: PushService) {}

  /** Телефон сообщает свой FCM-токен после входа и при его обновлении. */
  @Post()
  @HttpCode(204)
  async register(@UserId() userId: string, @Body(new ZodPipe(DeviceSchema)) body: z.infer<typeof DeviceSchema>) {
    await this.push.register(userId, body.token, body.platform);
  }

  /** При выходе из аккаунта: на этот телефон больше не слать. */
  @Post('remove')
  @HttpCode(204)
  async remove(@UserId() userId: string, @Body(new ZodPipe(DeviceSchema)) body: z.infer<typeof DeviceSchema>) {
    await this.push.unregister(userId, body.token);
  }
}
