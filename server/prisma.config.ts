import { defineConfig, env } from 'prisma/config';

// .env читается встроенным в Node загрузчиком; в CI переменные приходят из окружения.
try {
  process.loadEnvFile();
} catch {
  // .env нет — используем переменные окружения как есть.
}

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: { path: 'prisma/migrations' },
  datasource: { url: env('DATABASE_URL') },
});
