import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/strength.dart';

void main() {
  test(
    'присед по весу тела: 80 кг при весе 80 — любитель не достигнут, новичок',
    () {
      expect(
        StrengthStandards.byOneRepMax('barbell_squat', 80, 80, female: false),
        StrengthLevel.novice,
      );
      expect(
        StrengthStandards.byOneRepMax('barbell_squat', 100, 80, female: false),
        StrengthLevel.amateur,
      );
      expect(
        StrengthStandards.byOneRepMax('barbell_squat', 40, 80, female: false),
        StrengthLevel.start,
      );
    },
  );

  test('для девушек свои нормативы', () {
    expect(
      StrengthStandards.byOneRepMax('bench_press', 30, 60, female: true),
      StrengthLevel.amateur,
    );
    expect(
      StrengthStandards.byOneRepMax('bench_press', 30, 60, female: false),
      StrengthLevel.novice,
    );
  });

  test('без веса тела уровень не считается', () {
    expect(
      StrengthStandards.byOneRepMax('barbell_squat', 100, null, female: false),
      isNull,
    );
  });

  test('отжимания по повторам', () {
    expect(
      StrengthStandards.byReps('push_up', 3, female: false),
      StrengthLevel.start,
    );
    expect(
      StrengthStandards.byReps('push_up', 20, female: false),
      StrengthLevel.amateur,
    );
    expect(
      StrengthStandards.byReps('push_up', 50, female: false),
      StrengthLevel.strong,
    );
  });

  test('общий уровень — средний', () {
    expect(
      StrengthStandards.overall([
        StrengthLevel.novice,
        StrengthLevel.experienced,
      ]),
      StrengthLevel.amateur,
    );
    expect(StrengthStandards.overall(const []), isNull);
  });
}
