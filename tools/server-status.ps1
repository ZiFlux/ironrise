# Состояние сервера беты: отвечает ли API, контейнеры, память, диск, бэкапы.
. "$PSScriptRoot\config.ps1"

Step "API https://$Domain"
try {
  $r = Invoke-RestMethod "https://$Domain/health" -TimeoutSec 15
  Write-Host "Отвечает: $($r.status)" -ForegroundColor Green
} catch {
  Write-Host "НЕ отвечает: $($_.Exception.Message)" -ForegroundColor Red
}

Step 'Сервер'
$remote = @'
cd /opt/ironrise
echo "Работает: $(uptime -p)"
echo
echo "Контейнеры:"
docker ps --format '  {{.Names}}: {{.Status}}'
echo
free -m | awk 'NR==2{printf "Память: занято %d из %d МБ\n",$3,$2} NR==3{printf "Подкачка: %d МБ\n",$3}'
df -h / | awk 'NR==2{printf "Диск: занято %s из %s (%s)\n",$3,$2,$5}'
echo
echo "Последние бэкапы:"
found=$(ls -1t backups/*.dump 2>/dev/null | head -3)
if [ -n "$found" ]; then echo "$found" | sed 's|^|  |'; else echo "  пока нет (первый — ночью в 03:30)"; fi
echo
errors=$(docker logs --since 1h ironrise-api-1 2>&1 | grep -ciE 'error|exception')
echo "Ошибок в логах API за час: $errors"
'@
Invoke-Remote $remote
