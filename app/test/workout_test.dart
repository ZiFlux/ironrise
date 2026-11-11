import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/game_config.dart';
import 'package:ironrise/game/streak.dart';
import 'package:ironrise/game/workout.dart';

Map<BodyPart, int> xpAll(int value) => {for (final p in BodyPart.values) p: value};

WorkoutSession sessionWith(String exerciseId, int sets) {
  final start = DateTime(2026, 11, 11, 19);
  var entry = ExerciseEntry(exercise: ExerciseCatalog.byId(exerciseId));
  for (var i = 0; i < sets; i++) {
    entry = entry.withSet(const SetRecord(weight: 30, reps: 10));
  }
  return WorkoutSession(startedAt: start, entries: [entry]);
}

void main() {
  group('опыт за тренировку', () {
    test('жим лёжа делит опыт между грудью и руками', () {
      final summary = WorkoutScoring.summarize(
        session: sessionWith('bench_press', 3),
        xpBefore: xpAll(0),
        validity: 1,
        finishedAt: DateTime(2026, 11, 11, 19, 40),
      );
      // 18 · 0,7 · 3 = 37,8 → 38; 18 · 0,3 · 3 = 16,2 → 16
      expect({for (final g in summary.gains) g.part: g.xp}, {BodyPart.chest: 38, BodyPart.arms: 16});
      expect(summary.duration, const Duration(minutes: 40));
      expect(summary.coins, 11);
    });

    test('отстающая часть получает ×1,5, без часов опыт ×0,5', () {
      final xp = xpAll(300)..[BodyPart.legs] = 0; // ноги: уровень 1, остальные 4
      final summary = WorkoutScoring.summarize(
        session: sessionWith('leg_press', 2),
        xpBefore: xp,
        validity: GameConfig.unverifiedValidity,
        finishedAt: DateTime(2026, 11, 11, 20),
      );
      // 18 · 1 · 1,5 · 0,5 · 2 = 27
      expect(summary.gains.single.xp, 27);
      expect(summary.gains.single.wasLagging, isTrue);
      expect(summary.isVerified, isFalse);
    });

    test('больше 8 подходов на упражнение не засчитываются', () {
      final entry = sessionWith('db_curl', 12).entries.single;
      expect(entry.sets.length, GameConfig.maxSetsPerExercise);
    });

    test('переход на новый уровень', () {
      final summary = WorkoutScoring.summarize(
        session: sessionWith('db_curl', 4),
        xpBefore: xpAll(90),
        validity: 1,
        finishedAt: DateTime(2026, 11, 11, 20),
      );
      final arms = summary.gains.single;
      expect(arms.levelBefore, 1);
      expect(arms.levelAfter, 2);
      expect(arms.leveledUp, isTrue);
    });
  });

  group('серия', () {
    final monday = DateTime(2026, 11, 9);

    test('первая тренировка начинает серию', () {
      expect(Streak.afterActivity(currentStreak: 0, lastActiveDay: null, today: monday, maxRestDays: 2), 1);
    });

    test('вторая тренировка в тот же день не меняет серию', () {
      expect(Streak.afterActivity(currentStreak: 5, lastActiveDay: monday, today: monday, maxRestDays: 2), 5);
    });

    test('отдых в пределах формата засчитывается в серию', () {
      final thursday = monday.add(const Duration(days: 3)); // 2 дня отдыха
      expect(Streak.afterActivity(currentStreak: 5, lastActiveDay: monday, today: thursday, maxRestDays: 2), 8);
    });

    test('лишний день отдыха сбрасывает серию', () {
      final friday = monday.add(const Duration(days: 4)); // 3 дня отдыха
      expect(Streak.afterActivity(currentStreak: 5, lastActiveDay: monday, today: friday, maxRestDays: 2), 1);
    });
  });
}
