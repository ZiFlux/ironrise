# Перенести данные беты (аккаунты, тренировки, лиги) с этого компьютера на VPS.
# Запуск из папки server, когда на VPS уже всё запущено:  .\deploy\migrate-beta.ps1 -Server root@1.2.3.4
param([Parameter(Mandatory = $true)][string]$Server)
# Windows PowerShell 5.1 считает ошибкой любой вывод программ в stderr (а docker и scp
# пишут туда обычный прогресс), поэтому успех проверяется по коду возврата.
$ErrorActionPreference = 'Continue'
function Invoke-Step([string]$What, [scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$What — ошибка (код $LASTEXITCODE)" }
}

Write-Host '== Копия базы беты'
Invoke-Step 'docker compose' { docker compose -p ironrise-beta exec -T db pg_dump -U ironrise -Fc ironrise -f /tmp/beta.dump }
Invoke-Step 'docker compose' { docker compose -p ironrise-beta cp db:/tmp/beta.dump beta.dump }

Write-Host '== Восстановление на сервере'
Invoke-Step 'копирование базы' { scp beta.dump "${Server}:/opt/ironrise/beta.dump" }
Remove-Item beta.dump
$restore = 'cd /opt/ironrise && ' +
  'docker compose -f compose.prod.yml --env-file .env.prod stop api && ' +
  'docker compose -f compose.prod.yml --env-file .env.prod exec -T db pg_restore -U ironrise -d ironrise --clean --if-exists --no-owner < beta.dump; ' +
  'rm beta.dump && docker compose -f compose.prod.yml --env-file .env.prod start api'
Invoke-Step 'восстановление на сервере' { ssh $Server $restore }
Write-Host '== Готово. Проверьте вход в приложении с новым адресом сервера.'
