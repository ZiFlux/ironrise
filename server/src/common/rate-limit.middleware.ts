import { Injectable, NestMiddleware } from '@nestjs/common';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { rateLimitVerdict } from './rate-limit';

// Из Express нужны только эти поля — без зависимости от его типов.
type Request = IncomingMessage & { originalUrl: string; body?: { email?: unknown } };
type Response = ServerResponse & { status(code: number): Response; json(body: unknown): void };
type NextFunction = () => void;

/**
 * Адрес клиента: за Caddy — последний в X-Forwarded-For (его дописывает сам Caddy;
 * первые значения может подставить клиент, чтобы обойти лимит).
 */
const clientIp = (req: Request): string => {
  const forwarded = req.headers['x-forwarded-for'];
  const last = (Array.isArray(forwarded) ? forwarded.join(',') : forwarded)?.split(',').pop()?.trim();
  return last || req.socket.remoteAddress || 'unknown';
};

/** 429 с понятным текстом для приложения и Retry-After. */
const tooMany = (res: Response, retryAfter: number) => {
  res.setHeader('Retry-After', String(retryAfter));
  res.status(429).json({ statusCode: 429, message: 'Слишком много попыток — попробуйте позже' });
};

@Injectable()
export class RateLimitMiddleware implements NestMiddleware {
  use(req: Request, res: Response, next: NextFunction) {
    const path = req.originalUrl.split('?')[0];
    const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
    const retry = rateLimitVerdict(path, req.method ?? 'GET', clientIp(req), email);
    if (retry !== null) return tooMany(res, retry);
    next();
  }
}
