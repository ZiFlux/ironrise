import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/workout.dart';
import 'providers.dart';

/// Текущая тренировка. null — тренировка не начата.
class WorkoutNotifier extends Notifier<WorkoutSession?> {
  @override
  WorkoutSession? build() => null;

  void start() => state ??= WorkoutSession(startedAt: DateTime.now());

  void addExercise(Exercise exercise) {
    final session = state;
    if (session == null) return;
    if (session.entries.any((e) => e.exercise.id == exercise.id)) return;
    state = session.copyWith(entries: [...session.entries, ExerciseEntry(exercise: exercise)]);
  }

  void logSet(int entryIndex, SetRecord set) =>
      _updateEntry(entryIndex, (entry) => entry.withSet(set));

  void undoLastSet(int entryIndex) =>
      _updateEntry(entryIndex, (entry) => entry.withoutLastSet());

  void removeExercise(int entryIndex) {
    final session = state;
    if (session == null) return;
    state = session.copyWith(entries: [...session.entries]..removeAt(entryIndex));
  }

  void cancel() => state = null;

  /// Закрыть тренировку, начислить герою итог и вернуть его для экрана итогов.
  Future<WorkoutSummary?> finish() async {
    final session = state;
    final hero = ref.read(heroProvider);
    if (session == null || hero == null || session.totalSets == 0) return null;

    final finishedAt = DateTime.now();
    final summary = WorkoutScoring.summarize(
      session: session,
      xpBefore: hero.xp,
      validity: GameConfig.unverifiedValidity, // часы ещё не подключены
      finishedAt: finishedAt,
    );
    await ref.read(heroProvider.notifier).applyWorkout(summary, finishedAt);
    ref.read(lastSummaryProvider.notifier).show(summary);
    state = null;
    return summary;
  }

  void _updateEntry(int index, ExerciseEntry Function(ExerciseEntry) change) {
    final session = state;
    if (session == null) return;
    final entries = [...session.entries];
    entries[index] = change(entries[index]);
    state = session.copyWith(entries: entries);
  }
}

final workoutProvider = NotifierProvider<WorkoutNotifier, WorkoutSession?>(WorkoutNotifier.new);

/// Итог последней тренировки для экрана итогов.
class LastSummaryNotifier extends Notifier<WorkoutSummary?> {
  @override
  WorkoutSummary? build() => null;

  void show(WorkoutSummary summary) => state = summary;
}

final lastSummaryProvider =
    NotifierProvider<LastSummaryNotifier, WorkoutSummary?>(LastSummaryNotifier.new);
