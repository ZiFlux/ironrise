/**
 * Колорит дуэлей: случайные события со спортзальным юмором и имена ботов.
 * Тексты событий живут в приложении (app/lib/game/duel_flavor.dart) — сервер
 * шлёт только id. Списки id и видов событий в обоих местах должны совпадать.
 */

export type DuelEventKind = 'heal' | 'boost' | 'skip';

export interface DuelEventDef {
  id: string;
  kind: DuelEventKind;
  /** Относительная частота среди событий. */
  weight: number;
}

/**
 * heal — восстановил здоровье; boost — этот удар ×1,5; skip — пропустил ход.
 * Положительных событий чуть больше: они веселее и не затягивают бой.
 */
export const DUEL_EVENTS: readonly DuelEventDef[] = [
  { id: 'creatine', kind: 'heal', weight: 3 },
  { id: 'protein_shake', kind: 'heal', weight: 3 },
  { id: 'buckwheat', kind: 'heal', weight: 2 },
  { id: 'eight_hours_sleep', kind: 'heal', weight: 1 },
  { id: 'pre_workout', kind: 'boost', weight: 3 },
  { id: 'pump', kind: 'boost', weight: 2 },
  { id: 'gym_playlist', kind: 'boost', weight: 2 },
  { id: 'coach_shouts', kind: 'boost', weight: 1 },
  { id: 'mirror_selfie', kind: 'skip', weight: 2 },
  { id: 'bench_hunt', kind: 'skip', weight: 2 },
  { id: 'forgot_towel', kind: 'skip', weight: 1 },
  { id: 'protein_debate', kind: 'skip', weight: 1 },
];

const TOTAL_WEIGHT = DUEL_EVENTS.reduce((s, e) => s + e.weight, 0);

export const pickDuelEvent = (rnd: () => number): DuelEventDef => {
  let x = rnd() * TOTAL_WEIGHT;
  for (const e of DUEL_EVENTS) {
    if (x < e.weight) return e;
    x -= e.weight;
  }
  return DUEL_EVENTS[DUEL_EVENTS.length - 1];
};

const MALE_NAMES = [
  'Стас', 'Валера', 'Богдан', 'Гена', 'Толян', 'Вован', 'Артур', 'Лёха', 'Дэн', 'Серёга', 'Михалыч', 'Жорик',
];
const FEMALE_NAMES = ['Кристина', 'Алёна', 'Света', 'Даша', 'Вика', 'Яна', 'Марина', 'Оля', 'Карина', 'Лиза'];

/** Шаблоны прозвищ: [мужской, женский] — прилагательные согласуются с родом. */
const NICKNAMES: readonly [(n: string) => string, (n: string) => string][] = [
  [(n) => `Протеиновый ${n}`, (n) => `Протеиновая ${n}`],
  [(n) => `Железный ${n}`, (n) => `Железная ${n}`],
  [(n) => `Креатиновый ${n}`, (n) => `Креатиновая ${n}`],
  [(n) => `Сухой ${n}`, (n) => `Сухая ${n}`],
  [(n) => `${n} с турника`, (n) => `${n} с турника`],
  [(n) => `${n} без дня ног`, (n) => `${n} без дня ног`],
  [(n) => `${n} на массе`, (n) => `${n} на сушке`],
  [(n) => `Качок ${n}`, (n) => `Фитоняшка ${n}`],
  [(n) => `Тренер ${n}`, (n) => `Тренер ${n}`],
  [(n) => `${n} из качалки`, (n) => `${n} из качалки`],
  [(n) => `${n} Двести-на-жим`, (n) => `${n} Сто-на-присед`],
  [(n) => `Бицепс-${n}`, (n) => `Пресс-${n}`],
];

/** [count] разных имён ботов; [isFemale] задаёт род для каждого. */
export const botNames = (isFemale: boolean[], rnd: () => number): string[] => {
  const used = new Set<string>();
  return isFemale.map((female) => {
    for (let attempt = 0; ; attempt++) {
      const pool = female ? FEMALE_NAMES : MALE_NAMES;
      const base = pool[Math.floor(rnd() * pool.length)];
      const [m, f] = NICKNAMES[Math.floor(rnd() * NICKNAMES.length)];
      const name = (female ? f : m)(base);
      if (!used.has(name) || attempt > 20) {
        used.add(name);
        return name;
      }
    }
  });
};
