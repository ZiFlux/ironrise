-- CreateTable
CREATE TABLE "InventoryItem" (
    "userId" UUID NOT NULL,
    "itemId" TEXT NOT NULL,
    "acquiredAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "InventoryItem_pkey" PRIMARY KEY ("userId","itemId")
);

-- CreateTable
CREATE TABLE "Duel" (
    "id" UUID NOT NULL,
    "attackerId" UUID NOT NULL,
    "opponentKind" TEXT NOT NULL,
    "opponentId" TEXT NOT NULL,
    "day" TEXT NOT NULL,
    "seed" INTEGER NOT NULL,
    "snapshotA" JSONB NOT NULL,
    "snapshotD" JSONB NOT NULL,
    "powerA" INTEGER NOT NULL,
    "powerD" INTEGER NOT NULL,
    "log" JSONB NOT NULL,
    "attackerWon" BOOLEAN NOT NULL,
    "coins" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "Duel_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "Duel_attackerId_day_idx" ON "Duel"("attackerId", "day");

-- CreateIndex
CREATE UNIQUE INDEX "Duel_attackerId_opponentId_day_key" ON "Duel"("attackerId", "opponentId", "day");

-- AddForeignKey
ALTER TABLE "InventoryItem" ADD CONSTRAINT "InventoryItem_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "Duel" ADD CONSTRAINT "Duel_attackerId_fkey" FOREIGN KEY ("attackerId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
