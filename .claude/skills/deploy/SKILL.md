---
name: deploy
description: Выкатить сервер IronRise и сайт ironrise.ru на VPS (api.ironrise.ru).
disable-model-invocation: true
---

# Деплой сервера и сайта

1. Убедиться, что рабочее дерево закоммичено, и прогнать тесты сервера: из `server/` — `npm test`.
   Если менялось приложение — ещё `flutter test` из `app/`. Красные тесты — не выкатывать.
2. Из папки `server/` (не из `server/deploy`!) в PowerShell:

   ```powershell
   .\deploy\push.ps1 -Server root@152.228.97.232 -Domain api.ironrise.ru
   ```

   Скрипт копирует код и `site/`, собирает контейнеры, применяет миграции и перезагружает Caddy.
3. Проверить:
   - `curl https://api.ironrise.ru/health` → `{"status":"ok"}`;
   - `curl -sI https://ironrise.ru` → 200;
   - если менялись эндпоинты — дернуть один новый без токена (ожидаем 401, не 404).
4. Коротко отчитаться: что выкатилось, какие миграции, результат проверок. Ошибку — с выводом.

Не читать продовую базу и данные бета-тестеров без явной просьбы пользователя.
