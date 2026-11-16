import { findExercise, isPlausibleSet } from './exercises';
import { PulseSummary } from './pulse-summary';

/**
 * Античит после тренировки (п. 113): ищем признаки обмана в уже принятой тренировке.
 * Решение всегда за админом — сервер только временно блокирует и зовёт его.
 *
 * - impossible_set (серьёзно): подход за гранью возможного. Приложение такой не пустит
 *   (п. 75), значит, запрос собран в обход приложения → сразу временная блокировка.
 * - strength_jump: в упражнении скачок силы в 1,5 раза и на 20+ кг к лучшему за 60 дней.
 * - flat_pulse: 10+ минут пульса почти без колебаний — у живого человека на тренировке так
 *   не бывает, похоже на подставленные данные.
 * Три подозрения за [WINDOW_DAYS] дней → временная блокировка.
 */
export type CheatKind = 'impossible_set' | 'strength_jump' | 'flat_pulse';

export interface CheatFinding {
  kind: CheatKind;
  severe: boolean;
  details: Record<string, unknown>;
}

export const WINDOW_DAYS = 14;
export const FINDINGS_TO_BLOCK = 3;
export const HISTORY_DAYS = 60;

type SetIn = { weight: number; reps: number };
type EntryIn = { exerciseId: string; sets: SetIn[] };

/** Грубая сила подхода (Эпли, повторы до 30) — как в app/lib/game/set_sanity.dart. */
export const setStrength = (s: SetIn) => s.weight * (1 + Math.min(s.reps, 30) / 30);

/** Лучшая сила по упражнениям из прошлых тренировок. */
export const bestByExercise = (history: EntryIn[][]): Map<string, number> => {
  const best = new Map<string, number>();
  for (const entries of history) {
    for (const e of entries) {
      for (const s of e.sets) {
        if (s.weight <= 0) continue;
        best.set(e.exerciseId, Math.max(best.get(e.exerciseId) ?? 0, setStrength(s)));
      }
    }
  }
  return best;
};

export const findCheats = (args: {
  entries: EntryIn[];
  /** Лучшее за [HISTORY_DAYS] дней до этой тренировки. */
  best: Map<string, number>;
  pulse: PulseSummary | null;
}): CheatFinding[] => {
  const out: CheatFinding[] = [];
  for (const e of args.entries) {
    const exercise = findExercise(e.exerciseId);
    if (!exercise) continue;
    const impossible = e.sets.filter((s) => !isPlausibleSet(exercise, s));
    if (impossible.length) {
      out.push({ kind: 'impossible_set', severe: true, details: { exercise: e.exerciseId, sets: impossible } });
      continue;
    }
    const was = args.best.get(e.exerciseId);
    const now = Math.max(0, ...e.sets.filter((s) => s.weight > 0).map(setStrength));
    if (was && now > was * 1.5 && now - was >= 20) {
      out.push({
        kind: 'strength_jump',
        severe: false,
        details: { exercise: e.exerciseId, was: Math.round(was), now: Math.round(now) },
      });
    }
  }
  const p = args.pulse;
  const minutes = p?.perMinute.filter((m) => m > 0).length ?? 0;
  if (p && minutes >= 10 && p.max - p.min <= 3) {
    out.push({ kind: 'flat_pulse', severe: false, details: { minutes, min: p.min, max: p.max } });
  }
  return out;
};

/** Блокировать: есть серьёзное или накопилось [FINDINGS_TO_BLOCK] за окно (вместе с новыми). */
export const shouldBlock = (findings: CheatFinding[], recentCount: number): boolean =>
  findings.some((f) => f.severe) || (findings.length > 0 && recentCount + findings.length >= FINDINGS_TO_BLOCK);

export const BLOCK_REASON = 'Временная блокировка: проверяем подозрительную тренировку. Если это ошибка — напишите нам';
