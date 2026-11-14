// PostToolUse (Edit|Write): dart format для изменённого .dart-файла.
const { execSync } = require('child_process');
let raw = '';
process.stdin.on('data', (c) => (raw += c));
process.stdin.on('end', () => {
  let path = '';
  try {
    const j = JSON.parse(raw);
    path = j.tool_response?.filePath ?? j.tool_input?.file_path ?? '';
  } catch {
    return;
  }
  if (!path.endsWith('.dart')) return;
  try {
    execSync(`dart format "${path}"`, { stdio: 'ignore' });
  } catch {
    // формат не обязателен: ошибка синтаксиса всплывёт в analyze
  }
});
