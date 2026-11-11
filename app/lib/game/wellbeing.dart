import 'program.dart';

/// Самочувствие после тренировки и облегчение плана (TRAINING_SYSTEM.md, раздел 6).
/// Приложение не ставит диагнозов: оно бережёт зону и советует обратиться к врачу.

enum Feeling {
  ok('Нормально'),
  hard('Тяжело'),
  pain('Что-то болит');

  const Feeling(this.label);
  final String label;
}

enum PainZone {
  shoulder('Плечо'),
  elbowWrist('Локоть или запястье'),
  lowerBack('Спина, поясница'),
  knee('Колено'),
  other('Другое');

  const PainZone(this.label);
  final String label;
}

/// Что изменилось в плане и почему — показывается человеку.
class PlanAdjustment {
  const PlanAdjustment({required this.exerciseId, this.replacementId});

  final String exerciseId;

  /// null — упражнение убрано на время.
  final String? replacementId;
}

class AdaptedDay {
  const AdaptedDay(this.day, {this.eased = false, this.adjustments = const []});

  final ProgramDay day;
  final bool eased;
  final List<PlanAdjustment> adjustments;

  bool get changed => eased || adjustments.isNotEmpty;
}

class Wellbeing {
  const Wellbeing._();

  /// «Тяжело» столько раз подряд — следующую тренировку облегчаем.
  static const hardInARowToEase = 2;

  /// Сколько дней бережём зону после «болит».
  static const avoidDays = 7;

  /// Повтор боли в той же зоне за это время — настойчивый совет к врачу.
  static const repeatWindow = Duration(days: 14);

  /// Упражнения, которые нагружают зону.
  static const _loads = <PainZone, Set<String>>{
    PainZone.shoulder: {'bench_press', 'db_bench_press', 'db_shoulder_press', 'push_up', 'dips', 'lat_pulldown', 'pull_up'},
    PainZone.elbowWrist: {'db_curl', 'french_press', 'dips', 'push_up', 'bench_press'},
    PainZone.lowerBack: {'romanian_deadlift', 'barbell_squat', 'back_extension', 'db_row'},
    PainZone.knee: {'barbell_squat', 'bodyweight_squat', 'lunges', 'leg_press'},
    PainZone.other: {},
  };

  /// Щадящие замены по порядку предпочтения: та же мышечная группа, меньше
  /// нагрузки на больное место. Берём первую, которая не нагружает больную зону;
  /// подходящей нет — упражнение на время убираем.
  static const _substitutes = <String, List<String>>{
    'barbell_squat': ['leg_press', 'romanian_deadlift'],
    'bodyweight_squat': ['back_extension'],
    'lunges': ['back_extension', 'romanian_deadlift'],
    'romanian_deadlift': ['leg_press'],
    'db_row': ['lat_pulldown'],
    'lat_pulldown': ['db_row'],
    'bench_press': ['db_bench_press'],
  };

  static Set<String> loadedBy(PainZone zone) => _loads[zone] ?? const {};

  /// План дня с учётом облегчения и больных зон.
  static AdaptedDay adapt(
    ProgramDay day, {
    required bool ease,
    required Set<PainZone> avoid,
    Equipment equipment = Equipment.gym,
  }) {
    final avoided = {for (final zone in avoid) ...loadedBy(zone)};
    final adjustments = <PlanAdjustment>[];
    final exercises = <PlannedExercise>[];
    for (final planned in day.exercises) {
      var exercise = planned;
      if (avoided.contains(planned.exerciseId)) {
        final substitute = (_substitutes[planned.exerciseId] ?? const <String>[])
            .where((id) => !avoided.contains(id) && !day.exercises.any((e) => e.exerciseId == id))
            .where((id) => isAvailable(id, equipment))
            .firstOrNull;
        adjustments.add(PlanAdjustment(exerciseId: planned.exerciseId, replacementId: substitute));
        if (substitute == null) continue;
        exercise = PlannedExercise(
          substitute,
          sets: planned.sets,
          repsMin: planned.repsMin,
          repsMax: planned.repsMax,
          repsInReserve: planned.repsInReserve,
        );
      }
      exercises.add(ease ? _eased(exercise) : exercise);
    }
    return AdaptedDay(ProgramDay(day.id, day.title, exercises), eased: ease, adjustments: adjustments);
  }

  static PlannedExercise _eased(PlannedExercise e) => PlannedExercise(
    e.exerciseId,
    sets: e.sets > 1 ? e.sets - 1 : 1,
    repsMin: e.repsMin,
    repsMax: e.repsMax,
    repsInReserve: e.repsInReserve,
  );
}
