/**
 * Цены косметики. Совпадают с app/lib/game/shop.dart; клиент показывает цены,
 * но списывает монеты только сервер по этой таблице. 0 — есть у всех с начала.
 */
export const SHOP_PRICES: Readonly<Record<string, number>> = {
  hair_short: 0, hair_buzz: 40, hair_curly: 60, hair_manbun: 80,
  hair_bob: 0, hair_ponytail: 40, hair_bun: 60, hair_long: 80,
  hc_black: 0, hc_brown: 30, hc_blond: 30, hc_red: 40, hc_platinum: 60, hc_pink: 70, hc_blue: 70,
  top_none: 0, top_bra: 0, top_tank: 50, top_tee: 40,
  tc_graphite: 0, tc_white: 30, tc_lime: 40, tc_ember: 40, tc_ice: 40, tc_navy: 40, tc_red: 40,
  bottom_shorts: 0, bottom_joggers: 50, bottom_leggings: 50,
  bc_graphite: 0, bc_navy: 30, bc_olive: 30, bc_grey: 30, bc_black: 30,
  sneakers_none: 0, sn_white: 40, sn_black: 40, sn_lime: 70, sn_red: 70, sn_blue: 70,
  acc_headband: 50, acc_wristbands: 50, acc_belt: 90, acc_knee_sleeves: 70, acc_cap: 80,
  acc_glasses: 60, acc_headphones: 100,
  skin_iron: 0, skin_light: 0, skin_tan: 0, skin_brown: 0, skin_dark: 0,
  // Премиум: купить можно только с подпиской, носить — всегда, раз куплено.
  tc_gold: 120, sn_gold: 120, acc_gold_chain: 150,
};

/** Вещи только для премиума — без подписки не продаются. */
export const PREMIUM_ITEMS: ReadonlySet<string> = new Set(['tc_gold', 'sn_gold', 'acc_gold_chain']);

/**
 * Эксклюзивы бета-тестеров: не продаются, выдаются аккаунту навсегда
 * (src/admin/grant-tester.ts и миграция beta_testers).
 */
export const TESTER_ITEMS: readonly string[] = ['acc_beta_cap', 'tc_beta', 'sn_beta'];

/** Вещи, которых нет в продаже: носить можно только выданные. */
export const EXCLUSIVE_ITEMS: ReadonlySet<string> = new Set(TESTER_ITEMS);

export const priceOf = (itemId: string): number | undefined => SHOP_PRICES[itemId];
