/**
 * Консольная админка: запускается внутри контейнера API (по SSH, docker exec).
 * Команды — в commands.ts, те же доступны в веб-админке (/admin, admin.controller.ts).
 * Каждое изменение пишется в журнал AdminAction.
 *
 *   node dist/admin/admin.js <команда> [аргументы]
 *
 * На компьютере разработчика: ярлык «Админка» (tools/admin.ps1).
 */
import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../generated/prisma/client';
import { run } from './commands';

async function main() {
  const db = new PrismaClient({ adapter: new PrismaPg({ connectionString: process.env.DATABASE_URL! }) });
  try {
    console.log(await run(db, process.argv.slice(2)));
  } catch (e) {
    console.error(`Ошибка: ${(e as Error).message}`);
    process.exitCode = 1;
  } finally {
    await db.$disconnect();
  }
}

void main();
