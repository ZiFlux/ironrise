-- CreateTable
CREATE TABLE "JointSession" (
    "id" UUID NOT NULL,
    "hostId" UUID NOT NULL,
    "code" TEXT NOT NULL,
    "codeUntil" TIMESTAMP(3) NOT NULL,
    "endsAt" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "JointSession_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "JointMember" (
    "sessionId" UUID NOT NULL,
    "userId" UUID NOT NULL,
    "joinedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "JointMember_pkey" PRIMARY KEY ("sessionId","userId")
);

-- CreateIndex
CREATE INDEX "JointSession_code_codeUntil_idx" ON "JointSession"("code", "codeUntil");

-- CreateIndex
CREATE INDEX "JointMember_userId_joinedAt_idx" ON "JointMember"("userId", "joinedAt");

-- AddForeignKey
ALTER TABLE "JointSession" ADD CONSTRAINT "JointSession_hostId_fkey" FOREIGN KEY ("hostId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JointMember" ADD CONSTRAINT "JointMember_sessionId_fkey" FOREIGN KEY ("sessionId") REFERENCES "JointSession"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "JointMember" ADD CONSTRAINT "JointMember_userId_fkey" FOREIGN KEY ("userId") REFERENCES "User"("id") ON DELETE CASCADE ON UPDATE CASCADE;
