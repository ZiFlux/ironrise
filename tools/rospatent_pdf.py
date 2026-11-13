"""Материалы для регистрации программы для ЭВМ в Роспатенте (docs/rospatent).

1. Листинг исходного текста: первые и последние 25 листов полного листинга
   (правило депонирования: если листов больше 50, подаются первые и последние 25).
2. Аудиовизуальные отображения: скриншоты экранов приложения.

Нужен PyMuPDF (pip install pymupdf). Скриншоты рендерятся тестом заранее
(app/test/rospatent_screens_test.dart, см. docs/rospatent/README.md). Запуск из корня репозитория:
    python -I tools/rospatent_pdf.py
"""
import glob
import os
import textwrap

import pymupdf

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, 'docs', 'rospatent')
TITLE = 'IronRise — фитнес-приложение с игровой прогрессией аватара и проверкой тренировок по пульсу'
MONO = r'C:\Windows\Fonts\consola.ttf'
SANS = os.path.join(ROOT, 'app', 'assets', 'fonts', 'Inter-Regular.ttf')
SANS_BOLD = os.path.join(ROOT, 'app', 'assets', 'fonts', 'Inter-Medium.ttf')

A4 = pymupdf.paper_rect('a4')
MARGIN_L, MARGIN_R, MARGIN_T, MARGIN_B = 56, 40, 56, 48
FONT_SIZE, LINE = 7.6, 9.6
WRAP = 104

# Порядок: общий игровой расчёт (сервер), остальной сервер, приложение, часы.
SOURCES = [
    'server/src/game/*.ts',
    'server/src/hero/*.ts', 'server/src/workouts/*.ts', 'server/src/economy/*.ts',
    'server/src/auth/*.ts', 'server/src/social/*.ts', 'server/src/joint/*.ts',
    'server/src/push/*.ts', 'server/src/logs/*.ts', 'server/src/admin/*.ts',
    'server/src/legal/*.ts', 'server/src/common/*.ts', 'server/src/*.ts',
    'server/prisma/schema.prisma',
    'app/lib/main.dart', 'app/lib/*.dart', 'app/lib/game/*.dart', 'app/lib/avatar/*.dart',
    'app/lib/state/*.dart', 'app/lib/net/*.dart', 'app/lib/legal/*.dart',
    'app/lib/widgets/*.dart', 'app/lib/screens/*.dart',
    'watch/wearos/app/src/main/**/*.kt',
]


def source_files():
    seen, out = set(), []
    for pattern in SOURCES:
        for path in sorted(glob.glob(os.path.join(ROOT, pattern), recursive=True)):
            rel = os.path.relpath(path, ROOT).replace('\\', '/')
            if rel in seen or '/generated/' in rel:
                continue
            seen.add(rel)
            out.append(rel)
    return out


_MONO_FONT = pymupdf.Font(fontfile=MONO)


def _printable(line):
    """Символы, которых нет в моноширинном шрифте (∈, эмодзи), — заменяем на «?»."""
    return ''.join(c if c in ' \t\r\n' or _MONO_FONT.has_glyph(ord(c)) else '?' for c in line)


def listing_lines():
    lines = []
    for rel in source_files():
        lines.append(f'// ===== Файл: {rel} =====')
        with open(os.path.join(ROOT, rel), encoding='utf-8') as f:
            for raw in _printable(f.read().expandtabs(2)).splitlines():
                wrapped = textwrap.wrap(raw, WRAP, drop_whitespace=False, replace_whitespace=False) or ['']
                lines.extend(wrapped)
        lines.append('')
    return lines


