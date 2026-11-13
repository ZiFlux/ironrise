-- Вехи героя, напарник по серии, лента друзей.
ALTER TABLE "Profile" ADD COLUMN "heroMilestone" INTEGER NOT NULL DEFAULT 0;

CREATE TABLE "StreakPair" (
    "id" UUID NOT NULL,
    "aId" UUID NOT NULL,
    "bId" UUID NOT NULL,
    "status" TEXT NOT NULL DEFAULT 'pending',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "since" TEXT,
    CONSTRAINT "StreakPair_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "StreakPair_aId_idx" ON "StreakPair"("aId");
CREATE INDEX "StreakPair_bId_idx" ON "StreakPair"("bId");
ALTER TABLE "StreakPair" ADD CONSTRAINT "StreakPair_aId_fkey" FOREIGN KEY ("aId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "StreakPair" ADD CONSTRAINT "StreakPair_bId_fkey" FOREIGN KEY ("bId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "FeedEvent" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "kind" TEXT NOT NULL,
    "data" JSONB NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "FeedEvent_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "FeedEvent_userId_createdAt_idx" ON "FeedEvent"("userId", "createdAt");
ALTER TABLE "FeedEvent" ADD CONSTRAINT "FeedEvent_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

CREATE TABLE "FeedFist" (
    "eventId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    CONSTRAINT "FeedFist_pkey" PRIMARY KEY ("eventId","userId")
);
ALTER TABLE "FeedFist" ADD CONSTRAINT "FeedFist_eventId_fkey" FOREIGN KEY ("eventId") REFERENCES "FeedEvent"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "FeedFist" ADD CONSTRAINT "FeedFist_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
