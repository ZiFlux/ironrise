import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../game/anti_fraud.dart';
import '../game/body_part.dart';
import '../game/calendar.dart';
import '../game/workout.dart';
import 'calendar_export.dart';
import 'providers.dart';

const _logKey = 'training_log_v1';

/// Столько тренировок храним на телефоне (≈ 2 года по 5 в неделю).
const _maxEntries = 500;

enum WorkoutKind { strength, cardio }

/// Упражнение в журнале: подходы как записаны.
typedef LoggedExercise = ({String id, List<SetRecord> sets});

/// Завершённая тренировка: всё, что нужно статистике, лимиту в день и подбору упражнений.
class LoggedWorkout {
  const LoggedWorkout({
    required this.at,
    required this.kind,
    required this.duration,
    required this.xp,
    required this.coins,
    required this.verified,
    this.exercises = const [],
    this.gains = const {},
    this.activity,
    this.avgHr,
    this.maxHr,
  });

  /// Время окончания.
  final DateTime at;
  final WorkoutKind kind;
  final Duration duration;
  final int xp;
  final int coins;
  final bool verified;
  final List<LoggedExercise> exercises;
  final Map<BodyPart, int> gains;

  /// Вид кардио (CardioActivity.name).
  final String? activity;
  final int? avgHr;
  final int? maxHr;

  int get sets => exercises.fold(0, (n, e) => n + e.sets.length);

  /// Поднятый вес за тренировку, кг (вес × повторы).
  double get volume => exercises.fold(
    0,
    (v, e) => v + e.sets.fold(0, (s, set) => s + set.weight * set.reps),
  );

  Map<String, dynamic> toJson() => {
    'at': at.toIso8601String(),
    'kind': kind.name,
    'durationSec': duration.inSeconds,
    'xp': xp,
    'coins': coins,
    'verified': verified,
    if (exercises.isNotEmpty)
      'exercises': [
        for (final e in exercises)
          {
            'id': e.id,
            'sets': [for (final s in e.sets) s.toJson()],
          },
      ],
    if (gains.isNotEmpty)
      'gains': {for (final g in gains.entries) g.key.name: g.value},
    'activity': ?activity,
    'avgHr': ?avgHr,
    'maxHr': ?maxHr,
  };

  factory LoggedWorkout.fromJson(Map<String, dynamic> j) => LoggedWorkout(
    at: DateTime.parse(j['at']),
    kind: WorkoutKind.values.byName(j['kind']),
    duration: Duration(seconds: j['durationSec'] ?? 0),
    xp: j['xp'] ?? 0,
    coins: j['coins'] ?? 0,
    verified: j['verified'] ?? false,
    exercises: [
      for (final e in (j['exercises'] as List? ?? const []))
        (
          id: e['id'] as String,
          sets: [for (final s in e['sets'] as List) SetRecord.fromJson(s)],
        ),
    ],
    gains: {
      for (final g in (j['gains'] as Map? ?? const {}).entries)
        ?BodyPart.values.asNameMap()[g.key]: (g.value as num).toInt(),
    },
    activity: j['activity'],
    avgHr: j['avgHr'],
    maxHr: j['maxHr'],
  );
}

/// Пульс тренировки одной сводкой: средний и максимальный.
({int? avg, int? max}) pulseSummary(List<PulseSample> pulse) {
  if (pulse.isEmpty) return (avg: null, max: null);
  final bpm = [for (final p in pulse) p.bpm];
  return (
    avg: (bpm.reduce((a, b) => a + b) / bpm.length).round(),
    max: bpm.reduce((a, b) => a > b ? a : b),
  );
}

/// Журнал тренировок на телефоне, от новых к старым.
class TrainingLogNotifier extends Notifier<List<LoggedWorkout>> {
  @override
  List<LoggedWorkout> build() {
    final raw = ref.read(prefsProvider).getString(_logKey);
    if (raw == null) return const [];
    try {
      return [
        for (final e in jsonDecode(raw) as List)
          LoggedWorkout.fromJson(Map<String, dynamic>.from(e)),
      ];
    } catch (_) {
      return const [];
    }
  }

  Future<void> add(LoggedWorkout workout) async {
    state = [workout, ...state].take(_maxEntries).toList();
    await ref
        .read(prefsProvider)
        .setString(_logKey, jsonEncode([for (final w in state) w.toJson()]));
    await ref.read(calendarExportProvider.notifier).export(workout);
  }
}

final trainingLogProvider =
    NotifierProvider<TrainingLogNotifier, List<LoggedWorkout>>(
      TrainingLogNotifier.new,
    );

/// Лимит: одна силовая и одна кардио за календарный день (как на сервере).
bool doneToday(List<LoggedWorkout> log, WorkoutKind kind, DateTime now) {
  final today = dayKey(now);
  return log.any((w) => w.kind == kind && dayKey(w.at) == today);
}