def build_listing():
    lines = listing_lines()
    per_page = int((A4.height - MARGIN_T - MARGIN_B) // LINE)
    pages = [lines[i:i + per_page] for i in range(0, len(lines), per_page)]
    total = len(pages)
    keep = list(range(min(25, total))) + [i for i in range(max(25, total - 25), total)]
    doc = pymupdf.open()
    for idx in keep:
        page = doc.new_page(width=A4.width, height=A4.height)
        page.insert_font(fontname='mono', fontfile=MONO)
        page.insert_font(fontname='sans', fontfile=SANS)
        page.insert_text((MARGIN_L, 30), TITLE, fontname='sans', fontsize=7.5, color=(0.35, 0.35, 0.35))
        page.insert_text((MARGIN_L, 40), 'Исходный текст программы (Dart, TypeScript, Kotlin)', fontname='sans',
                         fontsize=7.5, color=(0.35, 0.35, 0.35))
        y = MARGIN_T
        for line in pages[idx]:
            page.insert_text((MARGIN_L, y), line, fontname='mono', fontsize=FONT_SIZE)
            y += LINE
        page.insert_text((A4.width / 2 - 30, A4.height - 24), f'Лист {idx + 1} из {total}', fontname='sans', fontsize=8)
    path = os.path.join(OUT, 'IronRise_листинг.pdf')
    doc.save(path, deflate=True)
    return path, total, len(lines)


SCREENS = [
    ('onboarding', 'Первый запуск: подтверждение возраста и отдельное согласие на данные о пульсе'),
    ('home', 'Главный экран: герой, неделя тренировок, уровни частей тела, тренировка дня'),
    ('workout', 'Тренировка: план дня под уровень подготовки — упражнения, подходы и повторы'),
    ('workout_stats', 'Статистика: нагрузка на мышцы против недельной нормы, анализ и прогноз'),
    ('duels', 'Дуэли и рейтинг: доступны после регистрации (расчёт на сервере)'),
    ('profile', 'Профиль: витрина героя, значки силы и статистика'),
    ('profile_start-look', 'Мой старт: телосложение и образ героя на старте'),
    ('shop', 'Магазин: косметика для героя'),
    ('profile_settings', 'Настройки: график, уровень подготовки, календарь, конфиденциальность'),
]


def build_screens(shots_dir):
    doc = pymupdf.open()
    cell_w = (A4.width - MARGIN_L - MARGIN_R - 24) / 2
    for i in range(0, len(SCREENS), 2):
        page = doc.new_page(width=A4.width, height=A4.height)
        page.insert_font(fontname='sans', fontfile=SANS)
        page.insert_font(fontname='bold', fontfile=SANS_BOLD)
        page.insert_text((MARGIN_L, 36), TITLE, fontname='bold', fontsize=8.5)
        page.insert_text((MARGIN_L, 50), 'Аудиовизуальные отображения, порождаемые программой (смартфон Android)',
                         fontname='sans', fontsize=8, color=(0.35, 0.35, 0.35))
        for j, (name, caption) in enumerate(SCREENS[i:i + 2]):
            x = MARGIN_L + j * (cell_w + 24)
            h = cell_w * 2340 / 1080
            rect = pymupdf.Rect(x, 70, x + cell_w, 70 + h)
            page.insert_image(rect, filename=os.path.join(shots_dir, f'{name}.png'))
            page.draw_rect(rect, color=(0.8, 0.8, 0.8), width=0.5)
            box = pymupdf.Rect(x, rect.y1 + 8, x + cell_w, rect.y1 + 60)
            page.insert_textbox(box, f'Рис. {i + j + 1}. {caption}', fontname='sans', fontsize=8.5)
        page.insert_text((A4.width / 2 - 20, A4.height - 24), f'Лист {i // 2 + 1}', fontname='sans', fontsize=8)
    path = os.path.join(OUT, 'IronRise_экраны.pdf')
    doc.save(path, deflate=True)
    return path


if __name__ == '__main__':
    os.makedirs(OUT, exist_ok=True)
    listing, total, n = build_listing()
    print(f'{listing}: листов в полном листинге {total}, строк {n}')
    print(build_screens(os.path.join(OUT, 'screens')))
