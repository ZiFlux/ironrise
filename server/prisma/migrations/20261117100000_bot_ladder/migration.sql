-- Лестница ботов (п. 88): ступень игрока и побеждённые боты лестницы.
ALTER TABLE "Profile" ADD COLUMN "botTier" INTEGER NOT NULL DEFAULT 0;
ALTER TABLE "Profile" ADD COLUMN "botBeaten" JSONB NOT NULL DEFAULT '[]';
