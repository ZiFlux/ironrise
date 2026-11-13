/**
 * Ники: проверка, ключ уникальности, запрещённые и кулдаун смены.
 * Совпадает с app/lib/game/nickname.dart.
 */
import { z } from 'zod';

const DAY = 24 * 60 * 60 * 1000;

/** Смена ника — раз в 30 дней (первая — сразу); внеочередная — за монеты. */
export const NICKNAME_CHANGE_DAYS = 30;
export const NICKNAME_CHANGE_COINS = 300;
/** Старый ник столько дней закреплён за прежним владельцем: его нельзя сразу занять. */
export const NICKNAME_HOLD_DAYS = 30;

/** Буквы, цифры, «_» и пробелы между словами; 3–20 знаков. */
export const NicknameSchema = z
  .string()
  .transform((s) => s.trim().replace(/\s+/g, ' '))
  .pipe(z.string().min(3).max(20).regex(/^[\p{L}\d_ ]+$/u));

// Латиница и цифры, похожие на кириллицу, после перевода в нижний регистр.
// Та же таблица — в миграции 20261112190000_nickname_key (translate в SQL).
const LOOKALIKE_FROM = 'ёaceopxykmhtb0';
const LOOKALIKE_TO = 'еасеорхукмнтво';

/**
 * Ключ уникальности: «Юра», «юра», «Ю ра», «Юpa» (латинские p и a) дают один ключ.
 * Регистр, пробелы и «_» не различаются.
 */
export const nicknameKey = (nickname: string): string => {
  let out = '';
  for (const ch of nickname.toLowerCase()) {
    if (ch === ' ' || ch === '_') continue;
    const i = LOOKALIKE_FROM.indexOf(ch);
    out += i >= 0 ? LOOKALIKE_TO[i] : ch;
  }
  return out;
};

/** Ники, которые выдают себя за проект или его команду. Сравниваются по ключу, «содержит». */
const RESERVED = [
  'ironrise', 'айронрайз', 'admin', 'админ', 'administrator', 'администратор', 'moderator', 'модератор',
  'support', 'поддержка', 'system', 'система', 'official', 'официальный', 'разработчик', 'developer',
].map(nicknameKey);

export const isReservedNickname = (nickname: string): boolean => {
  const key = nicknameKey(nickname);
  return RESERVED.some((r) => key.includes(r));
};

/** Когда можно бесплатно сменить ник; null — уже можно. */
export const nextNicknameChangeAt = (changedAt: Date | null, now = new Date()): Date | null => {
  if (!changedAt) return null;
  const next = new Date(changedAt.getTime() + NICKNAME_CHANGE_DAYS * DAY);
  return next > now ? next : null;
};

export const nicknameHoldUntil = (now = new Date()) => new Date(now.getTime() + NICKNAME_HOLD_DAYS * DAY);
