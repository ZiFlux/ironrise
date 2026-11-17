import { WellbeingSchema } from '../src/wellbeing/wellbeing-schema';

describe('самочувствие после тренировки (п. 81)', () => {
  it('принимает ответ с болью: зона, вид, упражнения из базы', () => {
    const r = WellbeingSchema.safeParse({ feeling: 'pain', zone: 'knee', painKind: 'sharp', exercises: ['lunges'] });
    expect(r.success).toBe(true);
  });

  it('зона и вид боли — только при «болит»; неизвестные значения и упражнения — нет', () => {
    expect(WellbeingSchema.safeParse({ feeling: 'ok', zone: 'knee' }).success).toBe(false);
    expect(WellbeingSchema.safeParse({ feeling: 'pain', zone: 'nose' }).success).toBe(false);
    expect(WellbeingSchema.safeParse({ feeling: 'pain', painKind: 'evil' }).success).toBe(false);
    expect(WellbeingSchema.safeParse({ feeling: 'easy', exercises: ['no_such'] }).success).toBe(false);
    expect(WellbeingSchema.safeParse({ feeling: 'easy', exercises: Array(13).fill('lunges') }).success).toBe(false);
  });
});
