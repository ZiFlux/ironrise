-- Повторные бои с ботом через 5 часов: один бой с соперником в день больше не правило базы.
DROP INDEX "Duel_attackerId_opponentId_day_key";

-- CreateIndex
CREATE INDEX "Duel_attackerId_opponentId_day_idx" ON "Duel"("attackerId", "opponentId", "day");
