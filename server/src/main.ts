import 'reflect-metadata';
import { NestFactory } from '@nestjs/core';
import { AppModule } from './app.module';

async function bootstrap() {
  // .env для разработки; в продакшене переменные приходят из окружения.
  try {
    process.loadEnvFile();
  } catch {
    // файла нет — используем окружение как есть
  }
  const app = await NestFactory.create(AppModule);
  app.setGlobalPrefix('v1', { exclude: ['health'] });
  const port = Number(process.env.PORT ?? 3000);
  await app.listen(port);
  console.log(`IronRise API listening on http://localhost:${port}`);
}

void bootstrap();
