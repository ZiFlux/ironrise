// PreToolUse (Edit|Write): запрещает ручную правку сгенерированных файлов.
let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let path = '';
  try {
    path = (JSON.parse(raw).tool_input?.file_path ?? '').split(String.fromCharCode(92)).join('/');
  } catch {
    process.exit(0);
  }
  const rules = [
    [/app\/lib\/game\/exercise_data\.dart$|server\/src\/game\/exercise-data\.ts$/,
      'Сгенерированный файл. Правьте shared/exercises.json и запустите py -I tools/gen_exercises.py.'],
    [/app\/lib\/game\/banwords_data\.dart$|server\/src\/game\/banwords-data\.ts$/,
      'Сгенерированный файл. Правьте shared/banwords.json и запустите py -I tools/gen_banwords.py.'],
    [/server\/src\/legal\/privacy-text\.ts$|docs\/PRIVACY\.md$/,
      'Сгенерированный файл. Правьте app/lib/legal/privacy_policy.dart и запустите (из app/) dart run tool/gen_privacy.dart.'],
    [/server\/src\/generated\//,
      'Код Prisma. Правьте server/prisma/schema.prisma и запустите npx prisma generate.'],
  ];
  for (const [re, reason] of rules) {
    if (re.test(path)) {
      process.stdout.write(JSON.stringify({
        hookSpecificOutput: {
          hookEventName: 'PreToolUse',
          permissionDecision: 'deny',
          permissionDecisionReason: reason,
        },
      }));
      return;
    }
  }
});
