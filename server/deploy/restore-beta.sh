#!/usr/bin/env bash
# Восстановление копии беты на VPS — полностью заменяет базу.
# Запускается из migrate-beta.ps1 (на сервере в фоне, чтобы обрыв SSH не прервал его).
set -uo pipefail
cd /opt/ironrise
C="docker compose -f compose.prod.yml --env-file .env.prod"

$C stop api
# Схема очищается целиком: pg_restore --clean удалил бы только таблицы из копии, а более
# новые (появившиеся после версии беты) остались бы, мешали восстановлению и миграциям.
if $C exec -T db psql -U ironrise -d ironrise -v ON_ERROR_STOP=1 -qc 'DROP SCHEMA public CASCADE; CREATE SCHEMA public;'   && $C exec -T db pg_restore -U ironrise -d ironrise --no-owner --exit-on-error < beta.dump; then
  RESULT=OK
else
  RESULT=FAIL
fi
rm -f beta.dump
# При старте API сам применит миграции, которых ещё не было в бете.
$C start api
echo "RESULT=$RESULT"
