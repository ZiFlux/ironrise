import { SHOP_PRICES } from './shop';

/**
 * Разбор образа (AvatarLook.toJson с клиента) на вещи магазина — чтобы сервер мог
 * проверить, что всё надетое куплено. Значения совпадают с app/lib/game/shop.dart.
 * Цвета — ARGB как 32-битные целые (Color.toARGB32 во Flutter).
 */
const HAIR: Record<string, string> = {
  short: 'hair_short', buzz: 'hair_buzz', curly: 'hair_curly', manBun: 'hair_manbun',
  bob: 'hair_bob', ponytail: 'hair_ponytail', bun: 'hair_bun', long: 'hair_long',
};
const HAIR_COLOR: Record<number, string> = {
  0xff26262a: 'hc_black', 0xff5a3a24: 'hc_brown', 0xffd9b66e: 'hc_blond',
  0xffb4532a: 'hc_red', 0xffe6e2d8: 'hc_platinum',
};
const TOP: Record<string, string> = { none: 'top_none', bra: 'top_bra', tank: 'top_tank', tee: 'top_tee' };
const TOP_COLOR: Record<number, string> = {
  0xff1f1f22: 'tc_graphite', 0xffe8e8e8: 'tc_white', 0xffc6ff3d: 'tc_lime',
  0xffff7a3d: 'tc_ember', 0xff3ddcff: 'tc_ice',
};
const BOTTOM: Record<string, string> = { shorts: 'bottom_shorts', joggers: 'bottom_joggers', leggings: 'bottom_leggings' };
const BOTTOM_COLOR: Record<number, string> = {
  0xff1f1f22: 'bc_graphite', 0xff1e2a4a: 'bc_navy', 0xff4a5230: 'bc_olive', 0xff8a8a90: 'bc_grey',
};
const SNEAKERS: Record<number, string> = {
  0xffededed: 'sn_white', 0xff2a2a2e: 'sn_black', 0xffc6ff3d: 'sn_lime', 0xffe5484d: 'sn_red',
};
const ACCESSORY: Record<string, string> = { headband: 'acc_headband', wristbands: 'acc_wristbands' };
const SKIN: Record<string, string> = {
  iron: 'skin_iron', light: 'skin_light', tan: 'skin_tan', brown: 'skin_brown', dark: 'skin_dark',
};

/** Вещи, из которых состоит образ, или null, если в образе есть то, чего нет в магазине. */
export const wornItems = (look: Record<string, unknown>): string[] | null => {
  const pick = <K extends string | number>(table: Record<K, string>, value: unknown): string | undefined =>
    (typeof value === 'string' || typeof value === 'number') ? table[value as K] : undefined;

  const accessories = look.accessories ?? [];
  if (!Array.isArray(accessories)) return null;
  const sneakers = look.sneakersColor === null || look.sneakersColor === undefined
    ? 'sneakers_none'
    : pick(SNEAKERS, look.sneakersColor);

  const items = [
    pick(SKIN, look.skin),
    pick(HAIR, look.hair),
    pick(HAIR_COLOR, look.hairColor),
    pick(TOP, look.top),
    pick(TOP_COLOR, look.topColor),
    pick(BOTTOM, look.bottom),
    pick(BOTTOM_COLOR, look.bottomColor),
    sneakers,
    ...accessories.map((a) => pick(ACCESSORY, a)),
  ];
  if (look.sex !== 'male' && look.sex !== 'female') return null;
  return items.every((i): i is string => i !== undefined) ? items : null;
};

/** Платные вещи образа, которых нет среди owned. null — образ некорректен. */
export const unpaidItems = (look: Record<string, unknown>, owned: ReadonlySet<string>): string[] | null => {
  const worn = wornItems(look);
  if (worn === null) return null;
  return [...new Set(worn)].filter((id) => (SHOP_PRICES[id] ?? 0) > 0 && !owned.has(id));
};
