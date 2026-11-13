import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/program.dart';
import '../game/workout.dart';
import 'providers.dart';

const _recordsKey = 'records_v1';

/// Лучший подход в упражнении: для оценки силы и раздела «Рекорды».
class BestLift {
  const BestLift({required this.weight, required this.reps, required this.at});

  final double weight;
  final int reps;
  final DateTime at;

  /// Расчётный максимум; null — подход вне 1–12 повторов или без веса.
  double? get oneRepMax =>
      estimatedOneRepMax(SetRecord(weight: weight, reps: reps));

  Map<String, dynamic> toJson() => {
    'weight': weight,
    'reps': reps,
    'at': at.toIso8601String(),
  };

  factory BestLift.fromJson(Map<String, dynamic> j) => BestLift(
    weight: (j['weight'] as num).toDouble(),
    reps: j['reps'],
    at: DateTime.parse(j['at']),
  );
}

/// Статистика игрока за всё время, хранится на телефоне.
class TrainingRecords {
  const TrainingRecords({
    this.workouts = 0,
    this.sets = 0,
    this.best = const {},
  });

  final int workouts;
  final int sets;
  final Map<String, BestLift> best;

  Map<String, dynamic> toJson() => {
    'workouts': workouts,
    'sets': sets,
    'best': {for (final e in best.entries) e.key: e.value.toJson()},
  };

  factory TrainingRecords.fromJson(Map<String, dynamic> j) => TrainingRecords(
    workouts: j['workouts'] ?? 0,
    sets: j['sets'] ?? 0,
    best: {
      for (final e in (j['best'] as Map<String, dynamic>? ?? {}).entries)
        e.key: BestLift.fromJson(e.value),
    },
  );
}

class RecordsNotifier extends Notifier<TrainingRecords> {
  @override
  TrainingRecords build() {
    final raw = ref.read(prefsProvider).getString(_recordsKey);
    if (raw == null) return const TrainingRecords();
    try {
      return TrainingRecords.fromJson(jsonDecode(raw));
    } catch (_) {
      return const TrainingRecords();
    }
  }

  /// Учесть завершённую силовую тренировку: счётчики и лучшие подходы.
  Future<void> record(WorkoutSession session, DateTime finishedAt) async {
    final best = {...state.best};
    for (final entry in session.entries) {
      for (final set in entry.sets) {
        final current = best[entry.exercise.id];
        if (current == null || _isBetter(set, current)) {
          best[entry.exercise.id] = BestLift(
            weight: set.weight,
            reps: set.reps,
            at: finishedAt,
          );
        }
      }
    }
    state = TrainingRecords(
      workouts: state.workouts + 1,
      sets: state.sets + session.totalSets,
      best: best,
    );
    await ref
        .read(prefsProvider)
        .setString(_recordsKey, jsonEncode(state.toJson()));
  }

  /// С весом — по расчётному максимуму, без веса — по повторам.
  static bool _isBetter(SetRecord set, BestLift current) {
    if (set.weight <= 0) return set.reps > current.reps;
    final candidate = estimatedOneRepMax(set) ?? set.weight;
    final existing = current.oneRepMax ?? current.weight;
    return candidate > existing;
  }
}

final recordsProvider = NotifierProvider<RecordsNotifier, TrainingRecords>(
  RecordsNotifier.new,
);
