/**
 * Ники: проверка, ключ уникальности, запрещённые и кулдаун смены.
 * Совпадает с app/lib/game/nickname.dart.
 */
import { z } from 'zod';
import { BANWORDS, DIACRITICS, LOOKALIKE_TO_CYR, TO_LATIN, TRANSLIT_TO_CYR } from './banwords-data';

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

// ── Фильтр ников: мат, оскорбления, разжигание, политика ──────────────────
// Список — shared/banwords.json. Обходы ловит нормализация: похожие латинские
// буквы и цифры, транслит, повторы букв, диакритика, разделители и смена регистра.

const squeeze = (s: string) => s.replace(/(.)\1+/gu, '$1');
const mapChars = (s: string, table: Record<string, string>) => [...s].map((ch) => table[ch] ?? ch).join('');

const translit = (s: string): string => {
  let out = '';
  for (let i = 0; i < s.length; ) {
    const hit = TRANSLIT_TO_CYR.find(([from]) => s.startsWith(from, i));
    if (hit) {
      out += hit[1];
      i += hit[0].length;
    } else {
      out += s[i];
      i += 1;
    }
  }
  return out;
};

/** Части слов из allow вырезаются разделителем, чтобы корень не склеился через них. */
const cutAllowed = (s: string, allow: readonly string[]) => allow.reduce((acc, a) => acc.split(a).join('·'), s);

interface Forms {
  cyr: string[];
  lat: string;
}

const formsOf = (word: string): Forms => {
  const base = squeeze(mapChars(word.toLowerCase(), DIACRITICS));
  const look = squeeze(mapChars(base, LOOKALIKE_TO_CYR));
  const tr = squeeze(translit(base));
  const lat = squeeze(mapChars(base, TO_LATIN));
  return {
    cyr: [look, tr].map((f) => cutAllowed(f, BANWORDS.cyr.allow)),
    lat: cutAllowed(lat, BANWORDS.latin.allow),
  };
};

/** Слова ника: по пробелам, «_» и смене регистра («ПетяСука» → «Петя», «Сука»). */
const nicknameWords = (nickname: string): string[] =>
  nickname
    .replace(/(\p{Ll})(\p{Lu})/gu, '$1 $2')
    .split(/[\s_]+/u)
    .filter(Boolean);

/** Мат, оскорбления, разжигание или политика — такой ник нельзя. */
export const isOffensiveNickname = (nickname: string): boolean => {
  const words = nicknameWords(nickname);
  const all = formsOf(words.join(''));
  if (all.cyr.some((f) => BANWORDS.cyr.anywhere.some((r) => f.includes(r)))) return true;
  if (BANWORDS.latin.anywhere.some((r) => all.lat.includes(r))) return true;
  return words.some((w) => {
    const f = formsOf(w);
    return (
      f.cyr.some((c) => BANWORDS.cyr.words.includes(c) || BANWORDS.cyr.wordStart.some((r) => c.startsWith(r))) ||
      BANWORDS.latin.words.includes(f.lat) ||
      BANWORDS.latin.wordStart.some((r) => f.lat.startsWith(r))
    );
  });
};
