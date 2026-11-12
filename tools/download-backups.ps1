# Скачать резервные копии базы с сервера на компьютер (копия на сервере не спасёт,
# если пропадёт сам сервер).
. "$PSScriptRoot\config.ps1"

$target = Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'IronRise-backups'
New-Item -ItemType Directory -Force $target | Out-Null
Step "Копирование в $target"
scp -o ConnectTimeout=60 "${Vps}:/opt/ironrise/backups/*.dump" $target
if ($LASTEXITCODE -ne 0) { Fail 'Не удалось скачать (бэкапов ещё нет — первый делается ночью в 03:30)' }
Get-ChildItem $target -Filter '*.dump' | Sort-Object Name -Descending | Select-Object -First 7 |
  ForEach-Object { Write-Host ("  {0}  {1:N0} КБ" -f $_.Name, ($_.Length / 1KB)) }
Ok 'Готово'
