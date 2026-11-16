import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/entry_test.dart';
import 'package:ironrise/game/session_builder.dart';
import 'package:ironrise/state/hero.dart';

// П. 116: уровень по входной тренировке — большинством, при равенстве ниже.
void main() {
  EntryTestResult r({
    int push = 0,
    bool knee = false,
    int squats = 0,
    int crunches = 0,
    int burpees = 0,
    int plank = 0,
    int? pull,
  }) => EntryTestResult(
    at: DateTime(2026, 11, 16),
    pushUps: push,
    kneePushUps: knee,
    squats60: squats,
    crunches60: crunches,
    burpees60: burpees,
    plankSec: plank,
    pullUps: pull,
  );

  test('пороги пользователя: скручивания 55+ и бёрпи 30+ — отлично', () {
    expect(
      levelOfItem(EntryTestItem.crunches60, 55, Sex.male),
      TrainingLevel.advanced,
    );
    expect(
      levelOfItem(EntryTestItem.crunches60, 29, Sex.male),
      TrainingLevel.novice,
    );
    expect(
      levelOfItem(EntryTestItem.burpees60, 30, Sex.male),
      TrainingLevel.advanced,
    );
    expect(
      levelOfItem(EntryTestItem.burpees60, 17, Sex.male),
      TrainingLevel.novice,
    );
  });

  test('крепкий новичок с хорошим кардио — средний', () {
    final level = entryLevel(
      r(push: 15, squats: 30, crunches: 40, burpees: 22, plank: 60),
      Sex.male,
    );
    expect(level, TrainingLevel.intermediate);
  });

  test('при равенстве голосов — уровень ниже', () {
    // 2 опытных, 2 средних, 1 новичок (с колен) → средний, а не опытный.
    final level = entryLevel(
      r(push: 40, knee: true, squats: 45, crunches: 60, burpees: 20, plank: 50),
      Sex.male,
    );
    expect(level, TrainingLevel.intermediate);
  });

  test('женские пороги отжиманий ниже', () {
    expect(
      levelOfItem(EntryTestItem.pushUps, 6, Sex.female),
      TrainingLevel.intermediate,
    );
    expect(
      levelOfItem(EntryTestItem.pushUps, 6, Sex.male),
      TrainingLevel.novice,
    );
  });

  test('результат сохраняется и читается', () {
    final back = EntryTestResult.fromJson(r(push: 12, pull: 3).toJson());
    expect(back.pushUps, 12);
    expect(back.pullUps, 3);
    expect(r().resultsJson().containsKey('at'), isFalse);
  });
}
