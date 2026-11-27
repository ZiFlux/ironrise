import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/game_config.dart';
import '../game/cardio.dart';
import '../game/streak_rewards.dart';
import '../game/workout.dart';
import 'cardio_norms.dart';
import 'account_state.dart';
import 'consent_state.dart';
import 'health_state.dart';
import 'heart_rate_state.dart';
import 'providers.dart';
import 'training_log.dart';
import 'workout_state.dart';

const _cardioKey = 'cardio_session_v1';

/// Текущее кардио. Сохраняется, чтобы пережить закрытие приложения.
class CardioNotifier extends Notifier<CardioSession?> {
  @override
  CardioSession? build() {
    final raw = ref.read(prefsProvider).getString(_cardioKey);
    if (raw == null) return null;
    try {
      return CardioSession.fromJson(jsonDecode(raw));
    } catch (_) {
      return null;
    }
  }

  void start(CardioActivity activity) {
    final done = doneToday(
      ref.read(trainingLogProvider),
      WorkoutKind.cardio,
      DateTime.now(),
    );
    if (state != null || done) return;
    _save(CardioSession(startedAt: DateTime.now(), activity: activity));
    ref.read(heartRateProvider.notifier).startWatch();
  }

  void cancel() {
    _save(null);
    ref.read(heartRateProvider.notifier).stopWatch();
  }

  Future<WorkoutSummary?> finish() async {
    final session = state;
    final hero = ref.read(heroProvider);
    if (session == null || hero == null) return null;

    // Больше 2 часов не засчитывается: конец обрезаем — и в журнале, и на сервере
    // длительность не больше лимита, даже если кардио забыли выключить.
    final now = DateTime.now();
    final limit = session.startedAt.add(
      const Duration(minutes: GameConfig.cardioMaxMinutes),
    );
    final finishedAt = now.isAfter(limit) ? limit : now;
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
    final boosters = hero.boosters;
    final scored = CardioScoring.summarize(
      session: session,
      pulse: pulse,
      xpBefore: hero.xp,
      finishedAt: finishedAt,
      restingHeartRate: hero.restingHeartRate,
      maxHeartRate: hero.maxHeartRate,
      unverified: hero.unverifiedValidity,
      // Предварительный подсчёт — по своей норме вида, как посчитает сервер.
      zoneBound: cardioNormOf(
        ref.read(cardioNormsProvider).value,
        session.activity,
      )?.bound,
    );
    // Бустеры и возвращение — как у силовой и на сервере.
    final summary = boostedSummary(
      scored,
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
          usedBoosters: !boosters.isEmpty,
          grantStreak: !ref.read(accountProvider).signedIn,
        );
    ref.read(lastStreakRewardProvider.notifier).show(streak);
    ref.read(lastSummaryProvider.notifier).show(summary);
    final hr = pulseSummary(pulse);
    await ref
        .read(trainingLogProvider.notifier)
        .add(
          LoggedWorkout(
            at: finishedAt,
            kind: WorkoutKind.cardio,
            duration: finishedAt.difference(session.startedAt),
            xp: summary.totalXp,
            coins: summary.coins,
            verified: summary.isVerified,
            gains: {for (final g in summary.gains) g.part: g.xp},
            activity: session.activity.name,
            avgHr: hr.avg,
            maxHr: hr.max,
          ),
        );
    _save(null);
    // Не ждём сети: итог уже на экране, отправка идёт в фоне.
    ref
        .read(accountProvider.notifier)
        .enqueueCardio(session, finishedAt, pulse);
    return summary;
  }

  void _save(CardioSession? session) {
    state = session;
    final prefs = ref.read(prefsProvider);
    session == null
        ? prefs.remove(_cardioKey)
        : prefs.setString(_cardioKey, jsonEncode(session.toJson()));
  }
}

final cardioProvider = NotifierProvider<CardioNotifier, CardioSession?>(
  CardioNotifier.new,
);
