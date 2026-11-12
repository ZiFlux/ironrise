# Собрать бету (release APK) для тестеров и, по желанию, поставить на телефон.
. "$PSScriptRoot\config.ps1"

Step 'Сборка APK беты (адрес сервера: https://' + $Domain + ')'
Set-Location $App
$firebase = Join-Path $App 'firebase.json'
if (Test-Path $firebase) {
  flutter build apk --release --dart-define-from-file=firebase.json
} else {
  Write-Host 'firebase.json нет — пуши в этой сборке будут выключены' -ForegroundColor Yellow
  flutter build apk --release
}
if ($LASTEXITCODE -ne 0) { Fail 'Сборка не удалась — смотрите ошибки выше' }

$apk = Join-Path $App 'build\app\outputs\flutter-apk\app-release.apk'
$version = (Select-String -Path (Join-Path $App 'pubspec.yaml') -Pattern '^version:\s*(.+)$').Matches[0].Groups[1].Value.Trim()
New-Item -ItemType Directory -Force $Outbox | Out-Null
$copy = Join-Path $Outbox ("IronRise-beta-$version-" + (Get-Date -Format 'yyyy-MM-dd_HHmm') + '.apk')
Copy-Item $apk $copy
# Храним 5 последних сборок.
Get-ChildItem $Outbox -Filter 'IronRise-beta-*.apk' | Sort-Object LastWriteTime -Descending | Select-Object -Skip 5 | Remove-Item
Ok "Готово: $copy`n  Этот файл можно отправить тестерам (например, в Telegram)."

& $Adb devices | Out-Null
$connected = (& $Adb devices) -match "^$Phone\s+device"
if ($connected -and (Ask 'Телефон подключён. Установить сборку на него?')) {
  Step 'Установка на телефон'
  $out = & $Adb -s $Phone install -r $apk 2>&1 | Out-String
  Write-Host $out
  if ($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
    Write-Host 'На телефоне стоит версия с другой подписью. Синхронизируйте данные (Профиль → Аккаунт),' -ForegroundColor Yellow
    Write-Host 'удалите IronRise (не DEV) и запустите этот ярлык ещё раз.' -ForegroundColor Yellow
  } elseif ($out -match 'Success') { Ok 'Установлено' }
}
