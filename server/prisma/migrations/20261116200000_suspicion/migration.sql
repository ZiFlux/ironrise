-- Подозрения античита (п. 113).
CREATE TABLE "Suspicion" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "workoutId" UUID,
    "kind" TEXT NOT NULL,
    "severe" BOOLEAN NOT NULL DEFAULT false,
    "details" JSONB NOT NULL,
    "blocked" BOOLEAN NOT NULL DEFAULT false,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "resolvedAt" TIMESTAMP(3),
    CONSTRAINT "Suspicion_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "Suspicion_userId_createdAt_idx" ON "Suspicion"("userId", "createdAt");
CREATE INDEX "Suspicion_resolvedAt_idx" ON "Suspicion"("resolvedAt");
ALTER TABLE "Suspicion" ADD CONSTRAINT "Suspicion_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
