# Ярлыки на рабочем столе: папка «IronRise — управление». Запускать повторно можно.
. "$PSScriptRoot\config.ps1"
New-Item -ItemType Directory -Force $Outbox | Out-Null
$shell = New-Object -ComObject WScript.Shell
$icons = @{
  'Собрать бету (APK)'                      = 'imageres.dll,113'
  'Выложить сервер (тестовая - основная)'   = 'imageres.dll,231'
  'Запустить DEV на телефоне'               = 'imageres.dll,41'
  'Состояние сервера'                       = 'imageres.dll,102'
  'Логи тестеров'                           = 'imageres.dll,97'
  'Скачать бэкапы базы'                     = 'imageres.dll,184'
  'Установить на устройства (Wi-Fi)'        = 'imageres.dll,25'
  'Назначить тестера'                       = 'imageres.dll,74'
  'DEV-сервер'                              = 'imageres.dll,104'
  'Админка'                                 = 'imageres.dll,73'
}
foreach ($name in $icons.Keys) {
  $lnk = $shell.CreateShortcut((Join-Path $Outbox "$name.lnk"))
  $lnk.TargetPath = Join-Path $PSScriptRoot "$name.bat"
  $lnk.WorkingDirectory = $PSScriptRoot
  $lnk.IconLocation = Join-Path $env:SystemRoot "System32\$($icons[$name])"
  $lnk.Save()
}
Ok "Ярлыки созданы: $Outbox"
