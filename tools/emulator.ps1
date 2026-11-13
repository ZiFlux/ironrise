# Эмулятор телефона с обоими приложениями: «IronRise» (бета) и «IronRise DEV».
# DEV работает с DEV-сервером на этом компьютере, бета — с боевым сервером.
. "$PSScriptRoot\config.ps1"

$Avd = 'Medium_Phone_API_37.0'
$Sdk = Join-Path $env:LOCALAPPDATA 'Android\Sdk'
$EmulatorExe = Join-Path $Sdk 'emulator\emulator.exe'
if (-not (Test-Path $EmulatorExe)) { Fail 'Эмулятор Android не установлен (Android Studio → SDK Manager → Android Emulator)' }

function Emulator-Serial {
  (& $Adb devices) | Where-Object { $_ -match '^(emulator-\d+)\s+device' } | ForEach-Object { ($_ -split '\s+')[0] } | Select-Object -First 1
}

Step 'DEV-сервер (Docker): база + API на порту 3000'
Set-Location $Server
docker compose up -d 2>&1 | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Host 'Docker не запущен — DEV без сервера будет работать офлайн' -ForegroundColor Yellow }

Step "Эмулятор $Avd"
$serial = Emulator-Serial
if (-not $serial) {
  Start-Process $EmulatorExe -ArgumentList '-avd', $Avd, '-netdelay', 'none', '-netspeed', 'full' | Out-Null
  Write-Host 'Запускаю, первый старт — до пары минут…'
  for ($i = 0; $i -lt 90 -and -not $serial; $i++) { Start-Sleep -Seconds 2; $serial = Emulator-Serial }
  if (-not $serial) { Fail 'Эмулятор не появился за 3 минуты' }
}
for ($i = 0; $i -lt 90; $i++) {
  if (((& $Adb -s $serial shell getprop sys.boot_completed) -join '').Trim() -eq '1') { break }
  Start-Sleep -Seconds 2
}
Ok "Эмулятор готов: $serial"
& $Adb -s $serial reverse tcp:3000 tcp:3000 | Out-Null

Step 'Бета (IronRise) — последняя сборка из папки управления'
$beta = Get-ChildItem $Outbox -Filter 'IronRise-beta-*.apk' -ErrorAction SilentlyContinue | Sort-Object LastWriteTime -Descending | Select-Object -First 1
if ($beta) {
  $out = & $Adb -s $serial install -r $beta.FullName 2>&1 | Out-String
  if ($out -match 'UPDATE_INCOMPATIBLE|SIGNATURES') {
    # На эмуляторе стоит бета с другой подписью — данные там тестовые, ставим начисто.
    Write-Host 'Бета на эмуляторе с другой подписью — переустанавливаю' -ForegroundColor Yellow
    & $Adb -s $serial uninstall com.ironrise.ironrise | Out-Null
    $out = & $Adb -s $serial install $beta.FullName 2>&1 | Out-String
  }
  if ($out -match 'Success') { Ok "Бета: $($beta.Name)" } else { Write-Host $out -ForegroundColor Yellow }
} else {
  Write-Host 'Сборки беты нет — запустите «Собрать бету (APK)»' -ForegroundColor Yellow
}

Step 'DEV (IronRise DEV) — отладочная сборка из текущего кода'
Set-Location $App
flutter build apk --debug
if ($LASTEXITCODE -ne 0) { Fail 'Сборка DEV не удалась — смотрите ошибки выше' }
$out = & $Adb -s $serial install -r (Join-Path $App 'build\app\outputs\flutter-apk\app-debug.apk') 2>&1 | Out-String
if ($out -match 'Success') { Ok 'DEV установлен' } else { Write-Host $out -ForegroundColor Yellow }

while ($true) {
  Write-Host "`nНа эмуляторе $serial оба приложения."
  Write-Host '  Д — открыть IronRise DEV'
  Write-Host '  Б — открыть бету'
  Write-Host '  Р — DEV с горячей перезагрузкой (flutter run; r — перезагрузить, q — выйти)'
  Write-Host '  В — выход (эмулятор продолжит работать)'
  $choice = Read-Host 'Выбор'
  if ($null -eq $choice) { exit 0 }  # ввод закрыт (запуск не из окна)
  switch ($choice.Trim().ToLower()) {
    { $_ -in 'д', 'd' } { & $Adb -s $serial shell monkey -p com.ironrise.ironrise.dev -c android.intent.category.LAUNCHER 1 | Out-Null }
    { $_ -in 'б', 'b' } { & $Adb -s $serial shell monkey -p com.ironrise.ironrise -c android.intent.category.LAUNCHER 1 | Out-Null }
    { $_ -in 'р', 'r' } { & $Adb -s $serial reverse tcp:3000 tcp:3000 | Out-Null; flutter run -d $serial }
    default { exit 0 }
  }
}
