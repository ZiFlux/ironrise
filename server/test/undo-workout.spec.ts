import { undoWorkout } from '../src/workouts/undo';
import { SEASON_POINTS, seasonAt } from '../src/game/season';

/** Подставная транзакция: только то, что трогает откат. */
function fakeTx() {
  const endedAt = new Date('2026-11-27T10:40:00Z');
  const db = {
    workouts: [
      {
        id: 'w1',
        userId: 'u1',
        type: 'strength',
        day: '2026-11-27',
        endedAt,
        validity: 1,
        payload: {
          entries: [{ exerciseId: 'bench_press', sets: [{}, {}, {}] }],
          planCompleted: true,
          summary: { validity: 1 },
          undo: { streakDays: 4, lastActiveDay: '2026-11-25', boosters: { xp: 1, coins: 0 }, heroMilestone: 0 },
        },
      },
    ],
    profile: {
      userId: 'u1',
      musclePoints: { pecs: 10 } as Record<string, number>,
      seasonNumber: seasonAt(endedAt).number,
      seasonPoints: 500,
      streakDays: 5,
      lastActiveDay: '2026-11-27',
      boosters: { xp: 0, coins: 0 },
    } as Record<string, unknown>,
    parts: { chest: 300, arms: 120 } as Record<string, number>,
    xpEvents: [
      { workoutId: 'w1', part: 'chest', xp: 80 },
      { workoutId: 'w1', part: 'arms', xp: 30 },
    ] as { workoutId: string | null; part: string; xp: number }[],
    wallet: [
      { refId: 'w1', amount: 12 },
      { refId: 'w1', amount: 20 },
      { refId: 'other', amount: 100 },
    ] as { refId: string | null; amount: number; reason?: string }[],
  };
  const tx = {
    $executeRaw: async () => 1,
    workout: {
      findUniqueOrThrow: async ({ where }: { where: { id: string } }) => db.workouts.find((w) => w.id === where.id)!,
      count: async () => 0,
      delete: async ({ where }: { where: { id: string } }) => {
        db.workouts = db.workouts.filter((w) => w.id !== where.id);
      },
    },
    profile: {
      findUniqueOrThrow: async () => db.profile,
      update: async ({ data }: { data: Record<string, unknown> }) => Object.assign(db.profile, data),
    },
    xpEvent: {
      findMany: async ({ where }: { where: { workoutId: string } }) => db.xpEvents.filter((e) => e.workoutId === where.workoutId),
      create: async ({ data }: { data: { part: string; xp: number } }) => db.xpEvents.push({ workoutId: null, ...data }),
    },
    avatarPart: {
      findUnique: async ({ where }: { where: { userId_part: { part: string } } }) => ({ xp: db.parts[where.userId_part.part] }),
      update: async ({ where, data }: { where: { userId_part: { part: string } }; data: { xp: number } }) => {
        db.parts[where.userId_part.part] = data.xp;
      },
    },
    walletTx: {
      aggregate: async ({ where }: { where: { refId: string } }) => ({
        _sum: { amount: db.wallet.filter((t) => t.refId === where.refId).reduce((n, t) => n + t.amount, 0) },
      }),
      create: async ({ data }: { data: { amount: number; refId: string; reason: string } }) => db.wallet.push(data),
    },
  };
  return { db, tx: tx as never };
}

describe('откат тренировки', () => {
  it('снимает опыт, монеты, очки мышц и сезона, возвращает серию и удаляет запись', async () => {
    const { db, tx } = fakeTx();
    const r = await undoWorkout(tx, 'w1');

    expect(db.parts).toEqual({ chest: 220, arms: 90 });
    expect(r.xp).toEqual({ chest: -80, arms: -30 });
    expect(db.wallet.reduce((n, t) => n + t.amount, 0)).toBe(100);
    expect(r.coins).toBe(-32);
    expect(db.profile.seasonPoints).toBe(500 - SEASON_POINTS.strength(1, true));
    expect((db.profile.musclePoints as Record<string, number>).pecs).toBeLessThan(10);
    expect(db.profile.streakDays).toBe(4);
    expect(db.profile.lastActiveDay).toBe('2026-11-25');
    expect(db.profile.boosters).toEqual({ xp: 1, coins: 0 });
    expect(r.streakRestored).toBe(true);
    expect(db.workouts).toHaveLength(0);
  });

  it('опыт не уходит ниже нуля', async () => {
    const { db, tx } = fakeTx();
    db.parts.arms = 10;
    await undoWorkout(tx, 'w1');
    expect(db.parts.arms).toBe(0);
  });
});
