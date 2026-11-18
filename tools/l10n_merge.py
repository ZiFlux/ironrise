"""Добавить переводы в app/lib/l10n/<lang>.dart из двух файлов по строке:
ключи (русский) и переводы в том же порядке.

    cd app && py -I ../tools/l10n_merge.py keys.txt values.txt [en]

Ключи без перевода выводит tools/l10n_keys.py.
"""

import re
import sys


def lit(t):
    return "'" + t.replace('\\', '\\\\').replace("'", "\\'").replace('$', '\\$') + "'"


def unlit(t):
    return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t'}.get(m.group(1), m.group(1)), t)


def main(keys_path, vals_path, lang='en'):
    keys = open(keys_path, encoding='utf-8').read().rstrip('\n').split('\n')
    vals = open(vals_path, encoding='utf-8').read().rstrip('\n').split('\n')
    assert len(keys) == len(vals), (len(keys), len(vals))
    path = f'lib/l10n/{lang}.dart'
    src = open(path, encoding='utf-8').read()
    have = {unlit(m.group(1)) for m in re.finditer(r"^\s*'((?:[^'\\]|\\.)*)':", src, re.M)}
    # Ключи из l10n_keys.py — как в исходнике (с \' и т.п.); в словаре — разобранные.
    body = ''.join(f'  {lit(unlit(k))}: {lit(v)},\n'
                   for k, v in zip(keys, vals) if unlit(k) not in have)
    end = src.rindex('};')
    src = src[:end] + body + src[end:]
    src = src.replace('<String, String>{};', '<String, String>{\n};')
    open(path, 'w', encoding='utf-8').write(src)
    print('добавлено:', body.count('\n'))


if __name__ == '__main__':
    main(*sys.argv[1:])
