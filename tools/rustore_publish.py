"""Публикация новой версии в RuStore через Public API.

    py -I tools/rustore_publish.py <apk> --whats-new <файл.txt> [--submit]

Ключ — C:/Users/<you>/.ironrise/rustore.json: {"keyId": "...", "key": "<закрытый ключ>"}
(оба значения — из консоли RuStore: «Компания → API RuStore → Создать ключ»).
Без --submit скрипт создаёт черновик и загружает APK, но на модерацию не отправляет —
черновик можно проверить в консоли и отправить там. Подпись: SHA512withRSA от keyId+timestamp,
Base64 (через openssl). Документация: rustore.ru/help/work-with-rustore-api.
"""
import argparse
import base64
import datetime
import json
import os
import subprocess
import sys
import tempfile
import urllib.request

BASE = 'https://public-api.rustore.ru/public'
PACKAGE = 'com.ironrise.ironrise'


def load_key():
    path = os.path.join(os.path.expanduser('~'), '.ironrise', 'rustore.json')
    with open(path, encoding='utf-8') as f:
        data = json.load(f)
    key_id = data.get('keyId') or data.get('key_id')
    key = data.get('key') or data.get('privateKey')
    if not key_id or not key:
        sys.exit('В rustore.json нужны "keyId" и "key" (закрытый ключ) — оба из консоли RuStore')
    if '-----BEGIN' not in key:
        body = ''.join(key.split())
        key = '-----BEGIN PRIVATE KEY-----\n' + '\n'.join(
            body[i:i + 64] for i in range(0, len(body), 64)) + '\n-----END PRIVATE KEY-----\n'
    return key_id, key


def sign(key_pem, message):
    with tempfile.TemporaryDirectory() as tmp:
        key_path = os.path.join(tmp, 'k.pem')
        with open(key_path, 'w', encoding='ascii') as f:
            f.write(key_pem)
        raw = subprocess.run(['openssl', 'dgst', '-sha512', '-sign', key_path],
                             input=message.encode('utf-8'), capture_output=True, check=True).stdout
    return base64.b64encode(raw).decode('ascii')


def call(method, path, token=None, body=None):
    data = None if body is None else json.dumps(body, ensure_ascii=False).encode('utf-8')
    req = urllib.request.Request(BASE + path, data=data, method=method)
    req.add_header('Content-Type', 'application/json')
    if token:
        req.add_header('Public-Token', token)
    try:
        with urllib.request.urlopen(req, timeout=60) as r:
            out = json.loads(r.read().decode('utf-8') or '{}')
    except urllib.error.HTTPError as e:
        sys.exit(f'{method} {path}: HTTP {e.code} {e.read().decode("utf-8", "replace")[:500]}')
    if out.get('code') != 'OK':
        sys.exit(f'{method} {path}: {out}')
    return out.get('body')


def token():
    key_id, key = load_key()
    ts = datetime.datetime.now().astimezone().isoformat(timespec='milliseconds')
    body = call('POST', '/auth/', body={'keyId': key_id, 'timestamp': ts, 'signature': sign(key, key_id + ts)})
    return body['jwe']


def upload_apk(tok, version_id, apk):
    # Multipart — через curl, как в плагине fastlane для RuStore.
    url = f'{BASE}/v1/application/{PACKAGE}/version/{version_id}/apk?isMainApk=true&servicesType=Unknown'
    r = subprocess.run(['curl', '-s', '-X', 'POST', url, '-H', f'Public-Token: {tok}',
                        '-F', f'file=@{apk}'],
                       capture_output=True, check=True)
    out = json.loads(r.stdout.decode('utf-8') or '{}')
    if out.get('code') != 'OK':
        sys.exit(f'Загрузка APK: {out}')


def main():
    p = argparse.ArgumentParser()
    p.add_argument('apk')
    p.add_argument('--whats-new', required=True, help='файл с текстом «Что нового» (до 5000 знаков)')
    p.add_argument('--submit', action='store_true', help='сразу отправить на модерацию')
    a = p.parse_args()
    with open(a.whats_new, encoding='utf-8') as f:
        whats_new = f.read().strip()[:5000]
    tok = token()
    version_id = call('POST', f'/v1/application/{PACKAGE}/version', tok, {'whatsNew': whats_new})
    print('Черновик:', version_id)
    upload_apk(tok, version_id, a.apk)
    print('APK загружен')
    if a.submit:
        call('POST', f'/v1/application/{PACKAGE}/version/{version_id}/submit', tok)
        print('Отправлено на модерацию')
    else:
        print('На модерацию не отправлено (--submit) — проверьте черновик в консоли RuStore')


if __name__ == '__main__':
    main()
