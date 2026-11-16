import { accessOf, ActiveCache, refreshAccess } from '../src/auth/ban';

// Баг 66б: после бана игрок продолжал играть.

describe('бан', () => {
  const ok = { bannedAt: null, banReason: null };
  const banned = { bannedAt: new Date('2026-11-16T10:00:00Z'), banReason: 'накрутка' };
  const now = new Date('2026-11-16T12:00:00Z');
  const later = new Date('2026-12-16T12:00:00Z');

  it('доступ по токену: нет аккаунта — gone, бан — с причиной', () => {
    expect(accessOf(null)).toEqual({ kind: 'gone' });
    expect(accessOf(ok)).toEqual({ kind: 'ok' });
    expect(accessOf(banned)).toEqual({ kind: 'banned', reason: 'накрутка' });
  });

  it('сессия, отозванная баном, отвечает «заблокирован», а не «войдите заново»', () => {
    expect(refreshAccess({ revokedAt: now, expiresAt: later, user: banned }, now)).toEqual({
      kind: 'banned',
      reason: 'накрутка',
    });
  });

  it('отозванная или просроченная сессия незабаненного — gone', () => {
    expect(refreshAccess(null, now)).toEqual({ kind: 'gone' });
    expect(refreshAccess({ revokedAt: now, expiresAt: later, user: ok }, now)).toEqual({ kind: 'gone' });
    expect(refreshAccess({ revokedAt: null, expiresAt: new Date('2026-11-01'), user: ok }, now)).toEqual({ kind: 'gone' });
    expect(refreshAccess({ revokedAt: null, expiresAt: later, user: ok }, now)).toEqual({ kind: 'ok' });
  });

  it('кэш «не забанен» живёт ttl и сбрасывается при переполнении', () => {
    const cache = new ActiveCache(30_000, 2);
    cache.remember('a', 0);
    expect(cache.isFresh('a', 29_999)).toBe(true);
    expect(cache.isFresh('a', 30_000)).toBe(false);
    cache.remember('b', 0);
    cache.remember('c', 0);
    expect(cache.isFresh('a', 1)).toBe(false);
    expect(cache.isFresh('c', 1)).toBe(true);
    cache.forget('c');
    expect(cache.isFresh('c', 1)).toBe(false);
  });
});
