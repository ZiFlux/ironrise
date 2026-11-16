-- Журнал античита в админке (п. 134): чем кончился разбор и заметка админа.
ALTER TABLE "Suspicion" ADD COLUMN "resolution" TEXT;
ALTER TABLE "Suspicion" ADD COLUMN "resolvedNote" TEXT;
CREATE INDEX "Suspicion_createdAt_idx" ON "Suspicion"("createdAt");
