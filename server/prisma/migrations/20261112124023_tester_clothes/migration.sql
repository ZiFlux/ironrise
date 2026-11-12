-- Одежда бета-тестера (футболка и джоггеры) — всем, кто уже тестер.
INSERT INTO "InventoryItem" ("userId", "itemId")
SELECT p."userId", i.item
FROM "Profile" p CROSS JOIN (VALUES ('top_beta_tee'), ('bottom_beta_joggers')) AS i(item)
WHERE p."isTester"
ON CONFLICT DO NOTHING;
