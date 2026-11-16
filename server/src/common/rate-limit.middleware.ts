import { Injectable, NestMiddleware } from '@nestjs/common';
import type { IncomingMessage, ServerResponse } from 'node:http';
import { adminByIp, anyByIp, AUTH_LIMITED_PATHS, authByEmail, authByIp } from './rate-limit';

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
    const ip = clientIp(req);
    if (!anyByIp.allow(ip)) return tooMany(res, anyByIp.retryAfterSec(ip));
    const path = req.originalUrl.split('?')[0];
    if ((path === '/admin' || path.startsWith('/v1/admin/')) && !adminByIp.allow(ip)) return tooMany(res, adminByIp.retryAfterSec(ip));
    if (req.method === 'POST' && AUTH_LIMITED_PATHS.includes(path)) {
      if (!authByIp.allow(ip)) return tooMany(res, authByIp.retryAfterSec(ip));
      const email = typeof req.body?.email === 'string' ? req.body.email.trim().toLowerCase() : '';
      if (email && !authByEmail.allow(email)) return tooMany(res, authByEmail.retryAfterSec(email));
    }
    next();
  }
}
