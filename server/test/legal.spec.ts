import { renderPolicyHtml } from '../src/legal/privacy-page';
import { PRIVACY_POLICY } from '../src/legal/privacy-text';

describe('страница политики конфиденциальности', () => {
  const html = renderPolicyHtml();

  it('все разделы на месте, пункты — списком', () => {
    expect(PRIVACY_POLICY.length).toBeGreaterThan(5);
    for (const s of PRIVACY_POLICY) expect(html).toContain(`<h2>${s.title}</h2>`);
    expect(html).toContain('<ul>');
    expect(html).toContain('<li>Аккаунт: e-mail и пароль');
  });

  it('оператор назван, данные о здоровье и Роскомнадзор упомянуты', () => {
    expect(html).toContain('Шатов Юрий');
    expect(html).toContain('ст. 10');
    expect(html).toContain('Роскомнадзор');
  });

  it('спецсимволы экранируются', () => {
    expect(html).not.toMatch(/<(?!\/?(html|head|meta|title|style|body|main|h1|h2|p|ul|li)\b|!doctype)/);
  });
});
