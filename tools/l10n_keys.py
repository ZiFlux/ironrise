"""Тексты из tr('…') в app/lib без перевода в lib/l10n/<lang>.dart — по строке.

    cd app && py -I ../tools/l10n_keys.py [en] > keys.txt
"""

import os
import re
import sys

CALL = re.compile(r"\btr\(\s*'((?:[^'\\]|\\.)*)'")


def unlit(t):
    return re.sub(r'\\(.)', lambda m: {'n': '\n', 't': '\t'}.get(m.group(1), m.group(1)), t)


def main(lang='en'):
    src = open(f'lib/l10n/{lang}.dart', encoding='utf-8').read()
    have = {unlit(m.group(1)) for m in re.finditer(r"^\s*'((?:[^'\\]|\\.)*)':", src, re.M)}
    seen = []
    for root, _, files in os.walk('lib'):
        if 'l10n' in root:
            continue
        for f in sorted(files):
            if f.endswith('.dart'):
                text = open(os.path.join(root, f), encoding='utf-8').read()
                for m in CALL.finditer(text):
                    k = m.group(1)
                    if unlit(k) not in have and k not in seen:
                        seen.append(k)
    sys.stdout.reconfigure(encoding='utf-8')
    print('\n'.join(seen))


if __name__ == '__main__':
    main(*sys.argv[1:])
