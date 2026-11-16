import { adminToken, tokenMatches } from '../src/admin/admin-token';

describe('ключ веб-админки', () => {
  const key = 'k'.repeat(32);

  it('без ключа или с коротким ключом веб-админки нет', () => {
    expect(adminToken(undefined)).toBeNull();
    expect(adminToken('')).toBeNull();
    expect(adminToken('short')).toBeNull();
    expect(adminToken(key)).toBe(key);
  });

  it('пускает только с точным ключом', () => {
    expect(tokenMatches(key, key)).toBe(true);
    expect(tokenMatches(key, key + 'x')).toBe(false);
    expect(tokenMatches(key, '')).toBe(false);
    expect(tokenMatches(key, undefined)).toBe(false);
    expect(tokenMatches(null, key)).toBe(false);
  });
});
