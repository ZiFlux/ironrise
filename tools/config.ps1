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
  scp -q -o ConnectTimeout=60 $local "${Vps}:/tmp/ironrise-remote.sh"
  if ($LASTEXITCODE -ne 0) { Fail 'Не удалось связаться с сервером по SSH' }
  ssh -o ConnectTimeout=60 $Vps 'bash /tmp/ironrise-remote.sh; rm -f /tmp/ironrise-remote.sh'
}
