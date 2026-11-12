# Сделать игрока бета-тестером: премиум навсегда, без штрафа за часы, вещи тестера навсегда.
. "$PSScriptRoot\config.ps1"

$nick = (Read-Host 'Ник игрока').Trim()
if (-not $nick) { exit 0 }
$revoke = Ask 'Снять статус тестера (вещи останутся)? Обычно — нет'
$flag = if ($revoke) { ' --revoke' } else { '' }
# Ник — в одинарных кавычках для bash; кавычки в самом нике экранируем.
$safe = $nick -replace "'", "'\''"
Step "Сервер $Domain"
Invoke-Remote "docker exec ironrise-api-1 node dist/admin/grant-tester.js '$safe'$flag"
Write-Host "`nИгроку достаточно открыть приложение и синхронизироваться (Профиль → Аккаунт)." -ForegroundColor DarkGray
