-- Бустеры за серию: опыт ×1,5 и монеты ×2 на следующую тренировку.
ALTER TABLE "Profile" ADD COLUMN "boosters" JSONB NOT NULL DEFAULT '{}';
