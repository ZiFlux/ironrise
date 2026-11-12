-- AlterTable
ALTER TABLE "Profile" ALTER COLUMN "formatChangedAt" DROP NOT NULL,
ALTER COLUMN "formatChangedAt" DROP DEFAULT;

-- Смены графика до сих пор не было: время регистрации не должно блокировать первую смену.
UPDATE "Profile" SET "formatChangedAt" = NULL;
