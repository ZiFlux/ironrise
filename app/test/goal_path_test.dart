import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/goal_path.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/state/hero.dart';

// П. 117: свой путь у каждой главной цели (TRAINING_SYSTEM.md 15).
void main() {
  List<ProgramDay> plan(
    Goal goal, {
    TrainingLevel level = TrainingLevel.intermediate,
    bool start = false,
  }) => SessionBuilder.days(
    level: level,
    sessionsPerWeek: 3,
    equipment: Equipment.gym,
    stepOf: (_) => level.startStep,
    format: TrainingFormat.fullBody,
    start: start,
    goal: goal,
  );

  test('сила: базовые 4–6, у новичка не ниже 6', () {
    final first = plan(Goal.strength).first.exercises.first;
    expect((first.repsMin, first.repsMax), (4, 6));
    final novice = plan(
      Goal.strength,
      level: TrainingLevel.novice,
    ).first.exercises.first;
    expect(novice.repsMin, greaterThanOrEqualTo(6));
  });

  test('похудеть и выносливость — финишер на дыхалку в конце', () {
    for (final goal in [Goal.fatLoss, Goal.endurance]) {
      for (final day in plan(goal)) {
        expect(
          [
            'burpee',
            'jump_squat',
            'mountain_climber',
            'jumping_jacks',
          ].contains(day.exercises.last.exerciseId),
          isTrue,
          reason: '$goal ${day.id}',
        );
      }
    }
    expect(plan(Goal.mass).first.exercises.last.exerciseId, isNot('burpee'));
  });

  test('регулярность — на упражнение меньше и больше запаса', () {
    final mass = plan(Goal.mass).first.exercises;
    final easy = plan(Goal.consistency).first.exercises;
    expect(easy.length, mass.length - 1);
    expect(easy.first.repsInReserve, greaterThan(mass.first.repsInReserve));
  });

  test('«Старт» одинаков для всех целей', () {
    final a = plan(Goal.strength, start: true).first.exercises;
    final b = plan(Goal.endurance, start: true).first.exercises;
    expect(
      a.map((e) => (e.exerciseId, e.repsMin, e.repsMax)).toList(),
      b.map((e) => (e.exerciseId, e.repsMin, e.repsMax)).toList(),
    );
  });

  test('отдых и взвешивание по цели', () {
    expect(restFor(Goal.strength).inSeconds, 150);
    expect(restFor(Goal.endurance).inSeconds, 45);
    expect(restFor(null).inSeconds, 90);
    expect(weighInEveryFor(Goal.fatLoss, const []).inDays, 2);
    expect(weighInEveryFor(Goal.mass, const [Goal.fatLoss]).inDays, 2);
    expect(weighInEveryFor(Goal.mass, const []).inDays, 3);
  });
}
