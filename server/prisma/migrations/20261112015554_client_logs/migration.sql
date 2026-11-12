-- CreateTable
CREATE TABLE "ClientLog" (
    "id" UUID NOT NULL,
    "userId" UUID,
    "installId" TEXT NOT NULL,
    "at" TIMESTAMP(3) NOT NULL,
    "level" TEXT NOT NULL,
    "message" TEXT NOT NULL,
    "stack" TEXT,
    "appVersion" TEXT NOT NULL,
    "os" TEXT NOT NULL,
    "env" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "ClientLog_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "ClientLog_createdAt_idx" ON "ClientLog"("createdAt");

-- CreateIndex
CREATE INDEX "ClientLog_installId_at_idx" ON "ClientLog"("installId", "at");

-- CreateIndex
CREATE INDEX "ClientLog_userId_at_idx" ON "ClientLog"("userId", "at");

-- AddForeignKey
ALTER TABLE "ClientLog" ADD CONSTRAINT "ClientLog_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE SET NULL ON UPDATE CASCADE;
