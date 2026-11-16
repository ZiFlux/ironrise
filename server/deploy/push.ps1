# Выложить сервер IronRise на VPS одной командой. Запуск из папки server:
#   .\deploy\push.ps1 -Server root@1.2.3.4 -Domain api.example.ru
#
# Первый запуск подготовит сервер (Docker, подкачка, файрвол, резервные копии)
# и создаст /opt/ironrise/.env.prod со случайными паролями. Повторные запуски
# только обновляют сервер приложения; база и пароли не трогаются.
#
# Быстрая выкатка (п. 126): образ делится на две части.
# - Зависимости (node_modules, ~900 МБ) — образ ironrise-api-deps:<хеш package-lock.json>.
#   Едет на VPS, только если его там ещё нет, то есть когда менялись зависимости.
# - Код (dist, prisma) — архив в несколько мегабайт; на VPS к образу зависимостей
#   добавляются файлы (deploy/Dockerfile.runtime) — сборки там нет, памяти хватает.
param(
  [Parameter(Mandatory = $true)][string]$Server,
  [Parameter(Mandatory = $true)][string]$Domain
)
# Windows PowerShell 5.1 считает ошибкой любой вывод программ в stderr (а docker и scp
# пишут туда обычный прогресс), поэтому успех проверяется по коду возврата.
$ErrorActionPreference = 'Continue'
# SSH до VPS иногда обрывается на рукопожатии (код 255) — такой шаг повторяем
# до 3 раз. Остальные ошибки — сразу стоп.
function Invoke-Step([string]$What, [scriptblock]$Command) {
  for ($try = 1; $try -le 3; $try++) {
    & $Command
    if ($LASTEXITCODE -eq 0) { return }
    if ($LASTEXITCODE -ne 255 -or $try -eq 3) { throw "$What — ошибка (код $LASTEXITCODE)" }
    Write-Host "  нет связи с сервером, повтор $($try + 1) из 3…" -ForegroundColor Yellow
    Start-Sleep -Seconds 5
  }
}
$compose = 'docker compose -f compose.prod.yml --env-file .env.prod'
$started = Get-Date

$deps = (Get-FileHash package-lock.json -Algorithm SHA256).Hash.Substring(0, 12).ToLower()
$depsImage = "ironrise-api-deps:$deps"

Write-Host "== Сборка: зависимости $deps и код"
# Образ зависимостей локально берётся из кэша Docker — пересобирается только при новом lock-файле.
Invoke-Step 'образ зависимостей' { docker build -q -f deploy/Dockerfile.deps -t $depsImage . }
Invoke-Step 'сборка кода' { docker build -q -f deploy/Dockerfile.build --build-arg DEPS=$deps -t ironrise-api-build:latest . }
$release = Join-Path $PWD '.release'
if (Test-Path $release) { Remove-Item -Recurse -Force $release }
New-Item -ItemType Directory $release | Out-Null
$container = (docker create ironrise-api-build:latest).Trim()
Invoke-Step 'выгрузка dist' { docker cp "${container}:/app/dist" "$release/dist" }
docker rm $container | Out-Null
Copy-Item -Recurse prisma "$release/prisma"
Copy-Item package.json, prisma.config.ts, deploy/Dockerfile.runtime $release
Invoke-Step 'архив кода' { tar -czf release.tar.gz -C $release . }
Remove-Item -Recurse -Force $release
Write-Host ("  код: {0:N1} МБ" -f ((Get-Item release.tar.gz).Length / 1MB))

