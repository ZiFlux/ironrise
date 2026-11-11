import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/calendar.dart';
import 'package:ironrise/game/recommendation.dart';
import 'package:ironrise/game/streak.dart';

void main() {
  // Неделя 9–15 ноября 2026, сегодня четверг 12-е. График Пн/Ср/Пт, лимит отдыха 2.
  final today = DateTime(2026, 11, 12, 18);
  List<DayKind> weekKinds(Set<String> active, {DateTime? start}) => [
        for (final d in ActivityCalendar.week(
          today: today,
          activeDays: active,
          trainingDays: const [0, 2, 4],
          maxRestDays: 2,
          startDay: start ?? DateTime(2026, 11, 1),
        ))
          d.kind,
      ];

  group('календарь недели', () {
    test('тренировки, отдых и план на будущее', () {
      expect(weekKinds({'2026-11-07', '2026-11-09', '2026-11-11'}), [
        DayKind.trained, // Пн
        DayKind.rest, // Вт
        DayKind.trained, // Ср
        DayKind.upcomingRest, // Чт, сегодня
        DayKind.upcomingTraining, // Пт
        DayKind.upcomingRest, // Сб
        DayKind.upcomingRest, // Вс
      ]);
    });

    test('отдых сверх лимита — пропуск', () {
      // Последняя тренировка в пятницу 6-го: Сб, Вс — отдых, Пн — третий день, пропуск.
      final kinds = weekKinds({'2026-11-06'});
      expect(kinds.take(3), [DayKind.missed, DayKind.missed, DayKind.missed]);
    });

    test('дни до создания героя не помечаются', () {
      final kinds = weekKinds({}, start: DateTime(2026, 11, 11));
      expect(kinds.take(2), [DayKind.none, DayKind.none]);
      expect(kinds[2], DayKind.rest);
    });

    test('сегодняшний день отмечен', () {
      final week = ActivityCalendar.week(
        today: today,
        activeDays: const {},
        trainingDays: const [0],
        maxRestDays: 6,
        startDay: today,
      );
      expect(week.where((d) => d.isToday).single.date, DateTime(2026, 11, 12));
    });
  });

  group('серия на сегодня', () {
    test('сгорает, когда отдых превысил лимит', () {
      final last = DateTime(2026, 11, 9);
      int at(int day) => Streak.current(
          streakDays: 5, lastActiveDay: last, today: DateTime(2026, 11, day), maxRestDays: 2);
      expect(at(12), 5); // 2 дня отдыха
      expect(at(13), 0); // 3 дня отдыха
    });
  });

  group('рекомендация', () {
    test('упражнение с наибольшей долей на отстающую часть', () {
      final rec = Recommendation.forLagging([BodyPart.legs, BodyPart.arms])!;
      expect(rec.part, BodyPart.legs);
      expect(rec.exercise!.shares[BodyPart.legs], greaterThanOrEqualTo(0.8));
    });

    test('для кардио без упражнения — текстовый совет', () {
      final rec = Recommendation.forLagging([BodyPart.cardio])!;
      expect(rec.exercise, isNull);
      expect(rec.text, BodyPart.cardio.beginnerExercise);
    });

    test('без отстающих — нет рекомендации', () {
      expect(Recommendation.forLagging(const []), isNull);
    });
  });
}
