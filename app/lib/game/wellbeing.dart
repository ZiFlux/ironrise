import 'exercise_catalog.dart';
import 'game_config.dart';
import 'program.dart';
import 'workout_variant.dart';

/// Самочувствие после тренировки и облегчение плана (TRAINING_SYSTEM.md, раздел 6).
/// Приложение не ставит диагнозов: оно бережёт зону и советует обратиться к врачу.

enum Feeling {
  easy('Легко'),
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
/// Почему упражнение заменено: бережём больное место или оно не понравилось.
enum AdjustReason { pain, dislike }

class PlanAdjustment {
  const PlanAdjustment({
    required this.exerciseId,
    this.replacementId,
    this.reason = AdjustReason.pain,
  });

  final String exerciseId;

  /// null — упражнение убрано на время.
  final String? replacementId;
  final AdjustReason reason;
}

class AdaptedDay {
  const AdaptedDay(
    this.day, {
    this.eased = false,
    this.boosted = false,
    this.adjustments = const [],
    this.variant = WorkoutVariant.regular,
  });

  final ProgramDay day;
  final bool eased;

  /// Вид тренировки по ритму (или выбранный на сегодня).
  final WorkoutVariant variant;

  AdaptedDay withVariant(WorkoutVariant v) => AdaptedDay(
    day,
    eased: eased,
    boosted: boosted,
    adjustments: adjustments,
    variant: v,
  );

  /// «Легко» два раза подряд — на подход больше (в пределах лимита).
  final bool boosted;
  final List<PlanAdjustment> adjustments;

  bool get changed => eased || boosted || adjustments.isNotEmpty;
}

class Wellbeing {
  const Wellbeing._();

  /// «Тяжело» столько раз подряд — следующую тренировку облегчаем.
  static const hardInARowToEase = 2;

  /// Сколько дней бережём зону после «болит».
  static const avoidDays = 7;

  /// Повтор боли в той же зоне за это время — настойчивый совет к врачу.
  static const repeatWindow = Duration(days: 14);

  /// «Легко» столько раз подряд — следующую тренировку усиливаем.
  static const easyInARowToBoost = 2;

  /// Сколько дней не ставим упражнение, которое «не зашло».
  static const dislikeDays = 30;

  /// Упражнения, которые нагружают зону (shared/exercises.json, поле joints).
  static Set<String> loadedBy(PainZone zone) => {
    for (final e in ExerciseCatalog.all)
      if (e.joints.contains(zone.name)) e.id,
  };

  /// Щадящая замена: та же главная часть тела и единица, не нагружает больные
  /// зоны, не из «не зашло», доступна и ещё не в дне. Сначала то же движение,
  /// потом сложность ближе к min(исходная, 2), потом тот же тип нагрузки.
  static String? substituteFor(
    Exercise original, {
    required Set<String> excluded,
    required Set<String> inDay,
    required Equipment equipment,
  }) {
    final target = original.difficulty < 2 ? original.difficulty : 2;
    final options = ExerciseCatalog.all
        .where(
          (e) =>
              e.id != original.id &&
              e.mainPart == original.mainPart &&
              e.unit == original.unit &&
              !excluded.contains(e.id) &&
              !inDay.contains(e.id) &&
              isAvailable(e.id, equipment),
        )
        .toList();
    int rank(Exercise e) =>
        (e.pattern == original.pattern ? 0 : 1000) +
        (e.difficulty - target).abs() * 100 +
        (e.usesWeight == original.usesWeight ? 0 : 10);
    options.sort((x, y) => rank(x).compareTo(rank(y)));
    return options.firstOrNull?.id;
  }

  /// План дня с учётом облегчения, усиления, больных зон и нелюбимых упражнений.
  static AdaptedDay adapt(
    ProgramDay day, {
    required bool ease,
    required Set<PainZone> avoid,
    bool boost = false,
    Set<String> disliked = const {},
    Equipment equipment = Equipment.gym,
  }) {
    final painful = {for (final zone in avoid) ...loadedBy(zone)};
    final excluded = {...painful, ...disliked};
    final inDay = {for (final e in day.exercises) e.exerciseId};
    final adjustments = <PlanAdjustment>[];
    final exercises = <PlannedExercise>[];
    for (final planned in day.exercises) {
      var exercise = planned;
      if (excluded.contains(planned.exerciseId)) {
        final substitute = substituteFor(
          planned.exercise,
          excluded: excluded,
          inDay: inDay,
          equipment: equipment,
        );
        adjustments.add(
          PlanAdjustment(
            exerciseId: planned.exerciseId,
            replacementId: substitute,
            reason: painful.contains(planned.exerciseId)
                ? AdjustReason.pain
                : AdjustReason.dislike,
          ),
        );
        if (substitute == null) continue;
        inDay.add(substitute);
        exercise = planned.copyWith(exerciseId: substitute);
      }
      exercises.add(
        ease
            ? _eased(exercise)
            : boost
            ? _boosted(exercise)
            : exercise,
      );
    }
    return AdaptedDay(
      ProgramDay(day.id, day.title, exercises),
      eased: ease,
      boosted: boost && !ease,
      adjustments: adjustments,
    );
  }

  static PlannedExercise _boosted(PlannedExercise e) => e.copyWith(
    sets: e.sets < GameConfig.maxSetsPerExercise ? e.sets + 1 : e.sets,
  );

  static PlannedExercise _eased(PlannedExercise e) =>
      e.copyWith(sets: e.sets > 1 ? e.sets - 1 : 1);
}
