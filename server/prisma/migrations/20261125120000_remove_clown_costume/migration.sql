-- Парик и костюм клоуна убраны из игры (25.11.2026). Кто покупал — монеты назад
-- (сколько заплатил на самом деле: цены менялись 18.11), вещи — из инвентаря,
-- с надетого образа — снять: бесплатная причёска и верх по полу героя.
-- Выданные без покупки (админом) просто снимаются, монет за них нет.
INSERT INTO "WalletTx" ("id", "userId", "amount", "reason", "refId")
SELECT gen_random_uuid(), i."userId", -SUM(w."amount"), 'refund', i."itemId"
FROM "InventoryItem" i
JOIN "WalletTx" w
  ON w."userId" = i."userId" AND w."reason" = 'shop' AND w."refId" = i."itemId"
WHERE i."itemId" IN ('hair_clown', 'top_clown')
GROUP BY i."userId", i."itemId"
HAVING SUM(w."amount") < 0;

DELETE FROM "InventoryItem" WHERE "itemId" IN ('hair_clown', 'top_clown');

UPDATE "Profile"
SET "appearance" = jsonb_set(
  "appearance"::jsonb,
  '{hair}',
  to_jsonb(CASE WHEN "appearance"->>'sex' = 'female' THEN 'bob' ELSE 'short' END)
)
WHERE "appearance"->>'hair' = 'clownWig';

UPDATE "Profile"
SET "appearance" = jsonb_set(
  "appearance"::jsonb,
  '{top}',
  to_jsonb(CASE WHEN "appearance"->>'sex' = 'female' THEN 'bra' ELSE 'none' END)
)
WHERE "appearance"->>'top' = 'clownSuit';
