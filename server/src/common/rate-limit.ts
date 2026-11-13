/**
 * Ограничение частоты запросов в памяти процесса (один контейнер API — этого
 * достаточно). Скользящее окно: в окне [windowMs] — не больше [limit] запросов
 * на ключ. Чистая логика, без Nest — проверяется в тестах.
 */
export class RateLimiter {
  private readonly hits = new Map<string, number[]>();

  constructor(
    private readonly limit: number,
    private readonly windowMs: number,
  ) {}

  /** true — запрос пропускаем; false — лимит исчерпан. */
  allow(key: string, now = Date.now()): boolean {
    const from = now - this.windowMs;
    const recent = (this.hits.get(key) ?? []).filter((t) => t > from);
    if (recent.length >= this.limit) {
      this.hits.set(key, recent);
      return false;
    }
    recent.push(now);
    this.hits.set(key, recent);
    // Не даём карте расти бесконечно: изредка чистим устаревшие ключи.
    if (this.hits.size > 50_000) this.prune(now);
    return true;
  }

  /** Через сколько секунд снова можно (для заголовка Retry-After). */
  retryAfterSec(key: string, now = Date.now()): number {
    const oldest = (this.hits.get(key) ?? [])[0];
    return oldest === undefined ? 0 : Math.max(1, Math.ceil((oldest + this.windowMs - now) / 1000));
  }

  private prune(now: number) {
    const from = now - this.windowMs;
    for (const [key, times] of this.hits) {
      if (!times.some((t) => t > from)) this.hits.delete(key);
    }
  }
}

/**
 * Лимиты API:
 * - вход, регистрация, удаление аккаунта — 10 попыток за 15 минут на адрес
 *   (защита от перебора паролей) и 5 за 15 минут на e-mail;
 * - все запросы — 600 в минуту на адрес (защита от заваливания запросами).
 */
export const authByIp = new RateLimiter(10, 15 * 60_000);
export const authByEmail = new RateLimiter(5, 15 * 60_000);
export const anyByIp = new RateLimiter(600, 60_000);

export const AUTH_LIMITED_PATHS = ['/v1/auth/login', '/v1/auth/register', '/v1/auth/delete-account'];
