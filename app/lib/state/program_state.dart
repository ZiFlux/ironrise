import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/body_part.dart';
import '../game/exercise_ladder.dart';
import '../game/program.dart';
import '../game/session_builder.dart';
import '../game/training_format.dart';
import '../game/wellbeing.dart';
import '../game/workout.dart';
import 'hero.dart';
import 'providers.dart';

const _programKey = 'program_v1';

/// Программа тренировок пользователя: где тренируется, какой день следующий,
/// рабочие веса по упражнениям.
class UserProgram {
  const UserProgram({
    this.equipment = Equipment.gym,
    this.nextDayIndex = 0,
    this.completedWorkouts = 0,
    this.progress = const {},
    this.hardInARow = 0,
    this.easeNext = false,
    this.painReports = const [],
    this.levels = const {},
    this.easyInARow = 0,
    this.boostNext = false,
    this.disliked = const {},
  });

  final Equipment equipment;
  final int nextDayIndex;
  final int completedWorkouts;
  final Map<String, ExerciseProgress> progress;

  /// Сколько тренировок подряд человек отметил «тяжело».
  final int hardInARow;

  /// Следующая тренировка по плану облегчена.
  final bool easeNext;
  final List<PainReport> painReports;

  /// Ступень в каждом движении (pattern → 1–3): лесенка «проще → сложнее».
  final Map<String, int> levels;

  /// Сколько тренировок подряд человек отметил «легко».
  final int easyInARow;

  /// Следующая тренировка по плану усилена: на подход больше.
  final bool boostNext;

  /// Упражнения, которые «не зашли»: id → когда отмечено. Месяц их заменяем.
  final Map<String, DateTime> disliked;

  Set<String> dislikedNow(DateTime now) => {
    for (final e in disliked.entries)
      if (now.difference(e.value).inDays < Wellbeing.dislikeDays) e.key,
  };

  int levelOf(String pattern, {required int start}) => ExerciseLadder.levelOf(
    pattern,
    levels: levels,
    progress: progress,
    start: start,
  );

  ProgramPhase get phase => ProgramPhase.after(completedWorkouts);

  /// Фаза для уровня: «Старт» (освоить технику) — только новичкам.
  ProgramPhase phaseFor(TrainingLevel level) =>
      level == TrainingLevel.novice ? phase : ProgramPhase.base;

  /// Дни программы: 6–8 упражнений под уровень, подходы — под недельную норму
  /// мышц (session_builder.dart). «Старт» новичка — всё тело, 2 подхода.
  List<ProgramDay> days(
    int sessionsPerWeek, {
    bool split = false,
    TrainingLevel level = TrainingLevel.novice,
    BodyPart? lagging,
  }) {
    final start = phaseFor(level) == ProgramPhase.start;
    return SessionBuilder.days(
      level: level,
      sessionsPerWeek: start ? 3 : sessionsPerWeek,
      equipment: equipment,
      stepOf: (pattern) => levelOf(pattern, start: level.startStep),
      split: split && !start,
      start: start,
      lagging: start ? null : lagging,
    );
  }

  /// Зоны, которые сейчас бережём после «болит».
  Set<PainZone> avoidedZones(DateTime now) => {
    for (final r in painReports)
      if (now.difference(r.at).inDays < Wellbeing.avoidDays) r.zone,
  };

  /// План на сегодня: день фазы, точечное упражнение на отстающую часть («База»),
  /// облегчение и больные зоны.
  AdaptedDay planFor({
    required DateTime now,
    required int sessionsPerWeek,
    BodyPart? lagging,
    TrainingLevel level = TrainingLevel.novice,
    bool split = false,
  }) {
    final all = days(
      sessionsPerWeek,
      split: split,
      level: level,
      lagging: lagging,
    );
    final day = all[nextDayIndex % all.length];
    return Wellbeing.adapt(
      day,
      ease: easeNext,
      boost: boostNext,
      avoid: avoidedZones(now),
      disliked: dislikedNow(now),
      equipment: equipment,
    );
  }

