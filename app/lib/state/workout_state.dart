import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/anti_fraud.dart';
import '../game/exercise_catalog.dart';
import '../game/workout.dart';
import 'heart_rate_state.dart';
import 'providers.dart';

const _sessionKey = 'workout_session_v1';

/// Текущая тренировка. null — тренировка не начата.
/// Каждое изменение сохраняется, поэтому подходы переживают закрытие приложения.
class WorkoutNotifier extends Notifier<WorkoutSession?> {
  @override
  WorkoutSession? build() {
    final raw = ref.read(prefsProvider).getString(_sessionKey);
    if (raw == null) return null;
    try {
      return WorkoutSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  void start() {
    if (state == null) _save(WorkoutSession(startedAt: DateTime.now()));
  }

  void addExercise(Exercise exercise) {
    final session = state;
    if (session == null) return;
    if (session.entries.any((e) => e.exercise.id == exercise.id)) return;
    _save(
      session.copyWith(
        entries: [
          ...session.entries,
          ExerciseEntry(exercise: exercise),
        ],
      ),
    );
  }

  void logSet(int entryIndex, SetRecord set) =>
      _updateEntry(entryIndex, (entry) => entry.withSet(set));

  void undoLastSet(int entryIndex) =>
      _updateEntry(entryIndex, (entry) => entry.withoutLastSet());

  void removeExercise(int entryIndex) {
    final session = state;
    if (session == null) return;
    _save(
      session.copyWith(entries: [...session.entries]..removeAt(entryIndex)),
    );
  }

  void cancel() => _save(null);

  /// Закрыть тренировку, проверить пульс, начислить герою итог.
  Future<WorkoutSummary?> finish() async {
    final session = state;
    final hero = ref.read(heroProvider);
    if (session == null || hero == null || session.totalSets == 0) return null;

    final finishedAt = DateTime.now();
    final pulse = ref
        .read(heartRateProvider.notifier)
        .samplesBetween(session.startedAt, finishedAt);
    final summary = WorkoutScoring.summarize(
      session: session,
      xpBefore: hero.xp,
      validity: AntiFraud.validity(
        session: session,
        pulse: pulse,
        finishedAt: finishedAt,
        restingHeartRate: hero.restingHeartRate,
      ),
      finishedAt: finishedAt,
    );
    await ref.read(heroProvider.notifier).applyWorkout(summary, finishedAt);
    ref.read(lastSummaryProvider.notifier).show(summary);
    _save(null);
    return summary;
  }

  void _updateEntry(int index, ExerciseEntry Function(ExerciseEntry) change) {
    final session = state;
    if (session == null) return;
    final entries = [...session.entries];
    entries[index] = change(entries[index]);
    _save(session.copyWith(entries: entries));
  }

  void _save(WorkoutSession? session) {
    state = session;
    final prefs = ref.read(prefsProvider);
    session == null
        ? prefs.remove(_sessionKey)
        : prefs.setString(_sessionKey, jsonEncode(session.toJson()));
  }
}

final workoutProvider = NotifierProvider<WorkoutNotifier, WorkoutSession?>(
  WorkoutNotifier.new,
);

/// Итог последней тренировки для экрана итогов.
class LastSummaryNotifier extends Notifier<WorkoutSummary?> {
  @override
  WorkoutSummary? build() => null;

  void show(WorkoutSummary summary) => state = summary;
}

final lastSummaryProvider =
    NotifierProvider<LastSummaryNotifier, WorkoutSummary?>(
      LastSummaryNotifier.new,
    );
