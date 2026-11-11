import { Body, Controller, HttpCode, Post, UseGuards } from '@nestjs/common';
import { z } from 'zod';
import { ZodPipe } from '../common/zod';
import { AuthGuard, UserId } from './auth.guard';
import { AuthService, DeleteAccountSchema, LoginSchema, RefreshSchema, RegisterSchema } from './auth.service';

@Controller('auth')
export class AuthController {
  constructor(private readonly auth: AuthService) {}

  @Post('register')
  register(@Body(new ZodPipe(RegisterSchema)) body: z.infer<typeof RegisterSchema>) {
    return this.auth.register(body);
  }

  @Post('login')
  @HttpCode(200)
  login(@Body(new ZodPipe(LoginSchema)) body: z.infer<typeof LoginSchema>) {
    return this.auth.login(body);
  }

  @Post('refresh')
  @HttpCode(200)
  refresh(@Body(new ZodPipe(RefreshSchema)) body: z.infer<typeof RefreshSchema>) {
    return this.auth.refresh(body.refreshToken);
  }

  @Post('logout')
  @HttpCode(204)
  async logout(@Body(new ZodPipe(RefreshSchema)) body: z.infer<typeof RefreshSchema>) {
    await this.auth.logout(body.refreshToken);
  }

  /** Удалить аккаунт и все данные. Пароль — защита от удаления с чужого телефона. */
  @Post('delete-account')
  @HttpCode(204)
  @UseGuards(AuthGuard)
  async deleteAccount(
    @UserId() userId: string,
    @Body(new ZodPipe(DeleteAccountSchema)) body: z.infer<typeof DeleteAccountSchema>,
  ) {
    await this.auth.deleteAccount(userId, body.password);
  }
}
