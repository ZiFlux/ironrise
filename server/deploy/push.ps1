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
# Windows PowerShell 5.1 считает ошибкой любой вывод программ в stderr (а docker и scp
# пишут туда обычный прогресс), поэтому успех проверяется по коду возврата.
$ErrorActionPreference = 'Continue'
function Invoke-Step([string]$What, [scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$What — ошибка (код $LASTEXITCODE)" }
}
$compose = 'docker compose -f compose.prod.yml --env-file .env.prod'

Write-Host '== Сборка образа сервера'
Invoke-Step 'docker build' { docker build -t ironrise-api:prod . }
Invoke-Step 'docker save' { docker save -o api.tar ironrise-api:prod }
Invoke-Step 'tar -czf' { tar -czf api.tar.gz api.tar }
Remove-Item api.tar

Write-Host '== Копирование на сервер'
Invoke-Step 'папки на сервере' { ssh $Server 'mkdir -p /opt/ironrise/deploy /opt/ironrise/secrets' }
Invoke-Step 'копирование образа' { scp compose.prod.yml Caddyfile .env.prod.example api.tar.gz "${Server}:/opt/ironrise/" }
Invoke-Step 'копирование скриптов' { scp deploy/setup-server.sh deploy/backup.sh "${Server}:/opt/ironrise/deploy/" }
# Сайт (../site): заменяем целиком, чтобы удалённые файлы не оставались.
# Сначала копия во временную папку: если scp оборвётся, живой сайт не пострадает.
# Чистим содержимое, а не саму папку: Caddy смонтировал её и иначе видел бы удалённую.
Invoke-Step 'папка для сайта' { ssh $Server 'rm -rf /opt/ironrise/site.new && mkdir -p /opt/ironrise/site.new /opt/ironrise/site' }
Invoke-Step 'scp сайта' { scp -r ../site/. "${Server}:/opt/ironrise/site.new/" }
Invoke-Step 'замена сайта' { ssh $Server 'find /opt/ironrise/site -mindepth 1 -delete && cp -a /opt/ironrise/site.new/. /opt/ironrise/site/ && rm -rf /opt/ironrise/site.new' }
Remove-Item api.tar.gz
$firebase = Test-Path secrets/firebase.json
if ($firebase) { Invoke-Step 'scp firebase' { scp secrets/firebase.json "${Server}:/opt/ironrise/secrets/firebase.json" } }

Write-Host '== Подготовка сервера (только в первый раз)'
Invoke-Step 'подготовка сервера' { ssh $Server 'command -v docker >/dev/null || bash /opt/ironrise/deploy/setup-server.sh' }

$firebasePath = if ($firebase) { '/app/secrets/firebase.json' } else { '' }
$createEnv = "cd /opt/ironrise && test -f .env.prod || { " +
  "printf 'DOMAIN=%s\nDB_PASSWORD=%s\nJWT_SECRET=%s\nFIREBASE_SERVICE_ACCOUNT=%s\n' " +
  "'$Domain' `"`$(openssl rand -hex 24)`" `"`$(openssl rand -hex 32)`" '$firebasePath' > .env.prod && chmod 600 .env.prod; }"
Invoke-Step 'создание .env.prod' { ssh $Server $createEnv }

Write-Host '== Загрузка образа и запуск'
# Caddy перечитывает Caddyfile (новые адреса сайта) без перезапуска.
Invoke-Step 'загрузка образа и запуск' { ssh $Server "cd /opt/ironrise && tar -xzOf api.tar.gz | docker load && rm api.tar.gz && $compose up -d && ($compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile || true) && docker image prune -f" }
Write-Host "== Готово: https://$Domain"
