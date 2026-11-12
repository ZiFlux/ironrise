# Разработка: сервер DEV на компьютере + отладочная сборка «IronRise DEV» на телефоне.
. "$PSScriptRoot\config.ps1"

Step 'Сервер разработки (Docker): база + API на порту 3000'
Set-Location $Server
docker compose up -d --build
if ($LASTEXITCODE -ne 0) { Fail 'Docker не запустился. Откройте Docker Desktop и повторите.' }

Step 'Телефон видит сервер как 127.0.0.1:3000 (adb reverse)'
& $Adb -s $Phone reverse tcp:3000 tcp:3000
if ($LASTEXITCODE -ne 0) { Fail "Телефон $Phone не найден. Подключите кабель и разрешите отладку." }

Step 'Запуск на телефоне (r — перезагрузить, R — перезапустить, q — выйти)'
Set-Location $App
flutter run -d $Phone
