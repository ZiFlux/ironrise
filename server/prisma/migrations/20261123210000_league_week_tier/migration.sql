-- Уровень лиги игрока в каждую неделю: итог недели считается по составу той недели.
CREATE TABLE "LeagueWeekTier" (
    "userId" UUID NOT NULL,
    "week" TEXT NOT NULL,
    "tier" INTEGER NOT NULL,
    CONSTRAINT "LeagueWeekTier_pkey" PRIMARY KEY ("userId", "week")
);

CREATE INDEX "LeagueWeekTier_week_tier_idx" ON "LeagueWeekTier"("week", "tier");

ALTER TABLE "LeagueWeekTier" ADD CONSTRAINT "LeagueWeekTier_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
