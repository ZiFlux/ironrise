/**
 * Сделать игрока бета-тестером: премиум навсегда, без штрафа за тренировки без часов,
 * эксклюзивные вещи тестеров в инвентарь навсегда (даже если статус потом снимут).
 *
 *   node dist/admin/grant-tester.js <ник> [--revoke]
 *
 * На сервере: tools/«Назначить тестера».bat (docker exec в контейнере API).
 */
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client';
import { TESTER_ITEMS } from '../game/shop';

async function main() {
  const [nickname, flag] = process.argv.slice(2);
  if (!nickname) {
    console.error('Укажите ник: node dist/admin/grant-tester.js <ник> [--revoke]');
    process.exit(2);
  }
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }) });
  try {
    const profile = await db.profile.findFirst({ where: { nickname: { equals: nickname, mode: 'insensitive' } } });
    if (!profile) {
      console.error(`Игрок «${nickname}» не найден`);
      process.exit(1);
    }
    const revoke = flag === '--revoke';
    await db.profile.update({ where: { userId: profile.userId }, data: { isTester: !revoke } });
    if (!revoke) {
      await db.inventoryItem.createMany({
        data: TESTER_ITEMS.map((itemId) => ({ userId: profile.userId, itemId })),
        skipDuplicates: true,
      });
    }
    console.log(
      revoke
        ? `${profile.nickname}: статус тестера снят (вещи тестера остаются)`
        : `${profile.nickname}: тестер — премиум, без штрафа за часы, вещи: ${TESTER_ITEMS.join(', ')}`,
    );
  } finally {
    await db.$disconnect();
  }
}

void main();
