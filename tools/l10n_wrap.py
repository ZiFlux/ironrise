"""Обернуть русские строки интерфейса в tr() (app/lib/l10n/tr.dart).

    cd app && py -I ../tools/l10n_wrap.py lib/screens/settings_screen.dart [...]

1. Подряд идущие литералы ('а ' 'б') склеиваются в один tr().
2. Подстановки $x и ${expr} становятся {x}/{p1}: tr('Осталось {n} дн.', {'n': n});
   русские строки внутри ${...} тоже оборачиваются.
3. Анализатор жалуется на const — const у выражения снимается, у объявления
   становится final; где константа обязательна (значение по умолчанию, case) —
   tr() откатывается к литералу.
Комментарии, импорты, r'...', '''...''' и строки внутри tr() не трогаются.
"""

import os
import re
import subprocess
import sys

CYR = re.compile('[А-Яа-яЁё]')


def scan_string(s, i):
    """s[i] — открывающая кавычка. Вернуть индекс после закрывающей.
    Внутри ${...} — выражения с вложенными строками."""
    q = s[i]
    if s.startswith(q * 3, i):
        end = s.find(q * 3, i + 3)
        return end + 3 if end >= 0 else len(s)
    j = i + 1
    while j < len(s):
        c = s[j]
        if c == '\\':
            j += 2
        elif c == q:
            return j + 1
        elif c == '$' and s.startswith('${', j):
            j = scan_expr(s, j + 2)
        elif c == '\n':
            return j
        else:
            j += 1
    return j


def scan_expr(s, i):
    """Выражение внутри ${...}: вернуть индекс после закрывающей }."""
    depth = 1
    while i < len(s):
        c = s[i]
        if c in '\'"':
            i = scan_string(s, i)
            continue
        if c == '{':
            depth += 1
        elif c == '}':
            depth -= 1
            if depth == 0:
                return i + 1
        i += 1
    return i


def tokens(s):
    """Строковые литералы верхнего уровня: (начало, конец, raw?) без комментариев."""
    i, out = 0, []
    while i < len(s):
        if s.startswith('//', i):
            i = s.find('\n', i)
            i = len(s) if i < 0 else i
        elif s.startswith('/*', i):
            i = s.find('*/', i)
            i = len(s) if i < 0 else i + 2
        elif s[i] in '\'"':
            raw = i > 0 and s[i - 1] in 'rR' and not (s[i - 2].isalnum() if i > 1 else False)
            j = scan_string(s, i)
            out.append((i - (1 if raw else 0), j, raw))
            i = j
        else:
            i += 1
    return out


def literal_body(lit):
    q = lit[0]
    return lit[1:-1] if not lit.startswith(q * 3) else None


def split_interp(body, transform):
    """Текст литерала → (шаблон с {имя}, [(имя, выражение)])."""
    out, args, names, i = [], [], {}, 0

    def name_for(expr):
        if expr in names:
            return names[expr]
        simple = re.fullmatch(r'[A-Za-z_][\w.]*', expr)
        base = (expr.split('.')[-1] if simple else f'p{len(args) + 1}').lstrip('_') or 'p'
        n, k = base, 2
        while n in [a for a, _ in args]:
            n, k = f'{base}{k}', k + 1
        names[expr] = n
        args.append((n, transform(expr)))
        return n

    while i < len(body):
        c = body[i]
        if c == '\\' and i + 1 < len(body):
            out.append(body[i:i + 2])
            i += 2
        elif body.startswith('${', i):
            j = scan_expr(body, i + 2)
            out.append('{' + name_for(body[i + 2:j - 1].strip()) + '}')
            i = j
        elif c == '$' and i + 1 < len(body) and (body[i + 1].isalpha() or body[i + 1] == '_'):
            m = re.compile(r'[A-Za-z_]\w*').match(body, i + 1)
            out.append('{' + name_for(m.group(0)) + '}')
            i = m.end()
        elif c == "'":
            # Внутри шаблона одинарная кавычка экранируется.
            out.append("\\'")
            i += 1
        else:
            out.append(c)
            i += 1
    return ''.join(out), args


def transform(src, wrapped=None, skip_lines=True):
    """Обернуть русские литералы в src. wrapped — call → оригинал для отката."""
    if wrapped is None:
        wrapped = {}
    toks = tokens(src)
    # Склеить подряд идущие литералы (между ними только пробелы).
    runs, cur = [], None
    for a, b, raw in toks:
        if cur and not cur[2] and not raw and src[cur[1]:a].strip() == '':
            cur = (cur[0], b, False, cur[3] + [(a, b)])
        else:
            if cur:
                runs.append(cur)
            cur = (a, b, raw, [(a, b)])
    if cur:
        runs.append(cur)

    out, last = [], 0
    for a, b, raw, parts in runs:
        text = src[a:b]
        if raw or not CYR.search(text):
            continue
        line_start = src.rfind('\n', 0, a) + 1
        head = src[line_start:a].lstrip()
        if skip_lines and head.startswith(('import ', 'export ', 'part ')):
            continue
        if src[max(0, a - 3):a] == 'tr(':
            continue
        bodies = [literal_body(src[x:y]) for x, y in parts]
        if any(bd is None for bd in bodies):
            continue
        # Тело в двойных кавычках: экранированная \" не нужна в одинарных.
        body = ''.join(bd.replace('\\"', '"') if src[x] == '"' else bd.replace("\\'", "'")
                       for bd, (x, _) in zip(bodies, parts))
        template, args = split_interp(body, lambda e: transform(e, wrapped, False))
        call = "tr('" + template + "'"
        if args:
            call += ', {' + ', '.join(f"'{n}': {e}" for n, e in args) + '}'
        call += ')'
        wrapped[call] = text
        out.append(src[last:a])
        out.append(call)
        last = b
    out.append(src[last:])
    return ''.join(out)


