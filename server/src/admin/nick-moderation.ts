/**
 * Автомодератор ников (17.11): список банвордов пополняется (shared/banwords.json),
 * а занятые раньше ники фильтр при регистрации уже не видит. Поэтому все ники
 * периодически сверяются с текущим списком: оскорбительный заменяется на нейтральный
 * «Боец 4821», смена ника становится бесплатной, игроку — уведомление, админу — запись.
 */
import { Prisma, PrismaClient } from '../generated/prisma/client';
import { isOffensiveNickname, nicknameKey } from '../game/nickname';

type Db = Pick<PrismaClient, 'profile' | 'adminAction'>;

export interface NickViolation {
  userId: string;
  nickname: string;
  replacement?: string;
}

/** Нейтральный свободный ник: «Боец 1000»–«Боец 9999», при неудаче — с длинным номером. */
export const neutralNickname = async (db: Pick<PrismaClient, 'profile'>, rnd: () => number = Math.random) => {
  for (let attempt = 0; attempt < 50; attempt++) {
    const n = attempt < 40 ? 1000 + Math.floor(rnd() * 9000) : 100_000 + Math.floor(rnd() * 900_000);
    const nickname = `Боец ${n}`;
    const taken = await db.profile.findUnique({ where: { nicknameKey: nicknameKey(nickname) }, select: { userId: true } });
    if (!taken) return nickname;
  }
  throw new Error('Не нашёлся свободный нейтральный ник');
};

/**
 * Проверить все ники. [apply] — заменить нарушающие, иначе только список.
 * [notify] — уведомить игрока (в сервисе; в консоли админа — без пушей).
 */
export async function moderateNicknames(
  db: Db,
  opts: { apply: boolean; notify?: (userId: string, oldNick: string, newNick: string) => void },
): Promise<NickViolation[]> {
  const found: NickViolation[] = [];
  const pageSize = 1000;
  let cursor: string | undefined;
  for (;;) {
    const page = await db.profile.findMany({
      select: { userId: true, nickname: true },
      orderBy: { userId: 'asc' },
      take: pageSize,
      ...(cursor ? { skip: 1, cursor: { userId: cursor } } : {}),
    });
    for (const p of page) {
      if (isOffensiveNickname(p.nickname)) found.push({ userId: p.userId, nickname: p.nickname });
    }
    if (page.length < pageSize) break;
    cursor = page[page.length - 1].userId;
  }
  if (!opts.apply) return found;
  for (const v of found) {
    const replacement = await neutralNickname(db);
    await db.profile.update({
      where: { userId: v.userId },
      // Смена ника после замены — бесплатная и сразу.
      data: { nickname: replacement, nicknameKey: nicknameKey(replacement), nicknameChangedAt: null },
    });
    await db.adminAction.create({
      data: {
        command: 'nick-moderate',
        userId: v.userId,
        details: { from: v.nickname, to: replacement } as Prisma.InputJsonValue,
      },
    });
    v.replacement = replacement;
    opts.notify?.(v.userId, v.nickname, replacement);
  }
  return found;
}