  ExerciseProgress progressOf(String exerciseId) =>
      progress[exerciseId] ?? const ExerciseProgress();

  UserProgram copyWith({
    Equipment? equipment,
    int? nextDayIndex,
    int? completedWorkouts,
    Map<String, ExerciseProgress>? progress,
    int? hardInARow,
    bool? easeNext,
    List<PainReport>? painReports,
    Map<String, int>? levels,
    int? easyInARow,
    bool? boostNext,
    Map<String, DateTime>? disliked,
  }) => UserProgram(
    levels: levels ?? this.levels,
    easyInARow: easyInARow ?? this.easyInARow,
    boostNext: boostNext ?? this.boostNext,
    disliked: disliked ?? this.disliked,
    equipment: equipment ?? this.equipment,
    nextDayIndex: nextDayIndex ?? this.nextDayIndex,
    completedWorkouts: completedWorkouts ?? this.completedWorkouts,
    progress: progress ?? this.progress,
    hardInARow: hardInARow ?? this.hardInARow,
    easeNext: easeNext ?? this.easeNext,
    painReports: painReports ?? this.painReports,
  );

  Map<String, dynamic> toJson() => {
    'equipment': equipment.name,
    'nextDayIndex': nextDayIndex,
    'completedWorkouts': completedWorkouts,
    'progress': {for (final e in progress.entries) e.key: e.value.toJson()},
    'hardInARow': hardInARow,
    'easeNext': easeNext,
    'painReports': [for (final r in painReports) r.toJson()],
    'levels': levels,
    'easyInARow': easyInARow,
    'boostNext': boostNext,
    'disliked': {
      for (final e in disliked.entries) e.key: e.value.toIso8601String(),
    },
  };

  factory UserProgram.fromJson(Map<String, dynamic> j) => UserProgram(
    equipment: Equipment.values.byName(j['equipment']),
    nextDayIndex: j['nextDayIndex'] ?? 0,
    completedWorkouts: j['completedWorkouts'] ?? 0,
    progress: {
      for (final e in (j['progress'] as Map<String, dynamic>? ?? {}).entries)
        e.key: ExerciseProgress.fromJson(e.value),
    },
    hardInARow: j['hardInARow'] ?? 0,
    easeNext: j['easeNext'] ?? false,
    painReports: [
      for (final r in j['painReports'] as List? ?? const [])
        PainReport.fromJson(r),
    ],
    levels: {
      for (final e in (j['levels'] as Map? ?? const {}).entries)
        e.key as String: (e.value as num).toInt(),
    },
    easyInARow: j['easyInARow'] ?? 0,
    boostNext: j['boostNext'] ?? false,
    disliked: {
      for (final e in (j['disliked'] as Map? ?? const {}).entries)
        e.key as String: DateTime.parse(e.value as String),
    },
  );
}

class PainReport {
  const PainReport(this.zone, this.at);

  final PainZone zone;
  final DateTime at;

  Map<String, dynamic> toJson() => {
    'zone': zone.name,
    'at': at.toIso8601String(),
  };

  factory PainReport.fromJson(Map<String, dynamic> j) =>
      PainReport(PainZone.values.byName(j['zone']), DateTime.parse(j['at']));
}

/// Что приложение ответило на самочувствие.
class WellbeingResponse {
  const WellbeingResponse({
    required this.feeling,
    this.zone,
    this.easeNext = false,
    this.boostNext = false,
    this.repeatedPain = false,
    this.plan,
  });

  final Feeling feeling;
  final PainZone? zone;

  /// Следующая тренировка будет облегчена.
  final bool easeNext;

  /// Следующая тренировка будет усилена.
  final bool boostNext;

  /// Боль в этой зоне уже была недавно.
  final bool repeatedPain;

  /// План следующей тренировки после изменений.
  final AdaptedDay? plan;
}

/// Итог по программе для экрана итогов: что изменится в следующий раз.
class PlanResult {
  const PlanResult({
    required this.changes,
    required this.bonusCoins,
    this.levelUps = const [],
  });

