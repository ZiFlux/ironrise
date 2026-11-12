import { PRIVACY_POLICY, PRIVACY_POLICY_UPDATED } from './privacy-text';

const escape = (s: string) =>
  s.replace(/&/g, '&amp;').replace(/</g, '&lt;').replace(/>/g, '&gt;').replace(/"/g, '&quot;');

/** Абзацы и строки-пункты «• …» из текста приложения — в простую страницу. */
const body = (text: string) =>
  text
    .split('\n')
    .map((line) => (line.startsWith('• ') ? `<li>${escape(line.slice(2))}</li>` : `<p>${escape(line)}</p>`))
    .join('\n')
    .replace(/(?:<li>.*<\/li>\n?)+/g, (items) => `<ul>\n${items}</ul>\n`);

export const renderPolicyHtml = (): string => `<!doctype html>
<html lang="ru">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>IronRise — политика конфиденциальности</title>
<style>
  body { margin: 0; background: #141415; color: #ededed; font: 16px/1.6 system-ui, -apple-system, "Segoe UI", Roboto, sans-serif; }
  main { max-width: 720px; margin: 0 auto; padding: 32px 16px 64px; }
  h1 { font-size: 26px; font-weight: 500; margin: 0 0 4px; }
  h2 { font-size: 18px; font-weight: 500; margin: 32px 0 8px; }
  .muted { color: #85858b; font-size: 14px; }
  p, li { color: #c8c8cc; margin: 0 0 8px; }
  ul { padding-left: 20px; margin: 0 0 8px; }
</style>
</head>
<body>
<main>
<h1>IronRise — политика конфиденциальности</h1>
<p class="muted">Обновлено ${escape(PRIVACY_POLICY_UPDATED)}</p>
${PRIVACY_POLICY.map((s) => `<h2>${escape(s.title)}</h2>\n${body(s.body)}`).join('\n')}
</main>
</body>
</html>
`;
