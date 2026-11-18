import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/l10n/en.dart';
import 'package:ironrise/l10n/tr.dart';

/// Все тексты в tr('…') из lib/. Ключ — как его видит Dart после разбора
/// литерала: \' → ', \\ → \, \n → перевод строки.
Set<String> trKeys() {
  final call = RegExp(r"\btr\(\s*'((?:[^'\\]|\\.)*)'");
  final keys = <String>{};
  for (final f in Directory('lib').listSync(recursive: true)) {
    if (f is! File || !f.path.endsWith('.dart')) continue;
    if (f.path.contains('l10n')) continue;
    for (final m in call.allMatches(f.readAsStringSync())) {
      keys.add(
        m
            .group(1)!
            .replaceAllMapped(
              RegExp(r'\\(.)'),
              (e) => switch (e.group(1)) {
                'n' => '\n',
                't' => '\t',
                final c => c!,
              },
            ),
      );
    }
  }
  return keys;
}

void main() {
  test('у каждого tr() есть английский перевод', () {
    final missing = trKeys().where((k) => !en.containsKey(k)).toList()..sort();
    expect(missing, isEmpty, reason: 'Нет перевода: ${missing.join(' | ')}');
  });

  test('в переводе те же подстановки {имя}, что в оригинале', () {
    final ph = RegExp(r'\{\w+\}');
    for (final MapEntry(:key, :value) in en.entries) {
      final a = ph.allMatches(key).map((m) => m[0]).toSet();
      final b = ph.allMatches(value).map((m) => m[0]).toSet();
      expect(b, a, reason: key);
    }
  });

  test('язык системы: русский для ru/uk/kk, иначе английский', () {
    expect(languageForSystem('ru'), AppLanguage.ru);
    expect(languageForSystem('uk'), AppLanguage.ru);
    expect(languageForSystem('kk'), AppLanguage.ru);
    expect(languageForSystem('en'), AppLanguage.en);
    expect(languageForSystem('de'), AppLanguage.en);
  });

  test('подстановки и множественное число', () {
    expect(tr('Осталось {n} дн.', {'n': 3}), 'Осталось 3 дн.');
    expect(trPlural(1, 'день', 'дня', 'дней', 'day', 'days'), '1 день');
    expect(trPlural(3, 'день', 'дня', 'дней', 'day', 'days'), '3 дня');
    expect(trPlural(11, 'день', 'дня', 'дней', 'day', 'days'), '11 дней');
  });
}