  final List<ProgressChange> changes;
  final int bonusCoins;

  /// Освоенные упражнения: со следующей тренировки — вариант сложнее.
  final List<LevelUp> levelUps;
}

class ProgramNotifier extends Notifier<UserProgram> {
  @override
  UserProgram build() {
    final raw = ref.read(prefsProvider).getString(_programKey);
    if (raw == null) return const UserProgram();
    try {
      return UserProgram.fromJson(jsonDecode(raw));
    } catch (_) {
      return const UserProgram();
    }
  }

  Future<void> setEquipment(Equipment equipment) =>
      _save(state.copyWith(equipment: equipment, nextDayIndex: 0));

  /// Записать результат тренировки по плану: рабочие веса, ступени движений
  /// и следующий день.
  Future<({List<ProgressChange> changes, List<LevelUp> levelUps})> applyWorkout(
    WorkoutSession session,
  ) async {
    if (session.planDayId == null) {
      return (changes: <ProgressChange>[], levelUps: <LevelUp>[]);
    }
    final progress = {...state.progress};
    final changes = <ProgressChange>[];
    for (final entry in session.entries) {
      final plan = entry.plan;
      if (plan == null || entry.sets.isEmpty) continue;
      final change = DoubleProgression.next(
        plan: plan,
        current: state.progressOf(plan.exerciseId),
        sets: entry.sets,
        // Не ответил — считаем, что запас был: отказ от вопроса не тормозит прогресс.
        hadReserve: entry.hadReserve ?? true,
      );
      progress[plan.exerciseId] = change.after;
      changes.add(change);
    }
    final levels = {...state.levels};
    final levelUps = <LevelUp>[];
    final hero = ref.read(heroProvider);
    final start = startLevelOf(hero);
    for (final change in changes) {
      final exercise = change.plan.exercise;
      final pattern = exercise.pattern;
      final level = ExerciseLadder.levelOf(
        pattern,
        levels: levels,
        progress: progress,
        start: start,
      );
      // Ступень растёт с того варианта, на котором человек сейчас.
      if (exercise.difficulty < level || level >= ExerciseLadder.maxLevel) {
        continue;
      }
      if (level + 1 >= ExerciseLadder.maxLevel &&
          state.completedWorkouts < ExerciseLadder.workoutsBeforeTopLevel) {
        continue;
      }
      final harder = ExerciseLadder.harderThan(exercise, state.equipment);
      if (harder == null) continue;
      final ok = ExerciseLadder.mastered(
        exercise,
        change.after,
        bodyweightKg: hero?.body.weightKg,
        female: hero?.body.sex == Sex.female,
      );
      if (!ok) continue;
      levels[pattern] = level + 1;
      levelUps.add((from: exercise.name, to: harder.name));
    }
    await _save(
      state.copyWith(
        levels: levels,
        progress: progress,
        nextDayIndex: state.nextDayIndex + 1,
        completedWorkouts:
            state.completedWorkouts + (session.planCompleted ? 1 : 0),
        // Облегчённая или усиленная тренировка сделана — дальше обычный план.
        easeNext: false,
        boostNext: false,
      ),
    );
    return (changes: changes, levelUps: levelUps);
  }

  /// Только для разработки: сразу перейти в фазу «База» или вернуться в «Старт».
  Future<void> debugTogglePhase() => _save(
    state.copyWith(
      completedWorkouts: state.phase == ProgramPhase.start
          ? ProgramPhase.startWorkouts
          : 0,
    ),
  );

