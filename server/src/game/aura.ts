/**
 * Ауры для дуэлей. Одна выбранная аура срабатывает в бою один раз: на просадке
 * здоровья (меньше 65 %) или за 3 раунда до конца. Прокачиваются особыми
 * тренировками — не больше [AURA_SESSIONS_PER_WEEK] в неделю, отдельно от
 * основных. Совпадает с app/lib/game/aura.dart.
 *
 * fury  — ярость: свои удары сильнее на 3 хода;
 * guard — стойкость: входящий урон меньше на 3 удара соперника;
 * haste — скорость: сразу лишний удар;
 * focus — фокус: удар без промаха и с усиленным критом.
 */
export const AURA_KINDS = ['fury', 'guard', 'haste', 'focus'] as const;
export type AuraKind = (typeof AURA_KINDS)[number];

export const AURA_SESSIONS_PER_WEEK = 2;

/** Тренировка ауры подтверждается пульсом: длительность и средний пульс. */
export const AURA_MIN_SECONDS = 6 * 60;
export const AURA_MAX_SECONDS = 40 * 60;
/**
 * Нагрузка подтверждена пульсом: средний от [AURA_MIN_AVG_BPM] или пик от [AURA_MIN_PEAK_BPM].
 * 95 в среднем было слишком строго для статики и фокуса (планка держит 80–90 уд/мин).
 */
export const AURA_MIN_AVG_BPM = 85;
export const AURA_MIN_PEAK_BPM = 110;

/** Почему тренировка ауры не засчитана по пульсу; null — всё в порядке. */
export type AuraPulseProblem = 'no_pulse' | 'coverage' | 'low';

export const auraPulseProblem = (
  pulse: { at: Date; bpm: number }[],
  seconds: number,
  minCoverage: number,
): AuraPulseProblem | null => {
  if (pulse.length < 2) return 'no_pulse';
  const covered = (pulse[pulse.length - 1].at.getTime() - pulse[0].at.getTime()) / 1000;
  if (seconds <= 0 || covered / seconds < minCoverage) return 'coverage';
  const avg = pulse.reduce((sum, s) => sum + s.bpm, 0) / pulse.length;
  const peak = Math.max(...pulse.map((s) => s.bpm));
  return avg >= AURA_MIN_AVG_BPM || peak >= AURA_MIN_PEAK_BPM ? null : 'low';
};
export const AURA_MAX_LEVEL = 5;

/** Сколько тренировок ауры нужно для уровня 1…5 (накопительно). */
export const AURA_LEVEL_SESSIONS = [1, 3, 6, 10, 15] as const;

export const auraLevel = (sessions: number): number =>
  AURA_LEVEL_SESSIONS.filter((need) => sessions >= need).length;

/** Тренировок до следующего уровня; null — максимум. */
export const auraSessionsToNext = (sessions: number): number | null => {
  const next = AURA_LEVEL_SESSIONS.find((need) => sessions < need);
  return next === undefined ? null : next - sessions;
};

/** Сила эффекта по уровню. */
export const auraEffect = {
  /** Множитель своих ударов под яростью. */
  fury: (level: number) => 1.2 + 0.05 * level,
  /** Множитель входящего урона под стойкостью. */
  guard: (level: number) => 0.7 - 0.05 * level,
  /** Множитель лишнего удара скорости. */
  haste: (level: number) => 0.8 + 0.05 * level,
  /** Множитель крита под фокусом (обычный крит ×1,5). */
  focus: (level: number) => 1.8 + 0.1 * level,
} as const;

/** Ходов действует длительная аура. */
export const AURA_TURNS = 3;

/** Прогресс аур в профиле: {fury: число тренировок, ...}. */
export type AuraProgress = Record<AuraKind, number>;

export const readAuras = (raw: unknown): AuraProgress => {
  const j = (raw ?? {}) as Partial<Record<string, unknown>>;
  const n = (v: unknown) => (typeof v === 'number' && v > 0 ? Math.floor(v) : 0);
  return { fury: n(j.fury), guard: n(j.guard), haste: n(j.haste), focus: n(j.focus) };
};

export const isAuraKind = (v: unknown): v is AuraKind => AURA_KINDS.includes(v as AuraKind);
