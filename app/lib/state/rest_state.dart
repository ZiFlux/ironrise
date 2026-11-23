import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/circuit_rest.dart';
import '../game/goal_path.dart';
import 'program_state.dart';
import 'providers.dart';

const _restKey = 'rest_seconds_v1';

/// Варианты отдыха между подходами в настройках; null — по главной цели.
const restChoices = <int?>[null, 60, 90, 120, 150, 180];

/// Свой отдых между подходами (п. 107): секунды или null — по главной цели (п. 117).
class RestNotifier extends Notifier<int?> {
  @override
  int? build() => ref.read(prefsProvider).getInt(_restKey);

  Future<void> set(int? seconds) async {
    state = seconds;
    final prefs = ref.read(prefsProvider);
    seconds == null
        ? await prefs.remove(_restKey)
        : await prefs.setInt(_restKey, seconds);
  }
}

final restSettingProvider = NotifierProvider<RestNotifier, int?>(
  RestNotifier.new,
);

/// Отдых между подходами: свой из настроек или по главной цели.
Duration restOf(WidgetRef ref) {
  final own = ref.read(restSettingProvider);
  return own != null
      ? Duration(seconds: own)
      : restFor(ref.read(heroProvider)?.goal);
}

/// «1:30», «2 мин», «45 с».
String restLabel(Duration d) {
  final s = d.inSeconds;
  if (s < 60) return '$s с';
  if (s % 60 == 0) return '${s ~/ 60} мин';
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

const _circuitKey = 'circuit_rest_v1';

/// Отдых между кардио-упражнениями (circuit_rest.dart): null — ещё не было
/// ответов, берётся старт по уровню.
class CircuitRestNotifier extends Notifier<CircuitRest?> {
  @override
  CircuitRest? build() {
    final raw = ref.read(prefsProvider).getString(_circuitKey);
    if (raw == null) return null;
    try {
      return CircuitRest.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  CircuitRest current() =>
      state ??
      CircuitRest.start(
        trainingLevelOf(ref.read(heroProvider), ref.read(programProvider)),
      );

  /// Ответ после тренировки «каким был темп кардио».
  Future<CircuitRest> answer(CircuitPace pace) async {
    final next = current().after(pace);
    state = next;
    await ref
        .read(prefsProvider)
        .setString(_circuitKey, jsonEncode(next.toJson()));
    return next;
  }
}

final circuitRestProvider = NotifierProvider<CircuitRestNotifier, CircuitRest?>(
  CircuitRestNotifier.new,
);

/// Была ли в последней тренировке кардио-часть — спросить о темпе на экране итогов.
class LastCircuitNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void show(bool had) => state = had;
}

final lastCircuitProvider = NotifierProvider<LastCircuitNotifier, bool>(
  LastCircuitNotifier.new,
);
