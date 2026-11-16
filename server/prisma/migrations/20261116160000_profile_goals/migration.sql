-- Дополнительные цели игрока (п. 100): главная — в "goal", ещё до двух — здесь.
ALTER TABLE "Profile" ADD COLUMN "goals" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];
