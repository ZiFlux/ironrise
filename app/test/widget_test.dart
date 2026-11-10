import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/progression.dart';
import 'package:ironrise/game/training_format.dart';

Map<BodyPart, int> lv(List<int> l) => {
      for (var i = 0; i < BodyPart.values.length; i++) BodyPart.values[i]: l[i],
    };

void main() {
  test('уровень растёт каждые 100 XP', () {
    expect(Progression.levelFromXp(0), 1);
    expect(Progression.levelFromXp(99), 1);
    expect(Progression.levelFromXp(100), 2);
    expect(Progression.levelFromXp(250), 3);
  });

  test('стартовый герой сбалансирован: P = 60 × 1,05 = 63', () {
    expect(Progression.laggingParts(lv([1, 1, 1, 1, 1, 1])), isEmpty);
    expect(Progression.power(lv([1, 1, 1, 1, 1, 1]), 0), 63);
  });

  test('отстающая часть снижает силу на 10%', () {
    final levels = lv([5, 5, 5, 1, 5, 5]); // ноги отстают
    expect(Progression.laggingParts(levels), [BodyPart.legs]);
    // (10·26 + 2·10) · 0,9 = 252
    expect(Progression.power(levels, 10), 252);
  });

  test('вклад серии ограничен 30 днями', () {
    final l = lv([1, 1, 1, 1, 1, 1]);
    expect(Progression.power(l, 100), Progression.power(l, 30));
  });

  test('опыт за подход: 18 · 0,7 · 1,5 · 1', () {
    expect(Progression.xpForSet(share: 0.7, isLagging: true, validity: 1),
        closeTo(18.9, 1e-9));
  });

  test('допустимый отдых подряд по графику', () {
    expect(maxRestDaysInRow([0, 2, 4]), 2); // Пт → Пн
    expect(maxRestDaysInRow([0, 1, 3, 4]), 2);
    expect(maxRestDaysInRow([0, 1, 2, 3, 4]), 2); // выходные
    expect(maxRestDaysInRow([0, 1, 2]), 4);
  });
}
