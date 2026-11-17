import { moderateNicknames } from '../src/admin/nick-moderation';

/** Минимальная поддельная база: профили и журнал админа в памяти. */
const fakeDb = (nicks: string[]) => {
  const profiles = nicks.map((nickname, i) => ({
    userId: `u${i}`,
    nickname,
    nicknameKey: nickname.toLowerCase(),
    nicknameChangedAt: new Date('2026-11-10') as Date | null,
  }));
  const actions: unknown[] = [];
  const db = {
    profile: {
      findMany: async () => profiles.map((p) => ({ userId: p.userId, nickname: p.nickname })),
      findUnique: async ({ where }: { where: { nicknameKey: string } }) =>
        profiles.find((p) => p.nicknameKey === where.nicknameKey) ?? null,
      update: async ({ where, data }: { where: { userId: string }; data: Partial<(typeof profiles)[0]> }) => {
        const p = profiles.find((x) => x.userId === where.userId)!;
        Object.assign(p, data);
        return p;
      },
    },
    adminAction: { create: async ({ data }: { data: unknown }) => actions.push(data) },
  };
  return { db, profiles, actions };
};

describe('автомодератор ников', () => {
  it('находит нарушающие ники и без apply ничего не меняет', async () => {
    const { db, profiles } = fakeDb(['Юра', 'Фюрер Евнух', 'Genka']);
    const list = await moderateNicknames(db as never, { apply: false });
    expect(list.map((v) => v.nickname)).toEqual(['Фюрер Евнух']);
    expect(profiles[1].nickname).toBe('Фюрер Евнух');
  });

  it('заменяет на нейтральный, смена ника — бесплатно, запись в журнал, уведомление', async () => {
    const { db, profiles, actions } = fakeDb(['Юра', 'Фюрер Евнух']);
    const notified: string[] = [];
    const list = await moderateNicknames(db as never, { apply: true, notify: (u) => notified.push(u) });
    expect(list).toHaveLength(1);
    expect(profiles[1].nickname).toMatch(/^Боец \d+$/);
    expect(profiles[1].nicknameChangedAt).toBeNull();
    expect(actions).toHaveLength(1);
    expect(notified).toEqual(['u1']);
    expect(profiles[0].nickname).toBe('Юра');
  });
});
