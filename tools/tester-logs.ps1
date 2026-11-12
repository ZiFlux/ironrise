# Логи приложения у тестеров (ошибки, сбои связи).
. "$PSScriptRoot\config.ps1"

$nick = Read-Host 'Ник тестера (Enter — все)'
$hours = Read-Host 'За сколько часов (Enter — 24)'
if (-not $hours) { $hours = 24 }
$errorsOnly = Ask 'Только ошибки?'

Set-Location $Server
$params = @{ Server = $Vps; Hours = [int]$hours }
if ($nick) { $params.Nick = $nick }
if ($errorsOnly) { $params.Errors = $true }
& (Join-Path $Server 'deploy\logs.ps1') @args
