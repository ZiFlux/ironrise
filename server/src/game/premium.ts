import { GameConfig as C } from './config';
import { WorkoutSummary } from './workout';

/**
 * Премиум (подписка) и статус бета-тестера. Оплаты пока нет — премиум есть у тестеров;
 * когда подключим RevenueCat / RuStore, будет заполняться premiumUntil.
 */
export interface PremiumStatus {
  active: boolean;
  /** tester — выдан тестерам навсегда; subscription — оплачен до until. */
  source: 'tester' | 'subscription' | null;
  until: Date | null;
  isTester: boolean;
}

export const premiumStatus = (p: { isTester: boolean; premiumUntil: Date | null }, now = new Date()): PremiumStatus => {
  if (p.isTester) return { active: true, source: 'tester', until: null, isTester: true };
  if (p.premiumUntil && p.premiumUntil > now) {
    return { active: true, source: 'subscription', until: p.premiumUntil, isTester: false };
  }
  return { active: false, source: null, until: null, isTester: false };
};

/** Премиум: +25% монет за тренировку. Опыт не меняется — сила не покупается. */
export const withPremiumCoins = <T extends WorkoutSummary>(summary: T, premium: boolean): T =>
  premium ? { ...summary, coins: Math.round(summary.coins * (1 + C.premiumCoinBonus)) } : summary;

/**
 * Достоверность тренировки без часов. Обычно 0,5 (ТЗ 4.4); у тестеров штрафа нет:
 * они проверяют приложение и часто тренируются без часов.
 */
export const unverifiedValidityFor = (isTester: boolean): number => (isTester ? 1 : C.unverifiedValidity);
