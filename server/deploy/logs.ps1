# Логи приложения тестеров с сервера. Запуск из папки server:
#   .\deploy\logs.ps1 -Server root@152.228.97.232                  # всё за сутки
#   .\deploy\logs.ps1 -Server root@152.228.97.232 -Nick Юра -Hours 72
#   .\deploy\logs.ps1 -Server root@152.228.97.232 -Errors          # только ошибки
param(
  [Parameter(Mandatory = $true)][string]$Server,
  [string]$Nick = '',
  [int]$Hours = 24,
  [switch]$Errors,
  [int]$Limit = 200
)
$ErrorActionPreference = 'Continue'
# Кириллица в нике должна дойти до psql как UTF-8.
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)

$where = @("l.at > now() - interval '$Hours hours'")
if ($Nick) { $where += "p.nickname ILIKE '%" + $Nick.Replace("'", "''") + "%'" }
if ($Errors) { $where += "l.level = 'error'" }

$sql = @"
SELECT to_char(l.at AT TIME ZONE 'Europe/Moscow', 'DD.MM HH24:MI:SS') AS time_msk,
       coalesce(p.nickname, '(no account) ' || left(l."installId", 8)) AS player,
       l.level, l."appVersion" AS ver,
       left(regexp_replace(l.message, '\s+', ' ', 'g'), 300) AS message
FROM "ClientLog" l LEFT JOIN "Profile" p ON p."userId" = l."userId"
WHERE $($where -join ' AND ')
ORDER BY l.at DESC LIMIT $Limit;
"@

$sql | ssh $Server 'cd /opt/ironrise && docker compose -f compose.prod.yml --env-file .env.prod exec -T db psql -U ironrise -d ironrise -P pager=off'
if ($LASTEXITCODE -ne 0) { throw "Не удалось получить логи (код $LASTEXITCODE)" }
