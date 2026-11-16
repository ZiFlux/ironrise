import { SEASON_ITEMS } from './season';
import { STREAK_ITEMS } from './streak-rewards';
/**
 * Цены косметики. Совпадают с app/lib/game/shop.dart; клиент показывает цены,
 * но списывает монеты только сервер по этой таблице. 0 — есть у всех с начала.
 */
export const SHOP_PRICES: Readonly<Record<string, number>> = {
  hair_short: 0, hair_buzz: 40, hair_curly: 60, hair_manbun: 80,
  hair_bob: 0, hair_ponytail: 40, hair_bun: 60, hair_long: 80,
  hair_spiky: 70, hair_mane: 90, hair_mullet: 80,
  hc_black: 0, hc_brown: 30, hc_blond: 30, hc_red: 40, hc_platinum: 60, hc_pink: 70, hc_blue: 70,
  hc_white: 70, hc_silver: 60, hc_cherry: 70,
  top_none: 0, top_bra: 0, top_tank: 50, top_tee: 40, top_vneck: 50, top_oversize: 60, top_crop: 50,
  tc_graphite: 0, tc_white: 30, tc_cream: 30, tc_sage: 40, tc_lime: 40, tc_ember: 40, tc_ice: 40, tc_navy: 40, tc_red: 40,
  bottom_shorts: 0, bottom_joggers: 50, bottom_leggings: 50, bottom_wide_shorts: 60, bottom_harem: 80, bottom_cargo: 70,
  bc_graphite: 0, bc_navy: 30, bc_olive: 30, bc_grey: 30, bc_black: 30, bc_white: 30, bc_denim: 40, bc_sand: 30,
  sneakers_none: 0, sh_sneakers: 0, sh_slippers: 60, sh_chunky: 90, sn_white: 40, sn_black: 40, sn_lime: 70, sn_red: 70, sn_blue: 70,
  acc_headband: 50, acc_wristbands: 50, acc_belt: 90, acc_knee_sleeves: 70, acc_cap: 80,
  acc_glasses: 60, acc_headphones: 100, acc_bandana: 60, acc_silver_chain: 90,
  // Костюм клоуна: только покупка, в редакторе старта его нет (COSTUME_ITEMS).
  hair_clown: 120, top_clown: 150, acc_clown_nose: 60,
  skin_iron: 0, skin_light: 0, skin_tan: 0, skin_brown: 0, skin_dark: 0,
  // Золотой комплект — бесплатно всем с 16.11 (п. 111; раньше премиум за монеты).
  tc_gold: 0, sn_gold: 0, acc_gold_chain: 0,
};

/**
 * Вещи только для премиума — без подписки не продаются. Пока пусто: стартовый
 * золотой комплект стал бесплатным (п. 111), новые премиум-вещи — сюда.
 */
export const PREMIUM_ITEMS: ReadonlySet<string> = new Set<string>();

/**
 * Эксклюзивы бета-тестеров: не продаются, выдаются аккаунту навсегда
 * (src/admin/grant-tester.ts и миграция beta_testers).
 */
export const TESTER_ITEMS: readonly string[] = [
  'acc_beta_cap', 'tc_beta', 'sn_beta', 'top_beta_tee', 'bottom_beta_joggers',
];

/** Одежда создателя проекта: не продаётся, выдаётся через админку (give). */
export const AUTHOR_ITEMS: readonly string[] = ['top_creator_tee', 'acc_crown'];

/**
 * Вещи за достижения в приложении: гайд по интерфейсу пройден — кроссовки
 * «Первый шаг», часы подключены впервые — аксессуар «Смарт-часы».
 */
export const ACHIEVEMENT_ITEMS = { guide: 'sn_first_step', watch: 'acc_smartwatch' } as const;
export type Achievement = keyof typeof ACHIEVEMENT_ITEMS;

/** Костюмы: продаются, но бесплатно в редакторе стартового образа их не надеть. */
export const COSTUME_ITEMS: ReadonlySet<string> = new Set(['hair_clown', 'top_clown']);

/** Вещи, которых нет в продаже: носить можно только выданные (тестерам, за серию, создателю). */
export const EXCLUSIVE_ITEMS: ReadonlySet<string> = new Set([
  ...TESTER_ITEMS,
  ...STREAK_ITEMS,
  ...AUTHOR_ITEMS,
  ...Object.values(ACHIEVEMENT_ITEMS),
  ...SEASON_ITEMS,
]);

export const priceOf = (itemId: string): number | undefined => SHOP_PRICES[itemId];
