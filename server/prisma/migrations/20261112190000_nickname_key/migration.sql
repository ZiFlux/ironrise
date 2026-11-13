-- Ключ уникальности ника (src/game/nickname.ts: nicknameKey) и бронь прежних ников.
ALTER TABLE "Profile" ADD COLUMN "nicknameKey" TEXT,
ADD COLUMN "nicknameChangedAt" TIMESTAMP(3);

-- Ники, совпавшие по ключу («Юра» и «юра»): более позднему аккаунту — суффикс _2, _3…
WITH k AS (
  SELECT p."userId",
         row_number() OVER (
           PARTITION BY translate(lower(replace(replace(p."nickname", ' ', ''), '_', '')), 'ёaceopxykmhtb0', 'еасеорхукмнтво')
           ORDER BY u."createdAt"
         ) AS n
  FROM "Profile" p JOIN "User" u ON u."id" = p."userId"
)
UPDATE "Profile" p SET "nickname" = left(p."nickname", 17) || '_' || k.n
FROM k WHERE k."userId" = p."userId" AND k.n > 1;

UPDATE "Profile" SET "nicknameKey" =
  translate(lower(replace(replace("nickname", ' ', ''), '_', '')), 'ёaceopxykmhtb0', 'еасеорхукмнтво');

ALTER TABLE "Profile" ALTER COLUMN "nicknameKey" SET NOT NULL;

-- CreateIndex
CREATE UNIQUE INDEX "Profile_nicknameKey_key" ON "Profile"("nicknameKey");

-- CreateTable
CREATE TABLE "NicknameHold" (
    "key" TEXT NOT NULL,
    "userId" UUID NOT NULL,
    "until" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "NicknameHold_pkey" PRIMARY KEY ("key")
);

-- CreateIndex
CREATE INDEX "NicknameHold_userId_idx" ON "NicknameHold"("userId");

-- AddForeignKey
ALTER TABLE "NicknameHold" ADD CONSTRAINT "NicknameHold_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
