/** Шесть частей тела аватара (ТЗ 3.1). Порядок важен: по нему перебирают части. */
export const BODY_PARTS = ['chest', 'back', 'arms', 'legs', 'core', 'cardio'] as const;

export type BodyPart = (typeof BODY_PARTS)[number];

export type PartMap<T> = Record<BodyPart, T>;

export const partMap = <T>(f: (p: BodyPart) => T): PartMap<T> =>
  Object.fromEntries(BODY_PARTS.map((p) => [p, f(p)])) as PartMap<T>;
