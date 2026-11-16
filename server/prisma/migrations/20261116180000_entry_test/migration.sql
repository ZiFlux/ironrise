-- Входная тренировка (п. 116): результаты, уровень, выданные монеты.
CREATE TABLE "EntryTest" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "clientId" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL,
    "results" JSONB NOT NULL,
    "level" TEXT NOT NULL,
    "coins" INTEGER NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT "EntryTest_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "EntryTest_userId_clientId_key" ON "EntryTest"("userId", "clientId");
CREATE INDEX "EntryTest_userId_at_idx" ON "EntryTest"("userId", "at");
ALTER TABLE "EntryTest" ADD CONSTRAINT "EntryTest_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
