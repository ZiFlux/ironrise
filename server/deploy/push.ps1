# Выложить сервер IronRise на VPS одной командой. Запуск из папки server:
#   .\deploy\push.ps1 -Server root@1.2.3.4 -Domain api.example.ru
#
# Первый запуск подготовит сервер (Docker, подкачка, файрвол, резервные копии)
# и создаст /opt/ironrise/.env.prod со случайными паролями. Повторные запуски
# только обновляют сервер приложения; база и пароли не трогаются.
# Образ собирается здесь: на VPS с 1 ГБ памяти сборка может не поместиться.
param(
  [Parameter(Mandatory = $true)][string]$Server,
  [Parameter(Mandatory = $true)][string]$Domain
)
$ErrorActionPreference = 'Stop'
$compose = 'docker compose -f compose.prod.yml --env-file .env.prod'

Write-Host '== Сборка образа сервера'
docker build -t ironrise-api:prod .
docker save -o api.tar ironrise-api:prod
tar -czf api.tar.gz api.tar
Remove-Item api.tar

Write-Host '== Копирование на сервер'
ssh $Server 'mkdir -p /opt/ironrise/deploy /opt/ironrise/secrets'
scp compose.prod.yml Caddyfile .env.prod.example api.tar.gz "${Server}:/opt/ironrise/"
scp deploy/setup-server.sh deploy/backup.sh "${Server}:/opt/ironrise/deploy/"
Remove-Item api.tar.gz
$firebase = Test-Path secrets/firebase.json
if ($firebase) { scp secrets/firebase.json "${Server}:/opt/ironrise/secrets/firebase.json" }

Write-Host '== Подготовка сервера (только в первый раз)'
ssh $Server 'command -v docker >/dev/null || bash /opt/ironrise/deploy/setup-server.sh'

$firebasePath = if ($firebase) { '/app/secrets/firebase.json' } else { '' }
$createEnv = "cd /opt/ironrise && test -f .env.prod || { " +
  "printf 'DOMAIN=%s\nDB_PASSWORD=%s\nJWT_SECRET=%s\nFIREBASE_SERVICE_ACCOUNT=%s\n' " +
  "'$Domain' `"`$(openssl rand -hex 24)`" `"`$(openssl rand -hex 32)`" '$firebasePath' > .env.prod && chmod 600 .env.prod; }"
ssh $Server $createEnv

Write-Host '== Загрузка образа и запуск'
ssh $Server "cd /opt/ironrise && gunzip -c api.tar.gz | docker load && rm api.tar.gz && $compose up -d && docker image prune -f"
Write-Host "== Готово: https://$Domain"
