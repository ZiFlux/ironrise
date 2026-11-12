-- AlterTable
ALTER TABLE "Profile" ADD COLUMN     "isTester" BOOLEAN NOT NULL DEFAULT false,
ADD COLUMN     "premiumUntil" TIMESTAMP(3);

-- Все аккаунты, созданные до этой миграции, — бета-тестеры: премиум навсегда,
-- без штрафа за тренировки без часов и эксклюзивные вещи (src/game/shop.ts, TESTER_ITEMS).
UPDATE "Profile" SET "isTester" = true;
INSERT INTO "InventoryItem" ("userId", "itemId")
SELECT p."userId", i.item
FROM "Profile" p CROSS JOIN (VALUES ('acc_beta_cap'), ('tc_beta'), ('sn_beta')) AS i(item)
ON CONFLICT DO NOTHING;
