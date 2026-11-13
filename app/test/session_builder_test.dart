import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/muscles.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';

List<ProgramDay> plan(
  TrainingLevel level,
  int sessions, {
  Equipment equipment = Equipment.gym,
  bool split = false,
  bool start = false,
  BodyPart? lagging,
}) => SessionBuilder.days(
  level: level,
  sessionsPerWeek: sessions,
  equipment: equipment,
  stepOf: (_) => level.startStep,
  split: split,
  start: start,
  lagging: lagging,
);

void main() {
  test('в зале — по уровню 6, 7 и 8 упражнений, подходов не больше 4', () {
    for (final level in TrainingLevel.values) {
      for (final (n, split) in [
        (3, false),
        (4, false),
        (5, false),
        (5, true),
      ]) {
        for (final day in plan(level, n, split: split)) {
          expect(
            day.exercises.length,
            level.exercises,
            reason: '$level ${day.id}',
          );
          expect(day.exercises.every((e) => e.sets <= 4), isTrue);
          final total = day.exercises.fold(0, (a, e) => a + e.sets);
          expect(
            total,
            lessThanOrEqualTo(level.daySets),
            reason: '$level ${day.id}',
          );
          final ids = [for (final e in day.exercises) e.exerciseId];
          expect(ids.toSet().length, ids.length, reason: 'без повторов: $ids');
        }
      }
    }
  });

  test('дома — только доступное и не меньше 5 упражнений', () {
    for (final level in TrainingLevel.values) {
      for (final day in plan(level, 4, equipment: Equipment.dumbbells)) {
        expect(day.exercises.length, greaterThanOrEqualTo(5));
        for (final e in day.exercises) {
          expect(isAvailable(e.exerciseId, Equipment.dumbbells), isTrue);
        }
      }
    }
  });

  test('новичку — простые варианты, опытному — штанга', () {
    final novice = plan(TrainingLevel.novice, 3).expand((d) => d.exercises);
    expect(novice.every((e) => e.exercise.difficulty <= 2), isTrue);
    expect(novice.map((e) => e.exerciseId), isNot(contains('barbell_squat')));
    final advanced = plan(TrainingLevel.advanced, 4).expand((d) => d.exercises);
    expect(
      advanced.map((e) => e.exerciseId),
      containsAll(['barbell_squat', 'bench_press', 'deadlift']),
    );
  });

  test('крупные мышцы за неделю близко к норме (верх/низ)', () {
    for (final level in TrainingLevel.values) {
      final week = SessionBuilder.weeklyPlan(plan(level, 4), 4);
      for (final m in [
        Muscle.lats,
        Muscle.quads,
        Muscle.hamstrings,
        Muscle.glutes,
      ]) {
        expect(
          week[m] ?? 0,
          greaterThanOrEqualTo(weeklyTarget(m, level) * 0.6),
          reason: '$level $m',
        );
      }
    }
  });

  test('отстающей части в неделю больше подходов', () {
    final plain = SessionBuilder.weeklyPlan(
      plan(TrainingLevel.intermediate, 5),
      5,
    );
    final back = SessionBuilder.weeklyPlan(
      plan(TrainingLevel.intermediate, 5, lagging: BodyPart.back),
      5,
    );
    expect(back[Muscle.lats]!, greaterThan(plain[Muscle.lats]!));
  });

  test('«Старт» — 2 подхода × 10–12, 3 в запасе', () {
    for (final e in plan(
      TrainingLevel.novice,
      3,
      start: true,
    ).expand((d) => d.exercises)) {
      expect(e.sets, 2);
      expect(e.repsInReserve, 3);
    }
  });

  test('сплит: спина+бицепс, грудь+трицепс+предплечья, ноги+плечи', () {
    expect(
      plan(TrainingLevel.intermediate, 5, split: true).map((d) => d.title),
      ['Спина и бицепс', 'Грудь, трицепс, предплечья', 'Ноги и плечи'],
    );
  });

  test('раскладка недели идёт с сегодняшнего дня и по кругу дней', () {
    final days = plan(TrainingLevel.intermediate, 3, split: true);
    final layout = weekLayout(
      days: days,
      nextIndex: 1,
      trainingDays: [0, 2, 4],
      today: DateTime(2026, 11, 11), // среда
    );
    expect(layout.map((d) => d.weekday), [2, 4, 0]);
    expect(layout.map((d) => d.title), [
      'Грудь, трицепс, предплечья',
      'Ноги и плечи',
      'Спина и бицепс',
    ]);
  });

  test('уровень: анкета, самопроверка и доказанный прогресс', () {
    expect(declaredLevel(experience: 0), TrainingLevel.novice);
    expect(declaredLevel(experience: 2), TrainingLevel.intermediate);
    expect(declaredLevel(experience: 3), TrainingLevel.advanced);
    // Тест поднимает не больше чем на ступень.
    expect(
      declaredLevel(experience: 0, pushUps: 50, pullUps: 15),
      TrainingLevel.intermediate,
    );
    expect(
      declaredLevel(experience: 2, pushUps: 50, pullUps: 15),
      TrainingLevel.advanced,
    );
    expect(
      provenLevel(
        completedWorkouts: 30,
        stepOf: (p) => p.startsWith('pu') ? 2 : 1,
      ),
      TrainingLevel.intermediate,
    );
    expect(
      provenLevel(completedWorkouts: 10, stepOf: (_) => 3),
      TrainingLevel.novice,
    );
  });
}
