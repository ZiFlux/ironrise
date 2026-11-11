# Сборка API IronRise. Миграции применяются при старте контейнера.
FROM node:26.13.0-slim AS build
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY prisma ./prisma
COPY prisma.config.ts tsconfig.json tsconfig.build.json nest-cli.json ./
COPY src ./src
# generate к базе не подключается, но конфиг Prisma требует адрес — даём фиктивный.
RUN DATABASE_URL=postgresql://build@localhost/build npx prisma generate && npx nest build

FROM node:26.13.0-slim
WORKDIR /app
ENV NODE_ENV=production
# CLI Prisma нужен в рантайме для migrate deploy, поэтому node_modules целиком.
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/dist ./dist
COPY package.json prisma.config.ts ./
COPY prisma ./prisma
EXPOSE 3000
USER node
CMD ["sh", "-c", "npx prisma migrate deploy && node dist/main.js"]
