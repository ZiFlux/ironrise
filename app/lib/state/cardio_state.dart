import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/cardio.dart';
import '../game/workout.dart';
import 'account_state.dart';
import 'health_state.dart';
import 'heart_rate_state.dart';
import 'providers.dart';
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
    if (state != null) return;
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
    final summary = CardioScoring.summarize(
      session: session,
      pulse: pulse,
      xpBefore: hero.xp,
      finishedAt: finishedAt,
      restingHeartRate: hero.restingHeartRate,
      maxHeartRate: hero.maxHeartRate,
    );
    await ref.read(heroProvider.notifier).applyWorkout(summary, finishedAt);
    ref.read(lastSummaryProvider.notifier).show(summary);
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
