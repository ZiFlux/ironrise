#!/usr/bin/env bash
# Резервная копия базы: /opt/ironrise/backups/ironrise-ГГГГ-ММ-ДД.dump, хранится 7 последних.
# Восстановление: docs/DEPLOY.md, раздел «Резервные копии».
set -euo pipefail
cd /opt/ironrise
file="backups/ironrise-$(date +%F).dump"
docker compose -f compose.prod.yml --env-file .env.prod exec -T db \
  pg_dump -U ironrise -Fc ironrise > "$file"
ls -1t backups/ironrise-*.dump | tail -n +8 | xargs -r rm --
echo "$(date -Is) backup ok: $file"
