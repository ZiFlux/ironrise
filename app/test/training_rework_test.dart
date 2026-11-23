import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:ironrise/game/anti_fraud.dart';
import 'package:ironrise/game/body_part.dart';
import 'package:ironrise/game/exercise_catalog.dart';
import 'package:ironrise/game/muscles.dart';
import 'package:ironrise/game/program.dart';
import 'package:ironrise/game/session_builder.dart';
import 'package:ironrise/game/set_effort.dart';
import 'package:ironrise/game/skill_practice.dart';
import 'package:ironrise/game/training_format.dart';
import 'package:ironrise/game/warmup.dart';
import 'package:ironrise/game/workout.dart';

void main() {
  List<ProgramDay> split({Equipment equipment = Equipment.gym}) =>
      SessionBuilder.days(
        level: TrainingLevel.intermediate,
        sessionsPerWeek: 3,
        equipment: equipment,
        stepOf: (_) => 2,
        format: TrainingFormat.split,
      );

  group('сплит по схеме тренеров', () {
    test('спина с бицепсом и трапециями, грудь с трицепсом и предплечьями, '
        'ноги с плечами и икрами', () {
      final days = split();
      Set<String> patterns(ProgramDay d) => {
        for (final e in d.exercises) e.exercise.pattern,
      };
      expect(days.map((d) => d.title), [
        'Спина и бицепс',
        'Грудь, трицепс, предплечья',
        'Ноги и плечи',
      ]);
      expect(patterns(days[0]), containsAll(['pull_v', 'pull_h', 'biceps']));
      expect(
        patterns(days[0]).intersection({'traps', 'rear_delts'}),
        isNotEmpty,
      );
      expect(patterns(days[1]), containsAll(['push_h', 'triceps']));
      expect(patterns(days[1]), contains('forearms'));
      expect(patterns(days[2]), containsAll(['squat', 'push_v', 'delts']));
      expect(patterns(days[2]), contains('calves'));
    });

    test('дома с гантелями — тоже все группы', () {
      final days = split(equipment: Equipment.dumbbells);
      for (final d in days) {
        expect(d.exercises.length, greaterThanOrEqualTo(5));
        for (final e in d.exercises) {
          expect(isAvailable(e.exerciseId, Equipment.dumbbells), isTrue);
        }
      }
    });

    test('подряд — разные мышцы: широчайшие, потом бицепс', () {
      final back = split()[0].exercises
          .where(
            (e) => !{'core', 'forearms', 'calves'}.contains(e.exercise.pattern),
          )
          .toList();
      for (var i = 1; i < back.length; i++) {
        expect(
          primaryMuscleOf(back[i].exerciseId),
          isNot(primaryMuscleOf(back[i - 1].exerciseId)),
          reason: '${back[i - 1].exerciseId} → ${back[i].exerciseId}',
        );
      }
    });

    test('пресс и предплечья — в конце дня', () {
      for (final d in split()) {
        final ids = [for (final e in d.exercises) e.exercise.pattern];
        final firstTail = ids.indexWhere((p) => p == 'core' || p == 'forearms');
        if (firstTail < 0) continue;
        expect(
          ids.skip(firstTail).every((p) => p == 'core' || p == 'forearms'),
          isTrue,
          reason: ids.join(', '),
        );
      }
    });
  });

  group('раскладка по дням недели (частота 2 раза, 48 часов, уровень)', () {
    Rotation best(List<int> days, TrainingLevel level) =>
        SessionBuilder.bestRotation(days, level);

    test('2–3 дня через день — всё тело', () {
      expect(best([0, 3], TrainingLevel.novice), Rotation.fullBody);
      expect(best([0, 2, 4], TrainingLevel.novice), Rotation.fullBody);
      expect(best([0, 2, 4], TrainingLevel.intermediate), Rotation.fullBody);
    });

    test('соседние дни — не всё тело', () {
      expect(best([0, 1, 3, 4], TrainingLevel.novice), Rotation.upperLower);
      expect(best([0, 1, 3, 4], TrainingLevel.advanced), Rotation.upperLower);
    });

    test('6 дней — сплит, 5 дней опытному — сплит', () {
      expect(
        best([0, 1, 2, 3, 4, 5], TrainingLevel.intermediate),
        Rotation.split,
      );
      expect(best([0, 1, 2, 3, 4], TrainingLevel.advanced), Rotation.split);
    });

    test('«подбери сам» с днями графика берёт лучшую раскладку', () {
      final days = SessionBuilder.days(
        level: TrainingLevel.intermediate,
        sessionsPerWeek: 4,
        equipment: Equipment.gym,
        stepOf: (_) => 2,
        weekdays: const [0, 1, 3, 4],
      );
      expect(days.map((d) => d.title), ['Верх', 'Низ']);
    });
  });

  group('разминка: общая по суставам и акцент на мышцы дня', () {
    test('шея, плечи, локти, спина, поясница, таз, колени — всегда', () {
      final moves = Warmup.forExercises([
        ExerciseCatalog.byId('bench_press'),
      ], Equipment.gym);
      final zones = {for (final m in moves) ?m.general};
      expect(zones, containsAll(Warmup.zones));
      expect(moves.first.isCardio, isTrue);
    });

    test('день ног — акцент на ноги', () {
      final legs = Warmup.forExercises([
        ExerciseCatalog.byId('barbell_squat'),
        ExerciseCatalog.byId('romanian_deadlift'),
      ], Equipment.gym);
      final focus = legs.where((m) => m.general == null && !m.isCardio);
      expect(focus, isNotEmpty);
      expect(focus.first.targets, contains(BodyPart.legs));
    });
  });

  group('пульс: хвост прошлого подхода', () {
    final t0 = DateTime(2026, 11, 20, 18);
    const resting = 60;

    /// Пульс каждые 5 с: подходы по 40 с до отметки поднимают до 150, после —
    /// спад к покою с τ = 50 с.
    List<PulseSample> pulse(List<int> setAt) {
      final out = <PulseSample>[];
      for (var s = 0; s <= 900; s += 5) {
        var bpm = resting.toDouble();
        for (final at in setAt) {
          if (s <= at && s >= at - 40) {
            bpm = 150;
          } else if (s > at) {
            final tail = resting + 90 * math.exp(-(s - at) / 50);
            if (tail > bpm) bpm = tail;
          }
        }
        out.add(PulseSample(t0.add(Duration(seconds: s)), bpm.round()));
      }
      return out;
    }

    test('скорость спада оценивается по отдыху', () {
      final sets = [100, 300, 500];
      final tau = SetEffortAnalysis.recoveryTauOf(pulse(sets), [
        for (final s in sets) t0.add(Duration(seconds: s)),
      ], restingHr: resting);
      expect(tau.inSeconds, inInclusiveRange(40, 70));
    });

    test('короткий отдых: подход не считается «без подъёма»', () {
      // Отдых минута: к началу второго подхода пульс ещё не упал.
      final sets = [100, 200, 400];
      final session = WorkoutSession(
        startedAt: t0,
        entries: [
          ExerciseEntry(
            exercise: ExerciseCatalog.byId('barbell_squat'),
            sets: [
              for (final s in sets)
                SetRecord(
                  weight: 60,
                  reps: 8,
                  at: t0.add(Duration(seconds: s)),
                ),
            ],
          ),
        ],
      );
      final a = SetEffortAnalysis.of(
        session,
        pulse(sets),
        restingHr: resting,
        maxHr: 190,
      )!;
      expect(a.flatSets, isEmpty);
      expect(a.sets[1].carryOver, greaterThan(10));
      expect(a.sets[2].carryOver, lessThan(a.sets[1].carryOver));
    });

    test('время до восстановления растёт с пульсом', () {
      Duration wait(int bpm) => SetEffortAnalysis.timeToRecover(
        bpm: bpm,
        restingHr: resting,
        maxHr: 190,
      );
      expect(wait(100), Duration.zero);
      expect(wait(170), greaterThan(wait(140)));
    });
  });

  group('не получается — учимся', () {
    final now = DateTime(2026, 11, 20);
    final pullDay = ProgramDay('S1', 'Спина', [
      const PlannedExercise(
        'pull_up',
        sets: 3,
        repsMin: 5,
        repsMax: 8,
        repsInReserve: 2,
      ),
      const PlannedExercise(
        'db_curl',
        sets: 3,
        repsMin: 10,
        repsMax: 12,
        repsInReserve: 2,
      ),
    ]);

    test('подводящие к подтягиваниям: вис, лопатки, негативы', () {
      final drills = SkillPractice.drillsFor(
        ExerciseCatalog.byId('pull_up'),
        equipment: Equipment.gym,
      ).map((e) => e.id);
      expect(drills, contains('dead_hang'));
      expect(drills, contains('scapular_pull_up'));
      expect(drills, isNot(contains('pull_up')));
    });

    test(
      'в плане: замена и подводящие, отдельный комплекс — только замена',
      () {
        final goal = SkillGoal(exerciseId: 'pull_up', since: now);
        final day = SkillPractice.apply(
          pullDay,
          goals: {'pull_up': goal},
          now: now.add(const Duration(days: 2)),
          equipment: Equipment.gym,
        );
        final roles = [for (final e in day.exercises) e.skillRole];
        expect(day.exercises.any((e) => e.exerciseId == 'pull_up'), isFalse);
        expect(roles.where((r) => r == SkillRole.alternative), hasLength(1));
        expect(
          roles.where((r) => r == SkillRole.drill),
          hasLength(SkillPractice.drillsInWorkout),
        );
        final practiced = SkillPractice.apply(
          pullDay,
          goals: {
            'pull_up': goal.copyWith(
              practice: [now.add(const Duration(days: 1))],
            ),
          },
          now: now.add(const Duration(days: 2)),
          equipment: Equipment.gym,
        );
        expect(
          practiced.exercises.where((e) => e.skillRole == SkillRole.drill),
          isEmpty,
        );
        expect(
          practiced.exercises.where(
            (e) => e.skillRole == SkillRole.alternative,
          ),
          hasLength(1),
        );
      },
    );

    test('через две недели — проверка самим упражнением', () {
      final day = SkillPractice.apply(
        pullDay,
        goals: {'pull_up': SkillGoal(exerciseId: 'pull_up', since: now)},
        now: now.add(SkillGoal.checkAfter),
        equipment: Equipment.gym,
      );
      final check = day.exercises.first;
      expect(check.exerciseId, 'pull_up');
      expect(check.skillRole, SkillRole.check);
      expect(SkillPractice.checkPassed(check, const [3, 5]), isTrue);
      expect(SkillPractice.checkPassed(check, const [2, 2]), isFalse);
      expect(SkillPractice.checkPassed(check, const []), isNull);
    });

    test('отработка вне плана засчитывается по подводящим', () {
      final goal = SkillGoal(exerciseId: 'pull_up', since: now);
      final drills = SkillPractice.drillsFor(
        goal.exercise,
        equipment: Equipment.gym,
      );
      expect(
        SkillPractice.isPractice(goal, {
          drills[0].id,
          drills[1].id,
        }, Equipment.gym),
        isTrue,
      );
      expect(
        SkillPractice.isPractice(goal, {drills[0].id}, Equipment.gym),
        isFalse,
      );
    });

    test('цель отработки переживает сохранение', () {
      final goal = SkillGoal(
        exerciseId: 'pull_up',
        since: now,
        practice: [now],
        checks: 1,
      );
      final back = SkillGoal.fromJson('pull_up', goal.toJson());
      expect(back.since, now);
      expect(back.practice, [now]);
      expect(back.checks, 1);
      final plan = const PlannedExercise(
        'dead_hang',
        sets: 2,
        repsMin: 20,
        repsMax: 35,
        repsInReserve: 2,
        skillFor: 'pull_up',
        skillRole: SkillRole.drill,
      );
      final restored = PlannedExercise.fromJson(plan.toJson());
      expect(restored.skillFor, 'pull_up');
      expect(restored.skillRole, SkillRole.drill);
    });
  });

  test('база: у каждого сложного базового движения есть подводящие', () {
    for (final id in [
      'pull_up',
      'push_up',
      'dips',
      'barbell_squat',
      'deadlift',
      'hanging_leg_raise',
      'plank',
      'bulgarian_split_squat',
    ]) {
      expect(
        SkillPractice.drillsFor(
          ExerciseCatalog.byId(id),
          equipment: Equipment.gym,
        ),
        isNotEmpty,
        reason: id,
      );
    }
  });
}
