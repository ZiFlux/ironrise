import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'account_state.dart';
import 'cardio_state.dart';
import 'duel_state.dart';
import 'health_state.dart';
import 'heart_rate_state.dart';
import 'program_state.dart';
import 'providers.dart';
import 'settings.dart';
import 'workout_state.dart';

/// Стереть с телефона всё, что приложение о вас знает: героя, тренировки,
/// очередь отправки, вход, настройки. Адрес сервера беты сохраняется.
class LocalData {
  const LocalData(this.ref);

  final Ref ref;

  Future<void> wipe() async {
    final prefs = ref.read(prefsProvider);
    final serverUrl = prefs.getString(serverUrlKey);
    await ref.read(apiProvider).tokens.clear();
    await prefs.clear();
    if (serverUrl != null) await prefs.setString(serverUrlKey, serverUrl);
    for (final provider in [
      heroProvider,
      workoutProvider,
      lastSummaryProvider,
      programProvider,
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
  }
}

final localDataProvider = Provider<LocalData>(LocalData.new);
