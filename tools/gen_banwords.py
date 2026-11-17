"""Фильтр ников: shared/banwords.json -> код приложения и сервера.

Запуск из корня репозитория: py -I tools/gen_banwords.py
"""
import json
import pathlib
import re
import shutil
import subprocess

ROOT = pathlib.Path(__file__).resolve().parent.parent
SRC = ROOT / 'shared' / 'banwords.json'
DART = ROOT / 'app' / 'lib' / 'game' / 'banwords_data.dart'
TS = ROOT / 'server' / 'src' / 'game' / 'banwords-data.ts'

HEADER = 'Сгенерировано tools/gen_banwords.py из shared/banwords.json — руками не править.'
CYR = re.compile(r'^[а-яё]+$')
LAT = re.compile(r'^[a-z]+$')


def squeeze(s):
    return re.sub(r'(.)\1+', r'\1', s)


def roots(section, kind, pattern, min_len):
    out = []
    for raw in section.get(kind, []):
        r = squeeze(raw.lower().replace('ё', 'е'))
        assert pattern.match(r), f'{kind}: «{raw}» — не та азбука или лишние знаки'
        assert len(r) >= min_len, f'{kind}: «{raw}» слишком короткий'
        if r != raw:
            print(f'  {kind}: «{raw}» проверяется как «{r}» (повторы букв схлопываются)')
        if r not in out:
            out.append(r)
    return out


def build(data):
    lists = {}
    for script, pattern in (('cyr', CYR), ('latin', LAT)):
        sec = data[script]
        lists[script] = {
            'anywhere': roots(sec, 'anywhere', pattern, 3),
            'wordStart': roots(sec, 'wordStart', pattern, 2),
            'words': roots(sec, 'words', pattern, 1),
            'allow': roots(sec, 'allow', pattern, 3),
        }
    for k, v in data['translitToCyr'].items():
        assert v, k
    translit = sorted(data['translitToCyr'].items(), key=lambda kv: -len(kv[0]))
    return lists, translit


def ts_str_list(xs):
    return '[' + ', '.join(json.dumps(x, ensure_ascii=False) for x in xs) + ']'


def dart_str_list(xs):
    return '[' + ', '.join("'" + x + "'" for x in xs) + ']'


def ts_map(d):
    return '{ ' + ', '.join(f'{json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}' for k, v in d) + ' }'


def dart_map(d):
    return '{' + ', '.join(f"'{k}': '{v}'" for k, v in d) + '}'


def main():
    data = json.loads(SRC.read_text(encoding='utf-8'))
    lists, translit = build(data)

    ts = [f'// {HEADER}', '']
    ts.append('export const BANWORDS = {')
    for script in ('cyr', 'latin'):
        ts.append(f'  {script}: {{')
        for kind, xs in lists[script].items():
            ts.append(f'    {kind}: {ts_str_list(xs)},')
        ts.append('  },')
    ts.append('};')
    ts.append('')
    ts.append(f"export const LOOKALIKE_TO_CYR: Record<string, string> = {ts_map(data['lookalikeToCyr'].items())};")
    ts.append(f"/** Транслит: длинные сочетания раньше коротких. */")
    ts.append(f'export const TRANSLIT_TO_CYR: ReadonlyArray<[string, string]> = {ts_str_list([])[:-1]}' +
              ', '.join(f'[{json.dumps(k)}, {json.dumps(v, ensure_ascii=False)}]' for k, v in translit) + '];')
    ts.append(f"export const TO_LATIN: Record<string, string> = {ts_map(data['toLatin'].items())};")
    ts.append(f"export const DIACRITICS: Record<string, string> = {ts_map(data['diacritics'].items())};")
    TS.write_text('\n'.join(ts) + '\n', encoding='utf-8')

    dart = [f'// {HEADER}', '// ignore_for_file: lines_longer_than_80_chars', '']
    for script in ('cyr', 'latin'):
        for kind, xs in lists[script].items():
            name = f"ban{script.capitalize()}{kind[0].upper()}{kind[1:]}"
            dart.append(f'const {name} = <String>{dart_str_list(xs)};')
    dart.append('')
    dart.append(f"const banLookalikeToCyr = <String, String>{dart_map(data['lookalikeToCyr'].items())};")
    dart.append('/// Транслит: длинные сочетания раньше коротких.')
    dart.append('const banTranslitToCyr = <(String, String)>[' +
                ', '.join(f"('{k}', '{v}')" for k, v in translit) + '];')
    dart.append(f"const banToLatin = <String, String>{dart_map(data['toLatin'].items())};")
    dart.append(f"const banDiacritics = <String, String>{dart_map(data['diacritics'].items())};")
    DART.write_text('\n'.join(dart) + '\n', encoding='utf-8')
    total = sum(len(xs) for s in lists.values() for xs in s.values())
    print(f'Готово: {total} записей -> {TS.relative_to(ROOT)}, {DART.relative_to(ROOT)}')


if __name__ == '__main__':
    main()