def wrap_file(path):
    src = open(path, encoding='utf-8').read()
    wrapped = {}
    s = transform(src, wrapped)
    if wrapped and 'l10n/tr.dart' not in s:
        rel = os.path.relpath('lib/l10n/tr.dart', os.path.dirname(path)).replace('\\', '/')
        first = re.search(r"^import .*;$", s, re.M)
        imp = f"import '{rel}';\n"
        s = s[:first.start()] + imp + s[first.start():] if first else imp + s
    open(path, 'w', encoding='utf-8').write(s)
    return wrapped


CONST_CODES = {
    'CONST_WITH_NON_CONSTANT_ARGUMENT', 'INVALID_CONSTANT', 'NON_CONSTANT_LIST_ELEMENT',
    'NON_CONSTANT_MAP_VALUE', 'NON_CONSTANT_MAP_KEY', 'NON_CONSTANT_SET_ELEMENT',
    'CONST_INITIALIZED_WITH_NON_CONSTANT_VALUE', 'CONST_EVAL_METHOD_INVOCATION',
    'CONST_EVAL_TYPE_BOOL_NUM_STRING', 'NON_CONSTANT_RECORD_FIELD',
    'CONST_CONSTRUCTOR_PARAM_TYPE_MISMATCH',
}
REVERT_CODES = {
    'NON_CONSTANT_DEFAULT_VALUE', 'NON_CONSTANT_CASE_EXPRESSION',
    'CONSTANT_PATTERN_WITH_NON_CONSTANT_EXPRESSION',
    'NON_CONSTANT_ANNOTATION_CONSTRUCTOR_ARGUMENT',
    'CONST_CONSTRUCTOR_WITH_FIELD_INITIALIZED_BY_NON_CONST',
}


def analyze(paths):
    r = subprocess.run(['dart', 'analyze', '--format=machine', *paths],
                       capture_output=True, text=True, encoding='utf-8', shell=True)
    errs = []
    for line in (r.stdout + r.stderr).splitlines():
        p = line.split('|')
        if len(p) >= 8 and p[0] == 'ERROR':
            errs.append((p[2], os.path.abspath(p[3]), int(p[4]), int(p[5])))
    return errs


def offset(src, line, col):
    return sum(len(l) + 1 for l in src.split('\n')[:line - 1]) + col - 1


def const_before(src, at):
    """Позиция ближайшего const перед at (того, что делает выражение константным)."""
    found = list(re.finditer(r'\bconst\b', src[:at]))
    return found[-1].start() if found else None


def apply_const_fix(src, k, at):
    """У объявления const → final, у выражения — снять."""
    if re.match(r'const(\s+[\w<>?, ]+?)?\s+\w+\s*=', src[k:at]):
        return src[:k] + 'final' + src[k + 5:]
    return src[:k] + src[k + 6:] if src[k + 5] == ' ' else src[:k] + src[k + 5:]


def main(paths):
    paths = [os.path.abspath(p) for p in paths]
    wrapped = {p: wrap_file(p) for p in paths}
    for _ in range(30):
        errs = analyze(paths)
        if not errs:
            break
        changed = False
        by_file = {}
        for code, f, line, col in errs:
            by_file.setdefault(f, []).append((code, line, col))
        for f, items in by_file.items():
            if f not in wrapped:
                continue
            src = open(f, encoding='utf-8').read()
            # Сначала собрать, какие const трогать, на исходном тексте: несколько
            # ошибок внутри одного const-списка — один и тот же const, а не соседние.
            consts, reverts = {}, set()
            for code, line, col in items:
                at = offset(src, line, col)
                if code in CONST_CODES:
                    k = const_before(src, at)
                    if k is not None:
                        consts.setdefault(k, at)
                elif code in REVERT_CODES:
                    reverts.add(line)
            if reverts:
                lines = src.split('\n')
                for line in reverts:
                    for call, orig in wrapped[f].items():
                        lines[line - 1] = lines[line - 1].replace(call, orig)
                new = '\n'.join(lines)
                if new != src:
                    src, changed = new, True
            else:
                for k in sorted(consts, reverse=True):
                    src = apply_const_fix(src, k, consts[k])
                    changed = True
            open(f, 'w', encoding='utf-8').write(src)
        if not changed:
            for e in errs:
                print('  осталось:', e)
            break
    print(f'обёрнуто строк: {sum(len(w) for w in wrapped.values())}')


if __name__ == '__main__':
    main(sys.argv[1:])
