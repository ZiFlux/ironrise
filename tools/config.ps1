# Общие настройки скриптов управления IronRise (tools/*.ps1).
$Repo   = Split-Path -Parent $PSScriptRoot
$App    = Join-Path $Repo 'app'
$Server = Join-Path $Repo 'server'

# Сервер беты на VPS (docs/DEPLOY.md).
$Vps    = 'root@152.228.97.232'
$Domain = 'api.ironrise.ru'

# Телефон для разработки (flutter devices).
$Phone  = '3B15AW007QP00000'

$Adb = Join-Path $env:LOCALAPPDATA 'Android\Sdk\platform-tools\adb.exe'
if (-not (Test-Path $Adb)) { $Adb = 'adb' }

# Куда класть готовые APK.
$Outbox = Join-Path ([Environment]::GetFolderPath('Desktop')) 'IronRise — управление'

$ErrorActionPreference = 'Continue'
[Console]::OutputEncoding = [System.Text.UTF8Encoding]::new($false)
$OutputEncoding = [System.Text.UTF8Encoding]::new($false)

function Step([string]$Text) { Write-Host "`n== $Text" -ForegroundColor Cyan }
function Fail([string]$Text) { Write-Host "`n✖ $Text" -ForegroundColor Red; exit 1 }
function Ok([string]$Text) { Write-Host "`n✔ $Text" -ForegroundColor Green }
function Ask([string]$Question) { (Read-Host "$Question (д/н)") -match '^(д|y|да|yes)$' }

# Выполнить bash-скрипт на сервере. Через файл, а не через аргументы или stdin:
# Windows PowerShell 5.1 срезает кавычки в аргументах и добавляет BOM в stdin.
function Invoke-Remote([string]$Script) {
  $local = Join-Path $env:TEMP 'ironrise-remote.sh'
  [IO.File]::WriteAllText($local, ($Script -replace "`r", ''), [Text.UTF8Encoding]::new($false))
  # SSH до VPS иногда обрывается на рукопожатии — повторяем. Копирование повторять
  # безопасно; команду — только если соединения не было (код 255 и пустой вывод),
  # иначе, например, монеты начислились бы дважды.
  for ($try = 1; $try -le 3; $try++) {
    scp -q -o ConnectTimeout=30 $local "${Vps}:/tmp/ironrise-remote.sh"
    if ($LASTEXITCODE -eq 0) { break }
    if ($try -eq 3) { Fail 'Не удалось связаться с сервером по SSH' }
    Write-Host "Нет связи с сервером, повтор $($try + 1) из 3…" -ForegroundColor Yellow
  }
  for ($try = 1; $try -le 3; $try++) {
    $out = ssh -o ConnectTimeout=30 $Vps 'bash /tmp/ironrise-remote.sh; rm -f /tmp/ironrise-remote.sh'
    $code = $LASTEXITCODE
    if ($code -ne 255 -or $out) { $out; $global:LASTEXITCODE = $code; return }
    if ($try -eq 3) { Fail 'Сервер не ответил по SSH — команда не выполнена' }
    Write-Host "Нет связи с сервером, повтор $($try + 1) из 3…" -ForegroundColor Yellow
  }
}
