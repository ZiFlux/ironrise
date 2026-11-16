import { connect, TLSSocket } from 'node:tls';

/**
 * Письма админу (логи античита, п. 113) — SMTP поверх TLS (порт 465), без внешних
 * библиотек. Настройки — в окружении: SMTP_HOST, SMTP_PORT (465), SMTP_USER,
 * SMTP_PASS (пароль приложения почтового ящика), SMTP_FROM (по умолчанию SMTP_USER).
 * Не настроено — письма не шлём (молча).
 */
export interface SmtpConfig {
  host: string;
  port: number;
  user: string;
  pass: string;
  from: string;
}

export const smtpConfig = (env = process.env): SmtpConfig | null => {
  const { SMTP_HOST, SMTP_USER, SMTP_PASS } = env;
  if (!SMTP_HOST || !SMTP_USER || !SMTP_PASS) return null;
  return {
    host: SMTP_HOST,
    port: Number(env.SMTP_PORT || 465),
    user: SMTP_USER,
    pass: SMTP_PASS,
    from: env.SMTP_FROM || SMTP_USER,
  };
};

const b64 = (s: string) => Buffer.from(s, 'utf-8').toString('base64');

/** Письмо в UTF-8: тема и тело в base64, строки тела по 76 знаков. */
export const buildMessage = (from: string, to: string, subject: string, text: string, now = new Date()): string => {
  const body = b64(text).replace(/.{1,76}/g, (line) => `${line}\r\n`);
  return [
    `From: IronRise <${from}>`,
    `To: <${to}>`,
    `Subject: =?UTF-8?B?${b64(subject)}?=`,
    `Date: ${now.toUTCString()}`,
    'MIME-Version: 1.0',
    'Content-Type: text/plain; charset=utf-8',
    'Content-Transfer-Encoding: base64',
    '',
    body,
  ].join('\r\n');
};

/** Код ответа SMTP, когда ответ закончен (последняя строка «250 …», а не «250-…»). */
export const smtpReplyCode = (buffer: string): number | null => {
  const lines = buffer.split('\r\n').filter(Boolean);
  const last = lines[lines.length - 1];
  return last && /^\d{3} /.test(last) ? Number(last.slice(0, 3)) : null;
};

export async function sendMail(cfg: SmtpConfig, to: string, subject: string, text: string): Promise<void> {
  const socket: TLSSocket = connect({ host: cfg.host, port: cfg.port, servername: cfg.host });
  socket.setEncoding('utf-8');
  socket.setTimeout(20_000, () => socket.destroy(new Error('SMTP timeout')));
  let buffer = '';
  let waiter: ((code: number) => void) | null = null;
  let failed: ((e: Error) => void) | null = null;
  socket.on('data', (chunk: string) => {
    buffer += chunk;
    const code = smtpReplyCode(buffer);
    if (code !== null && waiter) {
      const w = waiter;
      waiter = null;
      buffer = '';
      w(code);
    }
  });
  socket.on('error', (e) => failed?.(e));
  const reply = () =>
    new Promise<number>((resolve, reject) => {
      waiter = resolve;
      failed = reject;
    });
  const step = async (line: string | null, expect: number) => {
    const wait = reply();
    if (line !== null) socket.write(`${line}\r\n`);
    const code = await wait;
    if (code !== expect) throw new Error(`SMTP ${line?.split(' ')[0] ?? 'greeting'}: ${code}`);
  };
  try {
    await step(null, 220);
    await step('EHLO ironrise', 250);
    await step('AUTH LOGIN', 334);
    await step(b64(cfg.user), 334);
    await step(b64(cfg.pass), 235);
    await step(`MAIL FROM:<${cfg.from}>`, 250);
    await step(`RCPT TO:<${to}>`, 250);
    await step('DATA', 354);
    await step(`${buildMessage(cfg.from, to, subject, text)}\r\n.`, 250);
    socket.write('QUIT\r\n');
  } finally {
    socket.end();
  }
}
