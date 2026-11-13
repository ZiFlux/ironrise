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

/** Игровые ники ботов латиницей (п. 46 бэклога). Совпадает с app/lib/game/duel_flavor.dart. */
export const BOT_HANDLES_M: readonly string[] = ['xX_IronWolf_Xx', 'BenchGod', 'PumpKing99', 'Gym_Rat_007', 'NoDaysOff', 'BeastMode_ON', 'Lift4Life', 'DeadliftDan', 'ProteinShake', 'Swole_Patrol', 'Max_Rep', 'IronMike_RU', 'Rack_Attack', 'Dumbb3ll', 'Vova_Pump', 'Big_Biceps', 'Squat_Lord', 'Kettle_Bear', 'Grind_Time', 'Spotter_42'];
export const BOT_HANDLES_F: readonly string[] = ['SquatQueen', 'Glute_Goddess', 'Fit_Lisa', 'Iron_Mary', 'PlankPrincess', 'Cardio_Kat', 'Lunge_Lady', 'Strong_Ann', 'Booty_Builder', 'Pilates_Pro', 'Yoga_Rage', 'Kettle_Kira', 'Run_Yana', 'Power_Vika', 'Muscle_Masha', 'Fit_Freak_x', 'Lift_Lena', 'Stretch_Sveta', 'Hip_Thrust_Hero', 'Sweaty_Sonya'];

/** [count] разных ников ботов; [isFemale] задаёт, из какого набора. */
export const botNames = (isFemale: boolean[], rnd: () => number): string[] => {
  const used = new Set<string>();
  return isFemale.map((female) => {
    const pool = female ? BOT_HANDLES_F : BOT_HANDLES_M;
    for (let attempt = 0; ; attempt++) {
      const base = pool[Math.floor(rnd() * pool.length)];
      // Занят — как в играх: с номером (BenchGod_27).
      const name = attempt < 10 ? base : `${base}_${10 + Math.floor(rnd() * 90)}`;
      if (!used.has(name)) {
        used.add(name);
        return name;
      }
    }
  });
};
