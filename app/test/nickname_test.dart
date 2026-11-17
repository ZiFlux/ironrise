import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/nickname.dart';

void main() {
  test('ключ совпадает с серверным (server/src/game/nickname.ts)', () {
    expect(nicknameKey('Ю_PA Ёж Bob0'), 'юраежвово');
    expect(nicknameKey('Юpa'), nicknameKey('юра'));
  });

  test('проверка ника как на сервере', () {
    expect(nicknameProblem('  genka '), isNull);
    expect(nicknameProblem('Юр'), isNotNull);
    expect(nicknameProblem('Юра!'), isNotNull);
    expect(nicknameProblem('Iron Rise'), isNotNull);
    expect(normalizeNickname('  Юра   Иванов '), 'Юра Иванов');
  });

  group('фильтр ников как на сервере (shared/banwords.json → tests)', () {
    final cases =
        jsonDecode(File('../shared/banwords.json').readAsStringSync())['tests']
            as Map<String, dynamic>;
    for (final n in (cases['bad'] as List).cast<String>()) {
      test('запрещён: $n', () => expect(isOffensiveNickname(n), isTrue));
    }
    for (final n in (cases['ok'] as List).cast<String>()) {
      test('разрешён: $n', () => expect(isOffensiveNickname(n), isFalse));
    }
  });
}
