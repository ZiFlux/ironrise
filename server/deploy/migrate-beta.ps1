# Перенести данные беты (аккаунты, тренировки, друзей, лиги) с этого компьютера на VPS.
# База на VPS ЗАМЕНЯЕТСЯ копией беты. Запуск из папки server:
#   .\deploy\migrate-beta.ps1 -Server root@1.2.3.4
param([Parameter(Mandatory = $true)][string]$Server)
# Windows PowerShell 5.1 считает ошибкой любой вывод программ в stderr (а docker и scp
# пишут туда обычный прогресс), поэтому успех проверяется по коду возврата.
$ErrorActionPreference = 'Continue'
function Invoke-Step([string]$What, [scriptblock]$Command) {
  & $Command
  if ($LASTEXITCODE -ne 0) { throw "$What — ошибка (код $LASTEXITCODE)" }
}
# На одном ядре под нагрузкой сервер иногда не успевает принять SSH: ждём дольше.
$ssh = @('-o', 'ConnectTimeout=60', '-o', 'ServerAliveInterval=15')

Write-Host '== Копия базы беты'
Invoke-Step 'копия базы' { docker compose -p ironrise-beta exec -T db pg_dump -U ironrise -Fc ironrise -f /tmp/beta.dump }
Invoke-Step 'копирование копии' { docker compose -p ironrise-beta cp db:/tmp/beta.dump beta.dump }

Write-Host '== Отправка на сервер'
Invoke-Step 'отправка' { scp @ssh beta.dump deploy/restore-beta.sh "${Server}:/opt/ironrise/" }
Remove-Item beta.dump

Write-Host '== Восстановление (на сервере, в фоне)'
Invoke-Step 'запуск восстановления' { ssh @ssh $Server 'cd /opt/ironrise && nohup bash restore-beta.sh > restore.log 2>&1 &' }
for ($i = 0; $i -lt 40; $i++) {
  Start-Sleep -Seconds 15
  $result = ssh @ssh $Server 'grep -h "^RESULT=" /opt/ironrise/restore.log 2>/dev/null'
  if ($result) { break }
}
if ($result -ne 'RESULT=OK') {
  ssh @ssh $Server 'tail -20 /opt/ironrise/restore.log'
  throw "Восстановление не удалось ($result). Журнал выше; база на VPS могла остаться пустой — повторите перенос."
}
Write-Host '== Готово: данные беты на VPS. API применит недостающие миграции при старте (до минуты).'
