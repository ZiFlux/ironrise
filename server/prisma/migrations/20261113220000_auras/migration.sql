-- Ауры для дуэлей: прогресс, выбранная аура и лимит тренировок в неделю.
ALTER TABLE "Profile" ADD COLUMN "auras" JSONB NOT NULL DEFAULT '{}';
ALTER TABLE "Profile" ADD COLUMN "auraEquipped" TEXT;
ALTER TABLE "Profile" ADD COLUMN "auraWeek" TEXT;
ALTER TABLE "Profile" ADD COLUMN "auraSessions" INTEGER NOT NULL DEFAULT 0;
