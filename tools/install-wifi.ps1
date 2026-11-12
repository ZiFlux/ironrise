# Поставить последнюю сборку IronRise на телефоны и часы по Wi-Fi (или по кабелю).
# Друг принёс часы — подключаем их по отладке по Wi-Fi и ставим бету.
. "$PSScriptRoot\config.ps1"

$Watch = Join-Path $Repo 'watch\wearos'
$PhoneApk = Join-Path $App 'build\app\outputs\flutter-apk\app-release.apk'
$WatchApk = Join-Path $Watch 'app\build\outputs\apk\release\app-release.apk'

function Get-Devices {
  $list = @()
  foreach ($line in (& $Adb devices -l) | Select-Object -Skip 1) {
    if ($line -notmatch '^(\S+)\s+device\b') { continue }
    $serial = $Matches[1]
    $model = if ($line -match 'model:(\S+)') { $Matches[1] -replace '_', ' ' } else { $serial }
    $chars = (& $Adb -s $serial shell getprop ro.build.characteristics 2>$null) -join ''
    $android = (& $Adb -s $serial shell getprop ro.build.version.release 2>$null) -join ''
    $list += [pscustomobject]@{
      Serial  = $serial
      Model   = $model
      IsWatch = $chars -match 'watch'
      Android = $android.Trim()
      Wifi    = $serial -match ':\d+$'
    }
  }
  return ,$list
}

function Connect-Wifi {
  Write-Host ''
  Write-Host 'На устройстве включите отладку по Wi-Fi (компьютер и устройство — в одной сети):' -ForegroundColor Yellow
  Write-Host '  Телефон: Настройки → Для разработчиков → Отладка по Wi-Fi → «Подключение по коду»'
  Write-Host '  Часы Wear OS: Настройки → Параметры разработчика → Отладка по Wi-Fi →'
  Write-Host '               «Подключить новое устройство»'
  Write-Host '  (Режим разработчика: 7 раз нажать «Номер сборки» в «О телефоне»/«О часах».)'
  $pair = Read-Host "`nIP-адрес и порт из окна сопряжения (например 192.168.0.139:37115)"
  $code = Read-Host 'Код сопряжения (6 цифр)'
  if ($pair -and $code) { & $Adb pair $pair $code }
  $conn = Read-Host 'IP-адрес и порт с главного экрана «Отладка по Wi-Fi» (порт другой!)'
  if ($conn) { & $Adb connect $conn }
}

function Ensure-Apk([bool]$ForWatch) {
  $apk = if ($ForWatch) { $WatchApk } else { $PhoneApk }
  $what = if ($ForWatch) { 'часов' } else { 'телефона' }
  $exists = Test-Path $apk
  if ($exists) {
    $age = (Get-Item $apk).LastWriteTime
    Write-Host "Сборка для $what от $($age.ToString('dd.MM HH:mm'))"
    if (-not (Ask 'Пересобрать перед установкой?')) { return $apk }
  } elseif (-not (Ask "Сборки для $what ещё нет. Собрать сейчас?")) { return $null }

  if ($ForWatch) {
    Step 'Сборка release для часов'
    Push-Location $Watch
    & .\gradlew.bat assembleRelease
    $ok = $LASTEXITCODE -eq 0
    Pop-Location
  } else {
    Step 'Сборка release для телефона'
    Push-Location $App
    if (Test-Path 'firebase.json') { flutter build apk --release --dart-define-from-file=firebase.json }
    else { flutter build apk --release }
    $ok = $LASTEXITCODE -eq 0
    Pop-Location
  }
  if (-not $ok -or -not (Test-Path $apk)) { Write-Host 'Сборка не удалась' -ForegroundColor Red; return $null }
  return $apk
}

function Install-To($device, [string]$apk) {
  Step "Установка на $($device.Model)"
  $out = & $Adb -s $device.Serial install -r $apk 2>&1 | Out-String
  if ($out -match 'Success') { Ok "Готово: $($device.Model)"; return }
  if ($out -match 'INSTALL_FAILED_UPDATE_INCOMPATIBLE') {
    Write-Host 'На устройстве стоит IronRise с другой подписью (старая сборка).' -ForegroundColor Yellow
    Write-Host 'Поставить можно только после удаления — несинхронизированные данные на устройстве пропадут.' -ForegroundColor Yellow
    if (Ask 'Удалить старую версию и установить новую?') {
      & $Adb -s $device.Serial uninstall com.ironrise.ironrise | Out-Null
      $out = & $Adb -s $device.Serial install $apk 2>&1 | Out-String
      if ($out -match 'Success') { Ok "Готово: $($device.Model)"; return }
    }
  }
  Write-Host "Не удалось:`n$out" -ForegroundColor Red
}

& $Adb start-server | Out-Null
while ($true) {
  $devices = Get-Devices
  Step 'Подключённые устройства'
  if ($devices.Count -eq 0) { Write-Host '  нет' }
  for ($i = 0; $i -lt $devices.Count; $i++) {
    $d = $devices[$i]
    $kind = if ($d.IsWatch) { 'часы   ' } else { 'телефон' }
    $via = if ($d.Wifi) { 'Wi-Fi' } else { 'кабель' }
    Write-Host ("  {0}. {1}  {2}  (Android {3}, {4})" -f ($i + 1), $kind, $d.Model, $d.Android, $via)
  }
  Write-Host "`n  П — подключить новое устройство по Wi-Fi    О — обновить список    В — выход"
  $choice = (Read-Host 'Номера устройств через запятую, «все» или буква').Trim().ToLower()
  if ($choice -in @('в', 'q', '')) { break }
  if ($choice -in @('п', 'p')) { Connect-Wifi; continue }
  if ($choice -in @('о', 'r')) { continue }

  $picked = if ($choice -eq 'все') { $devices } else {
    $choice -split '[,\s]+' | Where-Object { $_ -match '^\d+$' } | ForEach-Object { $devices[[int]$_ - 1] } | Where-Object { $_ }
  }
  if (-not $picked) { Write-Host 'Не понял выбор' -ForegroundColor Yellow; continue }

  $apks = @{}
  foreach ($d in $picked) {
    $key = [string]$d.IsWatch
    if (-not $apks.ContainsKey($key)) { $apks[$key] = Ensure-Apk $d.IsWatch }
    if ($apks[$key]) { Install-To $d $apks[$key] }
  }
  Write-Host "`nНа часах приложение увидит телефон, только если на нём стоит IronRise той же бета-сборки." -ForegroundColor DarkGray
}
