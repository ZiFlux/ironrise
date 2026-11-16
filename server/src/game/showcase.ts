/**
 * Что можно поставить на витрину профиля (п. 84, безопасность): аватарки-достижения
 * и поза победы открываются только за реальные достижения — как в приложении
 * (app/lib/game/avatar_icons.dart, hero_milestones.dart). Раньше сервер принимал
 * любую аватарку, и статус «100 тренировок» можно было подделать.
 */
export type IconUnlock = { kind: 'heroLevel' | 'streak' | 'workouts'; at: number };

export const ICON_UNLOCKS: Readonly<Record<string, IconUnlock>> = {
  medal: { kind: 'streak', at: 7 },
  volcano: { kind: 'streak', at: 30 },
  rocket: { kind: 'workouts', at: 50 },
  dragon: { kind: 'workouts', at: 100 },
  trophy: { kind: 'heroLevel', at: 10 },
  crown: { kind: 'heroLevel', at: 20 },
};

/** Поза победы — с уровня героя 5 (веха героя). */
export const VICTORY_POSE_LEVEL = 5;

export interface Achieved {
  heroLevel: number;
  streak: number;
  workouts: number;
}

/** null — можно; иначе — что ещё не открыто (текст для ошибки). */
export const showcaseLock = (showcase: { icon: string; pose?: string | null }, a: Achieved): string | null => {
  const unlock = ICON_UNLOCKS[showcase.icon];
  if (unlock && a[unlock.kind] < unlock.at) return `Icon ${showcase.icon} is locked`;
  if (showcase.pose === 'victory' && a.heroLevel < VICTORY_POSE_LEVEL) return 'Victory pose is locked';
  return null;
};
