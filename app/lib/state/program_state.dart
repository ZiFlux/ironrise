import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/program.dart';
import '../game/workout.dart';
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
  });

  final Equipment equipment;
  final int nextDayIndex;
  final int completedWorkouts;
  final Map<String, ExerciseProgress> progress;

  List<ProgramDay> get days => StartProgram.days(equipment);

  ProgramDay get today => days[nextDayIndex % days.length];

  ExerciseProgress progressOf(String exerciseId) =>
      progress[exerciseId] ?? const ExerciseProgress();

  UserProgram copyWith({
    Equipment? equipment,
    int? nextDayIndex,
    int? completedWorkouts,
    Map<String, ExerciseProgress>? progress,
  }) => UserProgram(
    equipment: equipment ?? this.equipment,
    nextDayIndex: nextDayIndex ?? this.nextDayIndex,
    completedWorkouts: completedWorkouts ?? this.completedWorkouts,
    progress: progress ?? this.progress,
  );

  Map<String, dynamic> toJson() => {
    'equipment': equipment.name,
    'nextDayIndex': nextDayIndex,
    'completedWorkouts': completedWorkouts,
    'progress': {for (final e in progress.entries) e.key: e.value.toJson()},
  };

  factory UserProgram.fromJson(Map<String, dynamic> j) => UserProgram(
    equipment: Equipment.values.byName(j['equipment']),
    nextDayIndex: j['nextDayIndex'] ?? 0,
    completedWorkouts: j['completedWorkouts'] ?? 0,
    progress: {
      for (final e in (j['progress'] as Map<String, dynamic>? ?? {}).entries)
        e.key: ExerciseProgress.fromJson(e.value),
    },
  );
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
    ));
    return changes;
  }

  Future<void> _save(UserProgram program) async {
    state = program;
    await ref.read(prefsProvider).setString(_programKey, jsonEncode(program.toJson()));
  }
}

final programProvider = NotifierProvider<ProgramNotifier, UserProgram>(ProgramNotifier.new);

class LastPlanResultNotifier extends Notifier<PlanResult?> {
  @override
  PlanResult? build() => null;

  void show(PlanResult? result) => state = result;
}

final lastPlanResultProvider =
    NotifierProvider<LastPlanResultNotifier, PlanResult?>(LastPlanResultNotifier.new);
