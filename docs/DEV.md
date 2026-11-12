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

## Ярлыки управления (tools/)

`tools/create-shortcuts.ps1` создаёт на рабочем столе папку «IronRise — управление» с ярлыками на `tools/*.bat`:
собрать бету (APK, копия кладётся в ту же папку), выложить сервер на VPS (с тестами и проверкой /health),
запустить DEV на телефоне, состояние сервера, логи тестеров, скачать бэкапы базы, установить сборку
на телефоны/часы по Wi-Fi или кабелю (с выбором устройства и сопряжением `adb pair`).
Общие настройки (VPS, домен, серийник телефона) — в `tools/config.ps1`.

## Админка (аккаунты игроков)

`tools/Админка.bat` — команды `find`, `list`, `coins`, `give`/`take`, `xp`, `streak`, `premium`,
`tester`, `ban`/`unban`, `history`, `items` (справка — пустая команда или `help`). Выполняются
`node dist/admin/admin.js` внутри контейнера API по SSH (или в DEV-контейнере на этом компьютере):
сетевого входа в админку нет. Каждое изменение пишется в таблицу `AdminAction`.
Блокировка закрывает вход и обновление сессии (403 с причиной), активные сессии гасятся сразу.

`tools/DEV-сервер.bat` поднимает Docker Desktop, DEV-сервер (:3000) и делает `adb reverse`
для всех подключённых устройств.
