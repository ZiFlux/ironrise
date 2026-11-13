-- Сезоны и батлпас: очки сезона и выданные уровни дорожек.
ALTER TABLE "Profile" ADD COLUMN "seasonNumber" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Profile" ADD COLUMN "seasonPoints" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Profile" ADD COLUMN "seasonFree" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Profile" ADD COLUMN "seasonPremium" INTEGER NOT NULL DEFAULT 0;
