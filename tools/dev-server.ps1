# Локальный DEV-сервер (база + API на :3000) для отладочной сборки «IronRise DEV».
. "$PSScriptRoot\config.ps1"

function Test-Docker { docker info *> $null; return $LASTEXITCODE -eq 0 }

Step 'Docker'
if (-not (Test-Docker)) {
  $exe = Join-Path $env:ProgramFiles 'Docker\Docker\Docker Desktop.exe'
  if (-not (Test-Path $exe)) { Fail 'Docker Desktop не установлен' }
  Write-Host 'Запускаю Docker Desktop…'
  Start-Process $exe
  for ($i = 0; $i -lt 60 -and -not (Test-Docker); $i++) { Start-Sleep -Seconds 3 }
  if (-not (Test-Docker)) { Fail 'Docker не запустился за 3 минуты' }
}
Write-Host 'Docker работает' -ForegroundColor Green

Step 'Сборка и запуск DEV-сервера (первый раз — несколько минут)'
Set-Location $Server
docker compose up -d --build
if ($LASTEXITCODE -ne 0) { Fail 'Не удалось поднять сервер — смотрите ошибки выше' }

Step 'Ждём, пока API ответит'
$ok = $false
for ($i = 0; $i -lt 40; $i++) {
  try { if ((Invoke-RestMethod 'http://localhost:3000/health' -TimeoutSec 3).status -eq 'ok') { $ok = $true; break } } catch {}
  Start-Sleep -Seconds 3
}
if (-not $ok) { Fail 'API не ответил за 2 минуты. Логи: docker compose logs api (в папке server)' }
Write-Host 'API: http://localhost:3000 — работает' -ForegroundColor Green

function Connect-Devices {
  Step 'Проброс порта на телефоны и часы (adb reverse)'
  $devices = (& $Adb devices) | Select-Object -Skip 1 | Where-Object { $_ -match '^(\S+)\s+device\b' } | ForEach-Object { ($_ -split '\s+')[0] }
  if (-not $devices) { Write-Host 'Устройств нет — подключите телефон кабелем или по Wi-Fi и нажмите П' -ForegroundColor Yellow }
  foreach ($d in $devices) {
    & $Adb -s $d reverse tcp:3000 tcp:3000 | Out-Null
    $model = ((& $Adb -s $d shell getprop ro.product.model) -join '').Trim()
    Write-Host "  $model ($d): 127.0.0.1:3000 → этот компьютер" -ForegroundColor Green
  }
}
Connect-Devices

while ($true) {
  Write-Host "`nIronRise DEV на телефоне теперь работает с этим сервером."
  Write-Host '  П — пробросить порт ещё раз (после переподключения кабеля)'
  Write-Host '  Л — логи API (Ctrl+C — выйти из логов)'
  Write-Host '  О — остановить DEV-сервер'
  Write-Host '  В — выход (сервер продолжит работать)'
  switch ((Read-Host 'Выбор').Trim().ToLower()) {
    { $_ -in 'п', 'p' } { Connect-Devices }
    { $_ -in 'л', 'l' } { docker compose logs -f --tail 50 api }
    { $_ -in 'о', 's' } { docker compose stop; Ok 'DEV-сервер остановлен'; exit 0 }
    default { exit 0 }
  }
}
