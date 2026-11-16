import { createHash, timingSafeEqual } from 'node:crypto';

/**
 * Ключ веб-админки — ADMIN_TOKEN из окружения, не короче 32 знаков.
 * Не задан или короткий — веб-админки нет (404), остаётся консольная.
 */
export const adminToken = (value = process.env.ADMIN_TOKEN): string | null =>
  value && value.length >= 32 ? value : null;

const digest = (s: string) => createHash('sha256').update(s).digest();

/** Сравнение без утечки по времени (хеши одной длины). */
export const tokenMatches = (expected: string | null, given: unknown): boolean =>
  expected != null && typeof given === 'string' && given.length > 0 && timingSafeEqual(digest(expected), digest(given));
