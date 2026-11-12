// Копии политики конфиденциальности из lib/legal/privacy_policy.dart:
// docs/PRIVACY.md (для чтения) и server/src/legal/privacy-text.ts (страница
// https://api.ironrise.ru/privacy для Google Play). Запуск из папки app:
//   dart run tool/gen_privacy.dart
// test/privacy_copies_test.dart падает, если копии устарели.
import 'dart:convert';
import 'dart:io';

import 'package:ironrise/legal/privacy_policy.dart';

String privacyMarkdown() {
  final b = StringBuffer(
    '# IronRise — политика конфиденциальности\n\n'
    'Обновлено $privacyPolicyUpdated\n\n'
    '> Копия текста из приложения (`app/lib/legal/privacy_policy.dart`). '
    'Меняйте сначала там и запускайте `dart run tool/gen_privacy.dart`.\n',
  );
  for (final s in privacyPolicy) {
    b.write('\n## ${s.title}\n\n${s.body}\n');
  }
  return b.toString();
}

String privacyTypeScript() {
  final b = StringBuffer(
    '// Сгенерировано из app/lib/legal/privacy_policy.dart: dart run tool/gen_privacy.dart.\n'
    '// Не править вручную.\n'
    'export const PRIVACY_POLICY_UPDATED = ${jsonEncode(privacyPolicyUpdated)};\n\n'
    'export const PRIVACY_POLICY: { title: string; body: string }[] = [\n',
  );
  for (final s in privacyPolicy) {
    b.write('  { title: ${jsonEncode(s.title)}, body: ${jsonEncode(s.body)} },\n');
  }
  b.write('];\n');
  return b.toString();
}

const markdownPath = '../docs/PRIVACY.md';
const typeScriptPath = '../server/src/legal/privacy-text.ts';

void main() {
  File(markdownPath).writeAsStringSync(privacyMarkdown());
  File(typeScriptPath).writeAsStringSync(privacyTypeScript());
  stdout.writeln('Обновлены $markdownPath и $typeScriptPath');
}
