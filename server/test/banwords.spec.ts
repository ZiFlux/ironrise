import { readFileSync } from 'fs';
import { join } from 'path';
import { isOffensiveNickname } from '../src/game/nickname';

const cases = JSON.parse(readFileSync(join(__dirname, '../../shared/banwords.json'), 'utf8')).tests as {
  bad: string[];
  ok: string[];
};

describe('фильтр ников (shared/banwords.json → tests)', () => {
  it.each(cases.bad)('запрещён: %s', (n) => expect(isOffensiveNickname(n)).toBe(true));
  it.each(cases.ok)('разрешён: %s', (n) => expect(isOffensiveNickname(n)).toBe(false));
});
