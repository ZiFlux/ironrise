import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_state.dart';
import 'api_cache.dart';
import 'cardio_state.dart';
import 'duel_state.dart';
import 'health_state.dart';
import 'heart_rate_state.dart';
import 'program_state.dart';
import 'records_state.dart';
import 'tips_state.dart';
import 'providers.dart';
import 'settings.dart';
import 'workout_state.dart';

/// Стереть с телефона всё, что приложение о вас знает: героя, тренировки,
/// очередь отправки, вход, настройки.
class LocalData {
  const LocalData(this.ref);

  final Ref ref;

  Future<void> wipe() async {
    final prefs = ref.read(prefsProvider);
    await ref.read(apiProvider).tokens.clear();
    await prefs.clear();
    for (final provider in [
      heroProvider,
      workoutProvider,
      lastSummaryProvider,
      programProvider,
      recordsProvider,
      tipsProvider,
      lastPlanResultProvider,
      cardioProvider,
      duelProvider,
      accountProvider,
      accentProvider,
      healthProvider,
      heartRateProvider,
    ]) {
      ref.invalidate(provider);
    }
    // Кэш ответов сервера держит копию в памяти — сбросить и её.
    ref.invalidate(apiCacheProvider);
  }
}

final localDataProvider = Provider<LocalData>(LocalData.new);