Write-Host '== Копирование на сервер'
Invoke-Step 'папки на сервере' { ssh $Server 'mkdir -p /opt/ironrise/deploy /opt/ironrise/secrets' }
Invoke-Step 'копирование кода' { scp compose.prod.yml Caddyfile .env.prod.example release.tar.gz "${Server}:/opt/ironrise/" }
Invoke-Step 'копирование скриптов' { scp deploy/setup-server.sh deploy/backup.sh "${Server}:/opt/ironrise/deploy/" }
# Сайт (../site): заменяем целиком, чтобы удалённые файлы не оставались.
# Сначала копия во временную папку: если scp оборвётся, живой сайт не пострадает.
# Чистим содержимое, а не саму папку: Caddy смонтировал её и иначе видел бы удалённую.
Invoke-Step 'папка для сайта' { ssh $Server 'rm -rf /opt/ironrise/site.new && mkdir -p /opt/ironrise/site.new /opt/ironrise/site' }
Invoke-Step 'scp сайта' { scp -r ../site/. "${Server}:/opt/ironrise/site.new/" }
Invoke-Step 'замена сайта' { ssh $Server 'find /opt/ironrise/site -mindepth 1 -delete && cp -a /opt/ironrise/site.new/. /opt/ironrise/site/ && rm -rf /opt/ironrise/site.new' }
Remove-Item release.tar.gz
$firebase = Test-Path secrets/firebase.json
if ($firebase) { Invoke-Step 'scp firebase' { scp secrets/firebase.json "${Server}:/opt/ironrise/secrets/firebase.json" } }

Write-Host '== Подготовка сервера (только в первый раз)'
Invoke-Step 'подготовка сервера' { ssh $Server 'command -v docker >/dev/null || bash /opt/ironrise/deploy/setup-server.sh' }

$firebasePath = if ($firebase) { '/app/secrets/firebase.json' } else { '' }
$createEnv = "cd /opt/ironrise && test -f .env.prod || { " +
  "printf 'DOMAIN=%s\nDB_PASSWORD=%s\nJWT_SECRET=%s\nFIREBASE_SERVICE_ACCOUNT=%s\n' " +
  "'$Domain' `"`$(openssl rand -hex 24)`" `"`$(openssl rand -hex 32)`" '$firebasePath' > .env.prod && chmod 600 .env.prod; }"
Invoke-Step 'создание .env.prod' { ssh $Server $createEnv }

# Образ зависимостей — только если на VPS такого ещё нет (новый package-lock.json).
$has = $null
for ($try = 1; $try -le 3 -and $null -eq $has; $try++) {
  $out = ssh $Server "docker image inspect $depsImage >/dev/null 2>&1 && echo yes || echo no"
  if ($LASTEXITCODE -eq 0) { $has = ($out -join '').Trim() -eq 'yes' } else { Start-Sleep -Seconds 5 }
}
if ($null -eq $has) { throw 'проверка образа зависимостей на сервере — нет связи' }
if (-not $has) {
  Write-Host '== Зависимости изменились: отправляем образ зависимостей (большой, это редко)'
  Invoke-Step 'docker save' { docker save -o deps.tar $depsImage }
  Invoke-Step 'tar -czf' { tar -czf deps.tar.gz deps.tar }
  Remove-Item deps.tar
  Invoke-Step 'копирование зависимостей' { scp deps.tar.gz "${Server}:/opt/ironrise/" }
  Remove-Item deps.tar.gz
  Invoke-Step 'загрузка зависимостей' { ssh $Server 'cd /opt/ironrise && tar -xzOf deps.tar.gz | docker load && rm deps.tar.gz' }
}

Write-Host '== Сборка на сервере и запуск'
# Старые образы зависимостей удаляем, кроме нужного; Caddy перечитывает Caddyfile без перезапуска.
$remote = @(
  'cd /opt/ironrise',
  'rm -rf release && mkdir release && tar -xzf release.tar.gz -C release && rm release.tar.gz',
  "docker build -q -f release/Dockerfile.runtime --build-arg DEPS=$deps -t ironrise-api:prod release",
  "$compose up -d",
  "($compose exec -T caddy caddy reload --config /etc/caddy/Caddyfile || true)",
  "(docker images ironrise-api-deps --format '{{.Repository}}:{{.Tag}}' | grep -v ':$deps`$' | xargs -r docker rmi || true)",
  'docker image prune -f'
) -join ' && '
Invoke-Step 'сборка и запуск' { ssh $Server $remote }
Write-Host ("== Готово за {0:N0} с: https://$Domain" -f ((Get-Date) - $started).TotalSeconds)
