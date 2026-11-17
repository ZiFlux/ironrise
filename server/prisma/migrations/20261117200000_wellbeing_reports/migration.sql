-- Самочувствие после тренировки (п. 81): отдельное согласие и ответы игроков.
-- Ответы — данные о здоровье (152-ФЗ, ст. 10): принимаются только с wellbeingConsentAt,
-- при отзыве согласия удаляются.
ALTER TABLE "Profile" ADD COLUMN "wellbeingConsentAt" TIMESTAMP(3);

CREATE TABLE "WellbeingReport" (
    "id" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "feeling" TEXT NOT NULL,
    "zone" TEXT,
    "painKind" TEXT,
    "exercises" JSONB NOT NULL DEFAULT '[]',
    CONSTRAINT "WellbeingReport_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "WellbeingReport_userId_createdAt_idx" ON "WellbeingReport"("userId", "createdAt");

ALTER TABLE "WellbeingReport" ADD CONSTRAINT "WellbeingReport_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
