# Выложить сервер с компьютера на VPS: «тестовая → основная».
. "$PSScriptRoot\config.ps1"

Write-Host "Будет обновлён сервер беты https://$Domain (тестеры его используют)."
Write-Host 'База и пароли не трогаются; новые миграции базы применятся сами.'
if (-not (Ask 'Продолжить?')) { exit 0 }

Set-Location $Server
Step 'Проверка серверных тестов'
npx jest --silent
if ($LASTEXITCODE -ne 0) { Fail 'Серверные тесты не прошли — выкладывать нельзя' }

& (Join-Path $Server 'deploy\push.ps1') -Server $Vps -Domain $Domain
if (-not $?) { Fail 'Выкладка не удалась — смотрите ошибки выше' }

Step 'Проверка, что сервер поднялся'
for ($i = 0; $i -lt 20; $i++) {
  try {
    $r = Invoke-RestMethod "https://$Domain/health" -TimeoutSec 10
    if ($r.status -eq 'ok') { Ok "Сервер обновлён и отвечает: https://$Domain"; exit 0 }
  } catch {}
  Start-Sleep -Seconds 10
}
Fail 'Сервер не ответил за 3 минуты. Запустите «Состояние сервера» и посмотрите логи API.'
