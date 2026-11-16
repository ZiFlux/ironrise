/**
 * Нормы пульса по упражнениям (п. 118): по сводкам подходов (пик и пульс отдыха, п. 106)
 * — медиана и разброс для каждого упражнения. Пока только для алгоритмов и админки:
 * игрокам не показываем. Разброс — межквартильный размах пика: большой — норма ещё
 * ненадёжна (мало данных или разные люди).
 */
export interface PulseNorm {
  exerciseId: string;
  sets: number;
  peakMedian: number;
  baseMedian: number | null;
  peakSpread: number;
}

/** Меньше — норма не считается. */
export const MIN_SETS_FOR_NORM = 20;

const quantile = (sorted: number[], q: number): number => {
  const pos = (sorted.length - 1) * q;
  const lo = Math.floor(pos);
  const hi = Math.ceil(pos);
  return sorted[lo] + (sorted[hi] - sorted[lo]) * (pos - lo);
};

type Entry = { exerciseId: string; sets: { peak?: number; base?: number }[] };

export const pulseNorms = (workouts: Entry[][], minSets = MIN_SETS_FOR_NORM): PulseNorm[] => {
  const peaks = new Map<string, number[]>();
  const bases = new Map<string, number[]>();
  for (const entries of workouts) {
    for (const e of entries) {
      for (const s of e.sets) {
        if (typeof s.peak === 'number') peaks.set(e.exerciseId, [...(peaks.get(e.exerciseId) ?? []), s.peak]);
        if (typeof s.base === 'number') bases.set(e.exerciseId, [...(bases.get(e.exerciseId) ?? []), s.base]);
      }
    }
  }
  const out: PulseNorm[] = [];
  for (const [exerciseId, list] of peaks) {
    if (list.length < minSets) continue;
    const p = [...list].sort((a, b) => a - b);
    const b = [...(bases.get(exerciseId) ?? [])].sort((x, y) => x - y);
    out.push({
      exerciseId,
      sets: p.length,
      peakMedian: Math.round(quantile(p, 0.5)),
      baseMedian: b.length ? Math.round(quantile(b, 0.5)) : null,
      peakSpread: Math.round(quantile(p, 0.75) - quantile(p, 0.25)),
    });
  }
  return out.sort((a, b) => b.sets - a.sets);
};
