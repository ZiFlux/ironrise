# IronRise: разработка и бета — два окружения

| | dev (разработка) | beta (тестировщики) |
|---|---|---|
| Сборка телефона | `flutter run` (debug) | `flutter build apk --release ...` (docs/BETA.md) |
| Приложение | **IronRise DEV**, `com.ironrise.ironrise.dev` | IronRise, `com.ironrise.ironrise` |
| Часы | `gradlew.bat assembleDebug` → `.dev` | `bundleRelease` / Google Play |
| Сервер | `server/docker-compose.yml`, порт 3000 на компьютере | `server/compose.beta.yml` + туннель |
| База | своя, тестовые аккаунты | бета-тестеры |
| Метка | оранжевая «DEV» в углу | нет |

Отладочная сборка — отдельное приложение со своими данными: её можно поставить рядом с бетой, и тестовые аккаунты, дуэли и тренировки не попадают к бета-тестерам.

## Запуск dev

```
cd server
docker compose up -d --build          # база + API разработки на :3000

adb reverse tcp:3000 tcp:3000         # телефон по USB видит API как 127.0.0.1:3000
                                      # (повторять после переподключения кабеля)
cd ../app
flutter run -d 3B15AW007QP00000
```

Часы для dev: `cd watch/wearos && gradlew.bat assembleDebug`, затем `adb -s <часы> install -r app/build/outputs/apk/debug/app-debug.apk`. Debug-часы (`.dev`) видят только DEV-приложение на телефоне.

Окружение можно задать явно: `--dart-define=ENV=dev|beta`. По умолчанию debug — dev, release — beta.

Пуши в dev не работают: проект Firebase настроен на пакет беты.
