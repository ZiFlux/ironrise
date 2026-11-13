import { unpaidItems } from './looks';
import { COSTUME_ITEMS, PREMIUM_ITEMS, SHOP_PRICES } from './shop';

/**
 * Стартовый образ: первые 14 дней (Profile.startLookUntil) игрок бесплатно собирает «себя» — телосложение,
 * причёску, одежду. Потом образ фиксируется как точка «Старт» на экране прогресса,
 * а надетые вещи остаются за ним. Совпадает с app/lib/game/start_look.dart.
 */
/** Что можно надеть бесплатно, пока открыт редактор: одежда и причёски без аксессуаров и премиума. */
export const CREATOR_ITEMS: ReadonlySet<string> = new Set(
  Object.keys(SHOP_PRICES).filter((id) => !id.startsWith('acc_') && !PREMIUM_ITEMS.has(id) && !COSTUME_ITEMS.has(id)),
);

export const creatorOpen = (p: { startLockedAt: Date | null; startLookUntil: Date }, now = new Date()) =>
  p.startLockedAt === null && now < p.startLookUntil;

/** Вещи редактора, которые выдаются навсегда при фиксации образа. */
export const creatorItemsToGrant = (look: Record<string, unknown>, owned: ReadonlySet<string>): string[] =>
  (unpaidItems(look, owned) ?? []).filter((id) => CREATOR_ITEMS.has(id));
