# IronRise

Фитнес-RPG: тренировки с проверкой пульсом растят игрового героя; дуэли, лиги, сезоны, друзья.
Разработчик один, Windows, Android (Mac нет). Общение и тексты в приложении — по-русски.

## Структура

- `app/` — Flutter (Riverpod 3, go_router, аватар на CustomPainter 200×400). Тесты: `flutter test` из `app/`.
- `server/` — NestJS + Prisma 7 + Postgres, Zod, jest (`npm test`). Чистая игровая логика — `server/src/game`.
  Миграции пишутся руками в `server/prisma/migrations/<timestamp>_name/migration.sql`, применяются при старте контейнера.
- `watch/wearos/` — приложение Wear OS (Kotlin, Gradle): пульс через SensorManager + wake lock, Data Layer с телефоном.
- `site/` — лендинг ironrise.ru (раздаёт Caddy на том же VPS).
- `shared/exercises.json`, `tools/` — источники и генераторы. `docs/` — план, бэклог, деплой, тексты магазина, Роспатент.

## Сгенерированные файлы (руками не править — хук заблокирует)

- `app/lib/game/exercise_data.dart`, `server/src/game/exercise-data.ts` ← `shared/exercises.json`, `py -I tools/gen_exercises.py`
- `server/src/legal/privacy-text.ts`, `docs/PRIVACY.md` ← `app/lib/legal/privacy_policy.dart`, из `app/`: `dart run tool/gen_privacy.dart`
- `server/src/generated/**` ← `server/prisma/schema.prisma`, `npx prisma generate`

## Правила

- Главные вкладки (`/`, `/duels`, `/rating`) помещаются на экран без прокрутки; `app/test/ui_layout_test.dart` это проверяет.
- Анализ и тяжёлые расчёты — на телефоне; сервер хранит только нужное и сводки (масштаб, 152-ФЗ).
- Пульс — только с отдельного согласия на данные о здоровье.
- Одна версия у телефона и часов — `version:` в `app/pubspec.yaml`; часы: versionCode = 1 000 000 + build.
- Изменил тексты политики — обнови дату `privacyPolicyUpdated` и перегенерируй копии.
- Коммиты маленькие, push в `origin` (github ZiFlux/ironrise, ветка master).

## Сборки и выкладка

- DEV: debug-сборка `com.ironrise.ironrise.dev` против локального сервера (`docker compose up -d --build api` в `server/`, `adb reverse`).
- Бета: `/beta` (release APK в папку «IronRise — управление» на рабочем столе + установка на телефон).
- Сервер и сайт: `/deploy` (`server/deploy/push.ps1`, запускать из `server/`).

## Окружение и грабли

- Python — `py` (не `python`); свои скрипты класть во временную папку и запускать `py -I script.py`.
- В heredoc и Python-строках обратные слэши ломаются — пути писать через `/` или править через Edit.
- Git Bash превращает аргументы вида `/onboarding` в пути: `MSYS_NO_PATHCONV=1`.
- `dart format` запускается хуком после каждой правки .dart — перед повторной правкой перечитай файл.
- adb: `$LOCALAPPDATA/Android/Sdk/platform-tools/adb.exe`. gh: `C:\Program Files\GitHub CLI\gh.exe`.
- npm медленный; TypeScript закреплён на 6.
