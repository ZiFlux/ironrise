import { SEASON_ITEMS } from './season';
import { STREAK_ITEMS } from './streak-rewards';
/**
 * Цены косметики (×2,5 с 18.11.2026: магазин скупался за две недели).
 * Совпадают с app/lib/game/shop.dart; клиент показывает цены,
 * но списывает монеты только сервер по этой таблице. 0 — есть у всех с начала.
 */
export const SHOP_PRICES: Readonly<Record<string, number>> = {
  hair_short: 0, hair_buzz: 100, hair_curly: 150, hair_manbun: 200,
  hair_bob: 0, hair_ponytail: 100, hair_bun: 150, hair_long: 200,
  hair_spiky: 175, hair_mane: 225, hair_mullet: 200,
  hc_black: 0, hc_brown: 75, hc_blond: 75, hc_red: 100, hc_platinum: 150, hc_pink: 175, hc_blue: 175,
  hc_white: 175, hc_silver: 150, hc_cherry: 175,
  top_none: 0, top_bra: 0, top_tank: 125, top_tee: 100, top_vneck: 125, top_oversize: 150, top_crop: 125,
  top_uniform: 300, top_open_shirt: 225, top_suit: 350, top_haori: 325,
  tc_graphite: 0, tc_white: 75, tc_cream: 75, tc_sage: 100, tc_lime: 100, tc_ember: 100, tc_ice: 100, tc_navy: 100, tc_red: 100,
  bottom_shorts: 0, bottom_joggers: 125, bottom_leggings: 125, bottom_wide_shorts: 150, bottom_harem: 200, bottom_cargo: 175,
  bottom_trousers: 150, bottom_hakama: 250, bottom_cuffed_shorts: 175,
  bc_graphite: 0, bc_navy: 75, bc_olive: 75, bc_grey: 75, bc_black: 75, bc_white: 75, bc_denim: 100, bc_sand: 75,
  sneakers_none: 0, sh_sneakers: 0, sh_slippers: 150, sh_chunky: 225, sn_white: 100, sn_black: 100, sn_lime: 175, sn_red: 175, sn_blue: 175,
  acc_headband: 125, acc_wristbands: 125, acc_belt: 225, acc_knee_sleeves: 175, acc_cap: 200,
  acc_glasses: 150, acc_headphones: 250, acc_bandana: 150, acc_silver_chain: 225,
  acc_round_shades: 150, acc_blindfold: 175, acc_straw_hat: 250, acc_sash: 175,
  // Костюм клоуна: только покупка, в редакторе старта его нет (COSTUME_ITEMS).
  hair_clown: 300, top_clown: 375, acc_clown_nose: 150,
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
