import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/body_part.dart';
import '../game/program.dart';
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

  ProgramPhase get phase => ProgramPhase.after(completedWorkouts);

  /// Дни текущей фазы. «Старт» — всегда 3 тренировки в неделю, «База» — по формату.
  List<ProgramDay> days(int sessionsPerWeek) => switch (phase) {
    ProgramPhase.start => StartProgram.days(equipment),
    ProgramPhase.base => BaseProgram.days(equipment, sessionsPerWeek),
  };

  /// Зоны, которые сейчас бережём после «болит».
  Set<PainZone> avoidedZones(DateTime now) => {
    for (final r in painReports)
      if (now.difference(r.at).inDays < Wellbeing.avoidDays) r.zone,
  };

  /// План на сегодня: день фазы, точечное упражнение на отстающую часть («База»),
  /// облегчение и больные зоны.
  AdaptedDay planFor({required DateTime now, required int sessionsPerWeek, BodyPart? lagging}) {
    final all = days(sessionsPerWeek);
    var day = all[nextDayIndex % all.length];
    if (phase == ProgramPhase.base) day = BaseProgram.withAccessories(day, lagging, equipment);
    return Wellbeing.adapt(day, ease: easeNext, avoid: avoidedZones(now), equipment: equipment);
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
  }) => UserProgram(
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
    painReports: [for (final r in j['painReports'] as List? ?? const []) PainReport.fromJson(r)],
  );
}

class PainReport {
  const PainReport(this.zone, this.at);

  final PainZone zone;
  final DateTime at;

  Map<String, dynamic> toJson() => {'zone': zone.name, 'at': at.toIso8601String()};

  factory PainReport.fromJson(Map<String, dynamic> j) =>
      PainReport(PainZone.values.byName(j['zone']), DateTime.parse(j['at']));
}

/// Что приложение ответило на самочувствие.
class WellbeingResponse {
  const WellbeingResponse({required this.feeling, this.zone, this.easeNext = false, this.repeatedPain = false, this.plan});

  final Feeling feeling;
  final PainZone? zone;

  /// Следующая тренировка будет облегчена.
  final bool easeNext;

  /// Боль в этой зоне уже была недавно.
  final bool repeatedPain;

  /// План следующей тренировки после изменений.
  final AdaptedDay? plan;
}

/// Итог по программе для экрана итогов: что изменится в следующий раз.
class PlanResult {
  const PlanResult({required this.changes, required this.bonusCoins});

  final List<ProgressChange> changes;
  final int bonusCoins;
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

  /// Записать результат тренировки по плану: рабочие веса и следующий день.
  Future<List<ProgressChange>> applyWorkout(WorkoutSession session) async {
    if (session.planDayId == null) return const [];
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
    await _save(state.copyWith(
      progress: progress,
      nextDayIndex: state.nextDayIndex + 1,
      completedWorkouts: state.completedWorkouts + (session.planCompleted ? 1 : 0),
      // Облегчённая тренировка сделана — дальше обычный план.
      easeNext: false,
    ));
    return changes;
  }

  /// Только для разработки: сразу перейти в фазу «База» или вернуться в «Старт».
  Future<void> debugTogglePhase() => _save(state.copyWith(
    completedWorkouts: state.phase == ProgramPhase.start ? ProgramPhase.startWorkouts : 0,
  ));

  /// Самочувствие после тренировки (TRAINING_SYSTEM.md, раздел 6).
  Future<WellbeingResponse> recordWellbeing(Feeling feeling, {PainZone? zone}) async {
    final now = DateTime.now();
    switch (feeling) {
      case Feeling.ok:
        await _save(state.copyWith(hardInARow: 0));
        return const WellbeingResponse(feeling: Feeling.ok);
      case Feeling.hard:
        final hard = state.hardInARow + 1;
        final ease = hard >= Wellbeing.hardInARowToEase;
        await _save(state.copyWith(hardInARow: ease ? 0 : hard, easeNext: ease || state.easeNext));
        return WellbeingResponse(feeling: Feeling.hard, easeNext: ease, plan: ease ? planForHero(state, ref.read(heroProvider)) : null);
      case Feeling.pain:
        final where = zone ?? PainZone.other;
        final repeated = state.painReports.any(
          (r) => r.zone == where && now.difference(r.at) < Wellbeing.repeatWindow,
        );
        await _save(state.copyWith(painReports: [
          for (final r in state.painReports)
            if (now.difference(r.at) < Wellbeing.repeatWindow) r,
          PainReport(where, now),
        ]));
        return WellbeingResponse(feeling: Feeling.pain, zone: where, repeatedPain: repeated, plan: planForHero(state, ref.read(heroProvider)));
    }
  }

  Future<void> _save(UserProgram program) async {
    state = program;
    await ref.read(prefsProvider).setString(_programKey, jsonEncode(program.toJson()));
  }
}

final programProvider = NotifierProvider<ProgramNotifier, UserProgram>(ProgramNotifier.new);

/// План следующей тренировки с учётом героя: формат тренировок и отстающая часть.
AdaptedDay planForHero(UserProgram program, HeroProfile? hero) => program.planFor(
  now: DateTime.now(),
  sessionsPerWeek: hero?.trainingDays.length ?? 3,
  lagging: hero?.lagging.firstOrNull,
);

final todayPlanProvider = Provider<AdaptedDay>(
  (ref) => planForHero(ref.watch(programProvider), ref.watch(heroProvider)),
);

class LastPlanResultNotifier extends Notifier<PlanResult?> {
  @override
  PlanResult? build() => null;

  void show(PlanResult? result) => state = result;
}

final lastPlanResultProvider =
    NotifierProvider<LastPlanResultNotifier, PlanResult?>(LastPlanResultNotifier.new);
