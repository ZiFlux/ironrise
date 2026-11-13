import { GameConfig as C } from './config';

/** Опыт кардио за шаги в день отдыха: 3 за тысячу, не больше 30. Как в app/lib/state/rest_steps.dart. */
export const stepsXp = (steps: number) => Math.min(C.stepsXpCap, Math.floor(steps / 1000) * C.stepsXpPerThousand);
