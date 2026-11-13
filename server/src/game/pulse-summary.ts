import { PulseSample } from './anti-fraud';

/**
 * Сводка пульса для хранения. Сырой ряд (до 20 000 точек) нужен только в момент
 * отправки: по нему считаются достоверность и зоны кардио. Хранится сводка —
 * в ~100 раз меньше: средний, минимум, максимум и средний пульс по минутам.
 */
export interface PulseSummary {
  /** Сколько было точек. */
  n: number;
  avg: number;
  min: number;
  max: number;
  /** Средний пульс каждой минуты от первой точки; 0 — в эту минуту данных не было. */
  perMinute: number[];
}

export const summarizePulse = (pulse: PulseSample[]): PulseSummary | null => {
  if (pulse.length === 0) return null;
  const sorted = [...pulse].sort((a, b) => a.at.getTime() - b.at.getTime());
  const start = sorted[0].at.getTime();
  const sums: number[] = [];
  const counts: number[] = [];
  let total = 0;
  let min = Infinity;
  let max = -Infinity;
  for (const s of sorted) {
    const m = Math.floor((s.at.getTime() - start) / 60_000);
    sums[m] = (sums[m] ?? 0) + s.bpm;
    counts[m] = (counts[m] ?? 0) + 1;
    total += s.bpm;
    min = Math.min(min, s.bpm);
    max = Math.max(max, s.bpm);
  }
  return {
    n: sorted.length,
    avg: Math.round(total / sorted.length),
    min,
    max,
    perMinute: Array.from({ length: sums.length }, (_, i) => (counts[i] ? Math.round(sums[i] / counts[i]) : 0)),
  };
};
