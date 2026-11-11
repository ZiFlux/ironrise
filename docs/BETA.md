# Бета IronRise: сервер с компьютера, APK для друзей, пуши

Сервер беты работает в Docker на компьютере разработчика и виден из интернета через
быстрый туннель Cloudflare (`https://….trycloudflare.com`). Это бесплатно и подходит
для первых тестеров. Минусы: пока компьютер выключен, бета недоступна, а адрес туннеля
меняется при каждом его перезапуске. Переезд на VPS — та же `compose.beta.yml`.

## 1. Запуск и остановка

Один раз: скопировать `server/.env.beta.example` в `server/.env.beta` и вписать случайные
`DB_PASSWORD` и `JWT_SECRET` (команда для генерации — в самом файле).

Из папки `server`:

```powershell
# запустить (или обновить после изменений в коде)
docker compose -f compose.beta.yml -p ironrise-beta --env-file .env.beta up -d --build

# адрес для друзей
docker compose -p ironrise-beta logs tunnel | findstr trycloudflare

# проверить: должно ответить {"status":"ok"}
curl https://<адрес>/health

# остановить (данные сохраняются в томе ironrise-beta_pgdata)
docker compose -p ironrise-beta stop
```

Контейнеры перезапускаются сами вместе с Docker Desktop. Чтобы бета поднималась
после перезагрузки компьютера, включите в Docker Desktop
«Start Docker Desktop when you sign in».

База беты отдельная от базы разработки (`docker compose up -d` без `-f`), данные не смешиваются.

## 2. Если адрес туннеля сменился

Адрес меняется, когда перезапускается контейнер `tunnel` (перезагрузка компьютера,
перезапуск Docker). Новый адрес берётся командой из раздела 1 и рассылается друзьям.
В приложении: **Профиль → Аккаунт и синхронизация → «Сервер: …» → вставить адрес**.
Вход в аккаунт при этом сохраняется. Постоянный адрес даёт именованный туннель
Cloudflare (нужен свой домен) или VPS.

## 3. Пуши через Firebase (один раз, ~10 минут)

Без этого шага приложение работает, просто без уведомлений.

1. [console.firebase.google.com](https://console.firebase.google.com) → **Add project** →
   имя `IronRise`, Google Analytics можно выключить.
2. В проекте: **Add app → Android**, package name `com.ironrise.ironrise` → Register →
   скачать `google-services.json`. В проект его класть **не нужно**.
3. Из `google-services.json` заполнить `app/firebase.json` по образцу
   `app/firebase.example.json`:

   | Ключ в firebase.json | Поле в google-services.json |
   |---|---|
   | `FIREBASE_API_KEY` | `client[0].api_key[0].current_key` |
   | `FIREBASE_APP_ID` | `client[0].client_info.mobilesdk_app_id` |
   | `FIREBASE_SENDER_ID` | `project_info.project_number` |
   | `FIREBASE_PROJECT_ID` | `project_info.project_id` |

4. Ключ для сервера: **Project settings → Service accounts → Generate new private key**.
   Сохранить файл как `server/secrets/firebase.json` (папка в git не попадает).
5. В `server/.env.beta`: `FIREBASE_SERVICE_ACCOUNT=/app/secrets/firebase.json`,
   затем перезапустить API командой из раздела 1.
   Это не другая папка: `/app/secrets` — так файл из шага 4 (`server/secrets/firebase.json`)
   виден серверу **внутри Docker-контейнера**. Папку `app\secrets` создавать не нужно,
   а ключ в папке Flutter-приложения `app\` держать нельзя. В логах API появится
   «Пуши включены, проект …».

Какие пуши приходят: заявка в друзья, заявка принята, на тебя напали (победил или ты отбился),
и в 19:00 по времени игрока — «серия под угрозой», если сегодня последний допустимый день отдыха.

## 4. APK для друзей

Из папки `app`:

```powershell
flutter build apk --release --dart-define=API_URL=https://<адрес туннеля> --dart-define-from-file=firebase.json
```

Без пушей — та же команда без `--dart-define-from-file`. Готовый файл:
`app\build\app\outputs\flutter-apk\app-release.apk` — его можно отправить в Telegram.

Другу при установке: разрешить установку из этого источника (Android спросит сам).
Обновление — новый APK поверх старого, данные сохраняются. Сборка пока подписана
ключом разработки этого компьютера: обновления собирать на нём же. Для Google Play
и RuStore понадобится отдельный ключ подписи.

## 5. Что сказать тестерам

1. Установить APK, пройти создание героя.
2. Профиль → Аккаунт и синхронизация → создать аккаунт (если адрес сервера не совпадает
   с присланным — нажать на «Сервер: …» и вставить).
3. Дуэли → иконка с человечком → найти друг друга по нику.
