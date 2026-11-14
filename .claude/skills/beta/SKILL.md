---
name: beta
description: Собрать release-бету IronRise (телефон, при необходимости часы), положить APK в папку рассылки и установить на подключённый телефон.
disable-model-invocation: true
argument-hint: "[watch] — собрать ещё и часы"
---

# Бета-сборка

Папка рассылки: `C:\Users\ziflux\Desktop\IronRise — управление`.
adb: `$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe`.

1. Тесты: `flutter test` из `app/`. Красные — не собирать.
2. Версия — из `version:` в `app/pubspec.yaml` (например `1.1.0+3`). Если пользователь
   собирается заливать в RuStore — сначала поднять версию (build-номер обязательно).
3. Телефон, из `app/`:

   ```
   flutter build apk --release --dart-define-from-file=firebase.json
   ```

   Скопировать `app/build/app/outputs/flutter-apk/app-release.apk` в папку рассылки как
   `IronRise-beta-<версия>-<YYYY-MM-DD_HHMM>.apk`.
4. Если передан аргумент `watch` или менялся `watch/`: из `watch/wearos` — `gradlew.bat assembleRelease`,
   копия как `IronRise-watch-<версия>-<дата>.apk`; установить на часы (`adb devices`, Wi-Fi-устройство `adb-RFAT90G886J-…`).
5. Установить на телефон: `adb devices`, затем `adb -s <serial> install -r <apk>`.
   Телефон пользователя — `3B15AW007QP00000`. Если установка падает из-за подписи
   (клон в профиле Island) — сказать пользователю, не удалять приложение самостоятельно.
6. Отчёт: имена файлов в папке рассылки, куда установлено, версия.
