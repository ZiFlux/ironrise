-- Стартовый образ. Уже зарегистрированные получают 14 дней от выхода функции (DEFAULT).
-- AlterTable
ALTER TABLE "Profile" ADD COLUMN     "startAppearance" JSONB,
ADD COLUMN     "startLockedAt" TIMESTAMP(3),
ADD COLUMN     "startLookUntil" TIMESTAMP(3) NOT NULL DEFAULT (now() + '14 days'::interval);
