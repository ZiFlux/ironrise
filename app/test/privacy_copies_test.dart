import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/gen_privacy.dart';

String _read(String path) => File(path).readAsStringSync().replaceAll('\r\n', '\n');

void main() {
  test('копии политики совпадают с текстом приложения', () {
    const hint = 'запустите в папке app: dart run tool/gen_privacy.dart';
    expect(_read(markdownPath), privacyMarkdown(), reason: hint);
    expect(_read(typeScriptPath), privacyTypeScript(), reason: hint);
  });
}
