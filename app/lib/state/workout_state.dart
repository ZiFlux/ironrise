import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/anti_fraud.dart';
import '../game/muscles.dart';
import '../game/exercise_catalog.dart';
import '../game/game_config.dart';
import '../game/program.dart';
import '../game/set_effort.dart';
import '../game/streak_rewards.dart';
import '../game/warmup.dart';
import '../game/workout.dart';
import 'account_state.dart';
import 'consent_state.dart';
import 'health_state.dart';
import 'heart_rate_state.dart';
import 'program_state.dart';
import 'records_state.dart';
import 'training_log.dart';
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

  /// Сегодня силовая уже была: вторую не начать (лимит, как на сервере).
  bool get _doneToday => doneToday(
    ref.read(trainingLogProvider),
    WorkoutKind.strength,
    DateTime.now(),
  );

  List<String> _warmupFor(List<Exercise> exercises) => [
    for (final m in Warmup.forExercises(
      exercises,
      ref.read(programProvider).equipment,
    ))
      m.id,
  ];

  void start() {
    if (state != null || _doneToday) return;
    _save(
      WorkoutSession(startedAt: DateTime.now(), warmup: _warmupFor(const [])),
    );
    ref.read(heartRateProvider.notifier).startWatch();
  }

  /// Тренировка по программе: упражнения дня уже добавлены, у каждого — цель.
  void startPlanned(ProgramDay day) {
    if (state != null || _doneToday) return;
    _save(
      WorkoutSession(
        startedAt: DateTime.now(),
        planDayId: day.id,
        warmup: _warmupFor([for (final e in day.exercises) e.exercise]),
        entries: [
          for (final plan in day.exercises)
            ExerciseEntry(exercise: plan.exercise, plan: plan),
        ],
      ),
    );
    ref.read(heartRateProvider.notifier).startWatch();
  }

  /// Отдельный комплекс отработки (skill_practice.dart): вне плана, у каждого
  /// подводящего — цель. Засчитывается в отработку после завершения.
  void startPractice(List<PlannedExercise> drills) {
    if (state != null || _doneToday || drills.isEmpty) return;
    _save(
      WorkoutSession(
        startedAt: DateTime.now(),
        warmup: _warmupFor([for (final e in drills) e.exercise]),
        entries: [
          for (final plan in drills)
            ExerciseEntry(exercise: plan.exercise, plan: plan),
        ],
      ),
    );
    ref.read(heartRateProvider.notifier).startWatch();
  }

  /// Отметить движение разминки сделанным (или снять отметку).
  void toggleWarmup(String moveId) {
    final session = state;
    if (session == null) return;
    final done = {...session.warmupDone};
    done.contains(moveId) ? done.remove(moveId) : done.add(moveId);
    _save(session.copyWith(warmupDone: done));
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

  /// Метка в журнал тренировки (п. 106): открыто упражнение, отдых кончился или пропущен.
  void mark(WorkoutEventKind kind, {String? exerciseId}) {
    final session = state;
    if (session == null) return;
    _save(session.withEvent(kind, exerciseId: exerciseId));
  }

  void logSet(int entryIndex, SetRecord set) => _updateEntry(
    entryIndex,
    (entry) => entry.withSet(
      SetRecord(
        weight: set.weight,
        reps: set.reps,
        at: set.at ?? DateTime.now(),
      ),
    ),
  );

  void undoLastSet(int entryIndex) =>
      _updateEntry(entryIndex, (entry) => entry.withoutLastSet());

  /// «Не получается» (п. 80): упражнение без подходов меняется на [to] с тем же
  /// планом; если подходы уже были — они остаются, а [to] встаёт следом с
  /// оставшимися подходами плана.
  void swapExercise(int entryIndex, Exercise to) {
    final session = state;
    if (session == null) return;
    if (session.entries.any((e) => e.exercise.id == to.id)) return;
    final entries = [...session.entries];
    final from = entries[entryIndex];
    final plan = from.plan;
    if (from.sets.isEmpty) {
      entries[entryIndex] = ExerciseEntry(
        exercise: to,
        plan: plan?.copyWith(exerciseId: to.id),
      );
    } else {
      final left = plan == null ? 0 : plan.sets - from.sets.length;
      entries.insert(
        entryIndex + 1,
        ExerciseEntry(
          exercise: to,
          plan: plan != null && left > 0
              ? plan.copyWith(exerciseId: to.id, sets: left)
              : null,
        ),
      );
    }
    _save(session.copyWith(entries: entries));
  }

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
    // Без согласия на данные о здоровье пульс не используется вовсе.
    final pulse = !ref.read(healthConsentProvider).allowsPulse
        ? live.take(0).toList()
        : live.isNotEmpty
        ? live
        : await ref
              .read(healthProvider.notifier)
              .heartRateBetween(session.startedAt, finishedAt);
    final report = AntiFraud.check(
      session: session,
      pulse: pulse,
      finishedAt: finishedAt,
      restingHeartRate: hero.restingHeartRate,
      unverified: hero.unverifiedValidity,
    );
    final boosters = hero.boosters;
    // Бустеры за серию: опыт ×1,5 и монеты ×2 — по одному на тренировку.
    final summary = boostedSummary(
      WorkoutScoring.summarize(
        session: session,
        xpBefore: hero.xp,
        validity: report.value,
        validityReport: report,
        finishedAt: finishedAt,
      ),
      hero.xp,
      xp: boosters.xp > 0,
      coins: boosters.coins > 0,
      comeback:
          hero.lastActiveDay != null && hero.currentStreak(finishedAt) == 0,
    );
    final streak = await ref
        .read(heroProvider.notifier)
        .applyWorkout(
          summary,
          finishedAt,
          muscles: MuscleMath.pointsOf([
            for (final e in session.entries)
              (exerciseId: e.exercise.id, sets: e.sets.length),
          ], summary.validity),
          usedBoosters: !boosters.isEmpty,
          grantStreak: !ref.read(accountProvider).signedIn,
        );
    ref.read(lastStreakRewardProvider.notifier).show(streak);
    ref.read(lastSummaryProvider.notifier).show(summary);
    ref
        .read(lastSetEffortProvider.notifier)
        .show(
          SetEffortAnalysis.of(
            session,
            pulse,
            restingHr: hero.restingHeartRate,
            maxHr: hero.maxHeartRate,
          ),
        );
    await _applyProgram(session, summary);
    await ref.read(recordsProvider.notifier).record(session, finishedAt);
    final hr = pulseSummary(pulse);
    await ref
        .read(trainingLogProvider.notifier)
        .add(
          LoggedWorkout(
            at: finishedAt,
            kind: WorkoutKind.strength,
            duration: finishedAt.difference(session.startedAt),
            xp: summary.totalXp,
            coins: summary.coins,
            verified: summary.isVerified,
            exercises: [
              for (final e in session.entries)
                if (e.sets.isNotEmpty) (id: e.exercise.id, sets: e.sets),
            ],
            gains: {for (final g in summary.gains) g.part: g.xp},
            avgHr: hr.avg,
            maxHr: hr.max,
          ),
        );
    _save(null);
    // Не ждём сети: итог уже на экране, отправка идёт в фоне.
    ref
        .read(accountProvider.notifier)
        .enqueueStrength(session, finishedAt, pulse);
    return summary;
  }

  /// Рабочие веса на следующий раз и бонус монет за тренировку по плану.
  Future<void> _applyProgram(
    WorkoutSession session,
    WorkoutSummary summary,
  ) async {
    if (session.planDayId == null) {
      // Вне плана: подводящие считаются отработкой (skill_practice.dart).
      await ref.read(programProvider.notifier).recordPractice(session);
      ref.read(lastPlanResultProvider.notifier).show(null);
      return;
    }
    final applied = await ref
        .read(programProvider.notifier)
        .applyWorkout(session);
    final bonus = session.planCompleted
        ? (summary.coins * GameConfig.planCoinBonus).round()
        : 0;
    if (bonus > 0) await ref.read(heroProvider.notifier).addCoins(bonus);
    ref
        .read(lastPlanResultProvider.notifier)
        .show(
          PlanResult(
            changes: applied.changes,
            bonusCoins: bonus,
            levelUps: applied.levelUps,
            skillsLearned: applied.skillsLearned,
            skillsRetry: applied.skillsRetry,
          ),
        );
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

/// Пульс по подходам последней силовой — для экрана итогов. null — нет данных.
class LastSetEffortNotifier extends Notifier<SetEffortAnalysis?> {
  @override
  SetEffortAnalysis? build() => null;

  void show(SetEffortAnalysis? analysis) => state = analysis;
}

final lastSetEffortProvider =
    NotifierProvider<LastSetEffortNotifier, SetEffortAnalysis?>(
      LastSetEffortNotifier.new,
    );