  /// Самочувствие после тренировки (TRAINING_SYSTEM.md, раздел 6).
  Future<WellbeingResponse> recordWellbeing(
    Feeling feeling, {
    PainZone? zone,
  }) async {
    final now = DateTime.now();
    switch (feeling) {
      case Feeling.easy:
        final easy = state.easyInARow + 1;
        final boost = easy >= Wellbeing.easyInARowToBoost;
        await _save(
          state.copyWith(
            hardInARow: 0,
            easyInARow: boost ? 0 : easy,
            boostNext: boost || state.boostNext,
          ),
        );
        return WellbeingResponse(
          feeling: Feeling.easy,
          boostNext: boost,
          plan: boost ? planForHero(state, ref.read(heroProvider)) : null,
        );
      case Feeling.ok:
        await _save(state.copyWith(hardInARow: 0, easyInARow: 0));
        return const WellbeingResponse(feeling: Feeling.ok);
      case Feeling.hard:
        final hard = state.hardInARow + 1;
        final ease = hard >= Wellbeing.hardInARowToEase;
        await _save(
          state.copyWith(
            hardInARow: ease ? 0 : hard,
            easyInARow: 0,
            easeNext: ease || state.easeNext,
            boostNext: false,
          ),
        );
        return WellbeingResponse(
          feeling: Feeling.hard,
          easeNext: ease,
          plan: ease ? planForHero(state, ref.read(heroProvider)) : null,
        );
      case Feeling.pain:
        final where = zone ?? PainZone.other;
        final repeated = state.painReports.any(
          (r) =>
              r.zone == where && now.difference(r.at) < Wellbeing.repeatWindow,
        );
        await _save(
          state.copyWith(
            painReports: [
              for (final r in state.painReports)
                if (now.difference(r.at) < Wellbeing.repeatWindow) r,
              PainReport(where, now),
            ],
          ),
        );
        return WellbeingResponse(
          feeling: Feeling.pain,
          zone: where,
          repeatedPain: repeated,
          plan: planForHero(state, ref.read(heroProvider)),
        );
    }
  }

  /// «Не зашло»: месяц ставим вместо него похожее (или возвращаем обратно).
  Future<void> toggleDislike(String exerciseId) {
    final disliked = {...state.disliked};
    disliked.containsKey(exerciseId)
        ? disliked.remove(exerciseId)
        : disliked[exerciseId] = DateTime.now();
    return _save(state.copyWith(disliked: disliked));
  }

  Future<void> _save(UserProgram program) async {
    state = program;
    await ref
        .read(prefsProvider)
        .setString(_programKey, jsonEncode(program.toJson()));
  }
}

final programProvider = NotifierProvider<ProgramNotifier, UserProgram>(
  ProgramNotifier.new,
);

/// План следующей тренировки с учётом героя: формат тренировок и отстающая часть.
AdaptedDay planForHero(UserProgram program, HeroProfile? hero) =>
    program.planFor(
      now: DateTime.now(),
      sessionsPerWeek: hero?.trainingDays.length ?? 3,
      lagging: hero?.lagging.firstOrNull,
      level: trainingLevelOf(hero, program),
      split: hero?.format == TrainingFormat.split,
    );

/// Уровень по анкете героя.
TrainingLevel declaredLevelOf(HeroProfile? hero) => declaredLevel(
  experience: hero?.body.experience?.index ?? 0,
  pushUps: hero?.body.pushUps,
  pullUps: hero?.body.pullUps,
);

/// Уровень подготовки: по анкете или по делу — что выше.
TrainingLevel trainingLevelOf(HeroProfile? hero, UserProgram program) {
  final declared = declaredLevelOf(hero);
  final proven = provenLevel(
    completedWorkouts: program.completedWorkouts,
    stepOf: (p) => program.levelOf(p, start: declared.startStep),
  );
  return proven.index > declared.index ? proven : declared;
}

/// Стартовая ступень лесенки — по уровню из анкеты.
int startLevelOf(HeroProfile? hero) => declaredLevelOf(hero).startStep;

final todayPlanProvider = Provider<AdaptedDay>(
  (ref) => planForHero(ref.watch(programProvider), ref.watch(heroProvider)),
);

class LastPlanResultNotifier extends Notifier<PlanResult?> {
  @override
  PlanResult? build() => null;

  void show(PlanResult? result) => state = result;
}

final lastPlanResultProvider =
    NotifierProvider<LastPlanResultNotifier, PlanResult?>(
      LastPlanResultNotifier.new,
    );
