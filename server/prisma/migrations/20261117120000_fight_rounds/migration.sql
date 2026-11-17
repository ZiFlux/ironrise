-- Бой по раундам (п. 149, docs/COMBAT.md): дуэль идёт несколько запросов.
-- finished = false — бой начат, state — состояние раунда; старые дуэли закончены.
ALTER TABLE "Duel" ADD COLUMN "finished" BOOLEAN NOT NULL DEFAULT true;
ALTER TABLE "Duel" ADD COLUMN "state" JSONB;
ALTER TABLE "Duel" ADD COLUMN "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;
CREATE INDEX "Duel_attackerId_finished_idx" ON "Duel"("attackerId", "finished");
