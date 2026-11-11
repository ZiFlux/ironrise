import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/anti_fraud.dart';
import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/program.dart';
import '../game/workout.dart';
import 'account_state.dart';
import 'health_state.dart';
import 'heart_rate_state.dart';
import 'program_state.dart';
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
    if (state != null) return;
    _save(WorkoutSession(startedAt: DateTime.now()));
    ref.read(heartRateProvider.notifier).startWatch();
  }

  /// Тренировка по программе: упражнения дня уже добавлены, у каждого — цель.
  void startPlanned(ProgramDay day) {
    if (state != null) return;
    _save(WorkoutSession(
      startedAt: DateTime.now(),
      planDayId: day.id,
      entries: [
        for (final plan in day.exercises) ExerciseEntry(exercise: plan.exercise, plan: plan),
      ],
    ));
    ref.read(heartRateProvider.notifier).startWatch();
  }

  void setReserve(int entryIndex, bool hadReserve) =>
      _updateEntry(entryIndex, (entry) => entry.withReserve(hadReserve));

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

  void cancel() {
    _save(null);
    ref.read(heartRateProvider.notifier).stopWatch();
  }

  /// Закрыть тренировку, проверить пульс, начислить герою итог.
  Future<WorkoutSummary?> finish() async {
    final session = state;
    final hero = ref.read(heroProvider);
    if (session == null || hero == null || session.totalSets == 0) return null;

    final finishedAt = DateTime.now();
    ref.read(heartRateProvider.notifier).stopWatch();
    final live = ref
        .read(heartRateProvider.notifier)
        .samplesBetween(session.startedAt, finishedAt);
    // Пульс не транслировался по Bluetooth — берём записанный часами (Health Connect).
    final pulse = live.isNotEmpty
        ? live
        : await ref
              .read(healthProvider.notifier)
              .heartRateBetween(session.startedAt, finishedAt);
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
    await _applyProgram(session, summary);
    _save(null);
    // Не ждём сети: итог уже на экране, отправка идёт в фоне.
    ref
        .read(accountProvider.notifier)
        .enqueueStrength(session, finishedAt, pulse);
    return summary;
  }

  /// Рабочие веса на следующий раз и бонус монет за тренировку по плану.
  Future<void> _applyProgram(WorkoutSession session, WorkoutSummary summary) async {
    if (session.planDayId == null) {
      ref.read(lastPlanResultProvider.notifier).show(null);
      return;
    }
    final changes = await ref.read(programProvider.notifier).applyWorkout(session);
    final bonus = session.planCompleted ? (summary.coins * GameConfig.planCoinBonus).round() : 0;
    if (bonus > 0) await ref.read(heroProvider.notifier).addCoins(bonus);
    ref.read(lastPlanResultProvider.notifier).show(PlanResult(changes: changes, bonusCoins: bonus));
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
