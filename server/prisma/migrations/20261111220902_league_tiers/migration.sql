-- AlterTable
ALTER TABLE "Profile" ADD COLUMN     "leagueLast" JSONB,
ADD COLUMN     "leagueTier" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN     "leagueWeek" TEXT;
