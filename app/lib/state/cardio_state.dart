import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/cardio.dart';
import '../game/workout.dart';
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
  }

  void cancel() => _save(null);

  Future<WorkoutSummary?> finish() async {
    final session = state;
    final hero = ref.read(heroProvider);
    if (session == null || hero == null) return null;

    final finishedAt = DateTime.now();
    final summary = CardioScoring.summarize(
      session: session,
      pulse: ref
          .read(heartRateProvider.notifier)
          .samplesBetween(session.startedAt, finishedAt),
      xpBefore: hero.xp,
      finishedAt: finishedAt,
      restingHeartRate: hero.restingHeartRate,
      maxHeartRate: hero.maxHeartRate,
    );
    await ref.read(heroProvider.notifier).applyWorkout(summary, finishedAt);
    ref.read(lastSummaryProvider.notifier).show(summary);
    _save(null);
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
