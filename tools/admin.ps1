# Админка: управление аккаунтами игроков на сервере (выдать вещи, монеты, бан, поправить опыт).
# Команды выполняются внутри контейнера API по SSH — снаружи по сети их нет.
. "$PSScriptRoot\config.ps1"

$target = Read-Host 'Сервер: Enter — основной (VPS), d — DEV на этом компьютере'
$dev = $target.Trim().ToLower() -in @('d', 'д')

function Admin([string]$ArgsLine) {
  if ($dev) {
    $parts = [regex]::Matches($ArgsLine, "'((?:[^']|'\'')*)'|(\S+)") | ForEach-Object { if ($_.Groups[1].Success) { $_.Groups[1].Value } else { $_.Groups[2].Value } }
    docker exec server-api-1 node dist/admin/admin.js @parts
  } else {
    Invoke-Remote "docker exec ironrise-api-1 node dist/admin/admin.js $ArgsLine"
  }
}

# Аргумент в одинарных кавычках для bash (ники и причины с пробелами).
function Q([string]$s) { "'" + ($s -replace "'", "'\''") + "'" }

Admin 'help'
while ($true) {
  Write-Host ''
  $line = (Read-Host 'Команда (например: find Стас, coins Стас 100 подарок, ban Стас спам) — Enter для выхода').Trim()
  if (-not $line) { break }
  $words = $line -split '\s+', 3
  $cmd = $words[0]
  $who = if ($words.Count -gt 1) { Q $words[1] } else { '' }
  $tail = if ($words.Count -gt 2) {
    # Причины (ban, coins) — одной строкой; остальное — словами.
    if ($cmd -eq 'ban') { Q $words[2] } else { ($words[2] -split '\s+' | ForEach-Object { Q $_ }) -join ' ' }
  } else { '' }
  if ($cmd -in @('ban', 'coins', 'give', 'take', 'xp', 'premium', 'tester', 'streak', 'unban') -and -not $dev) {
    if (-not (Ask "Изменить аккаунт на основном сервере: $line ?")) { continue }
  }
  Admin "$(Q $cmd) $who $tail"
}
