/**
 * Проверка блокировки без зависимостей от NestJS (тестируется jest напрямую).
 * Баг 66б: после бана игрок продолжал играть — выданный токен жил ещё 15 минут,
 * а обновление сессии отвечало «войдите заново» вместо причины блокировки.
 */

export interface BanFields {
  bannedAt: Date | null;
  banReason: string | null;
}

/** ok — можно; gone — аккаунта нет (401); banned — 403 с причиной. */
export type Access = { kind: 'ok' } | { kind: 'gone' } | { kind: 'banned'; reason: string | null };

export const accessOf = (user: BanFields | null): Access =>
  !user ? { kind: 'gone' } : user.bannedAt ? { kind: 'banned', reason: user.banReason } : { kind: 'ok' };

/**
 * Можно ли обменять refresh-токен. Бан проверяется раньше отзыва: бан гасит все
 * сессии, и иначе игрок увидел бы «войдите заново» вместо причины.
 */
export const refreshAccess = (
  stored: { revokedAt: Date | null; expiresAt: Date; user: BanFields } | null,
  now = new Date(),
): Access => {
  if (!stored) return { kind: 'gone' };
  const access = accessOf(stored.user);
  if (access.kind !== 'ok') return access;
  return stored.revokedAt || stored.expiresAt < now ? { kind: 'gone' } : access;
};

/** Помнит, кто недавно был не забанен: бан доходит до игрока не позже ttl. */
export class ActiveCache {
  private readonly okUntil = new Map<string, number>();

  constructor(
    private readonly ttlMs = 30_000,
    private readonly maxSize = 50_000,
  ) {}

  isFresh(userId: string, now = Date.now()): boolean {
    return (this.okUntil.get(userId) ?? 0) > now;
  }

  remember(userId: string, now = Date.now()): void {
    if (this.okUntil.size >= this.maxSize) this.okUntil.clear();
    this.okUntil.set(userId, now + this.ttlMs);
  }

  forget(userId: string): void {
    this.okUntil.delete(userId);
  }
}
