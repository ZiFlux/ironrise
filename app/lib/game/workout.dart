import 'anti_fraud.dart';
import 'body_part.dart';
import 'exercise_catalog.dart';
import 'game_config.dart';
import 'progression.dart';
import 'program.dart';

class SetRecord {
  const SetRecord({required this.weight, required this.reps});

  final double weight;

  /// Повторы или секунды, в зависимости от упражнения.
  final int reps;

  Map<String, dynamic> toJson() => {'weight': weight, 'reps': reps};

  factory SetRecord.fromJson(Map<String, dynamic> j) =>
      SetRecord(weight: (j['weight'] as num).toDouble(), reps: j['reps']);
}

class ExerciseEntry {
  const ExerciseEntry({
    required this.exercise,
    this.sets = const [],
    this.plan,
    this.hadReserve,
  });

  final Exercise exercise;
  final List<SetRecord> sets;

  /// Цель из программы тренировок; null — упражнение добавлено вне плана.
  final PlannedExercise? plan;

  /// Ответ «был запас?» после запланированных подходов; null — не отвечал.
  final bool? hadReserve;

  bool get isFull => sets.length >= GameConfig.maxSetsPerExercise;

  bool get planDone => plan != null && sets.length >= plan!.sets;

  ExerciseEntry _copy({List<SetRecord>? sets, bool? hadReserve}) => ExerciseEntry(
    exercise: exercise,
    sets: sets ?? this.sets,
    plan: plan,
    hadReserve: hadReserve ?? this.hadReserve,
  );

  ExerciseEntry withSet(SetRecord set) => isFull ? this : _copy(sets: [...sets, set]);

  ExerciseEntry withoutLastSet() =>
      sets.isEmpty ? this : _copy(sets: sets.sublist(0, sets.length - 1));

  ExerciseEntry withReserve(bool reserve) => _copy(hadReserve: reserve);

  Map<String, dynamic> toJson() => {
    'exercise': exercise.id,
    'sets': [for (final s in sets) s.toJson()],
    if (plan != null) 'plan': plan!.toJson(),
    if (hadReserve != null) 'hadReserve': hadReserve,
  };

  factory ExerciseEntry.fromJson(Map<String, dynamic> j) => ExerciseEntry(
    exercise: ExerciseCatalog.byId(j['exercise']),
    sets: [for (final s in j['sets'] as List) SetRecord.fromJson(s)],
    plan: j['plan'] == null ? null : PlannedExercise.fromJson(j['plan']),
    hadReserve: j['hadReserve'],
  );
}

class WorkoutSession {
  const WorkoutSession({
    required this.startedAt,
    this.entries = const [],
    this.planDayId,
  });

  final DateTime startedAt;
  final List<ExerciseEntry> entries;

  /// День программы («A», «B»); null — свободная тренировка.
  final String? planDayId;

  int get totalSets => entries.fold(0, (sum, e) => sum + e.sets.length);

  /// Все упражнения плана сделаны в запланированном числе подходов.
  bool get planCompleted {
    final planned = entries.where((e) => e.plan != null);
    return planDayId != null && planned.isNotEmpty && planned.every((e) => e.planDone);
  }

  WorkoutSession copyWith({List<ExerciseEntry>? entries}) =>
      WorkoutSession(startedAt: startedAt, entries: entries ?? this.entries, planDayId: planDayId);

  Map<String, dynamic> toJson() => {
    'startedAt': startedAt.toIso8601String(),
    'entries': [for (final e in entries) e.toJson()],
    if (planDayId != null) 'planDayId': planDayId,
  };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
    startedAt: DateTime.parse(j['startedAt']),
    entries: [for (final e in j['entries'] as List) ExerciseEntry.fromJson(e)],
    planDayId: j['planDayId'],
  );
}

/// Что получила одна часть тела за тренировку.
class PartGain {
  const PartGain({
    required this.part,
    required this.xp,
    required this.levelBefore,
    required this.levelAfter,
    required this.xpAfter,
    required this.wasLagging,
  });

  final BodyPart part;
  final int xp;
  final int levelBefore;
  final int levelAfter;
  final int xpAfter;
  final bool wasLagging;

  bool get leveledUp => levelAfter > levelBefore;
}

class WorkoutSummary {
  const WorkoutSummary({
    required this.duration,
    required this.totalSets,
    required this.gains,
    required this.coins,
    required this.validity,
    this.cardio,
    this.validityReport,
  });

  final Duration duration;
  final int totalSets;

  /// Есть только у кардио: вид активности и минуты в пульсовой зоне.
  final ({String activity, int zoneMinutes})? cardio;

  /// Только части, получившие опыт, по убыванию опыта.
  final List<PartGain> gains;
  final int coins;
  final double validity;

  /// Почему опыт урезан (только у силовой, посчитанной на телефоне).
  final ValidityReport? validityReport;

  int get totalXp => gains.fold(0, (sum, g) => sum + g.xp);

  bool get isVerified => validity >= 1;

  Map<BodyPart, int> applyTo(Map<BodyPart, int> xp) => {
    ...xp,
    for (final g in gains) g.part: g.xpAfter,
  };
}

/// Перевод подходов в опыт частей тела: XP = k_base · d · B · V (ТЗ 4.1).
/// Отстающие части определяются по уровням на начало тренировки.
class WorkoutScoring {
  const WorkoutScoring._();

  static WorkoutSummary summarize({
    required WorkoutSession session,
    required Map<BodyPart, int> xpBefore,
    required double validity,
    required DateTime finishedAt,
    ValidityReport? validityReport,
  }) {
    final levelsBefore = Progression.levels(xpBefore);
    final lagging = Progression.laggingParts(levelsBefore).toSet();
    final earned = _earnedXp(session, lagging, validity);

    final gains = [
      for (final MapEntry(key: part, value: xp) in earned.entries)
        if (xp > 0)
          PartGain(
            part: part,
            xp: xp,
            levelBefore: levelsBefore[part]!,
            levelAfter: Progression.levelFromXp(xpBefore[part]! + xp),
            xpAfter: xpBefore[part]! + xp,
            wasLagging: lagging.contains(part),
          ),
    ]..sort((a, b) => b.xp.compareTo(a.xp));
    final totalXp = gains.fold(0, (sum, g) => sum + g.xp);

    return WorkoutSummary(
      duration: finishedAt.difference(session.startedAt),
      totalSets: session.totalSets,
      gains: gains,
      coins: (totalXp * GameConfig.coinsPerXp).round(),
      validity: validity,
      validityReport: validityReport,
    );
  }

  static Map<BodyPart, int> _earnedXp(
    WorkoutSession session,
    Set<BodyPart> lagging,
    double validity,
  ) {
    final raw = <BodyPart, double>{};
    for (final entry in session.entries) {
      final countedSets = entry.sets.length.clamp(
        0,
        GameConfig.maxSetsPerExercise,
      );
      for (final MapEntry(key: part, value: share)
          in entry.exercise.shares.entries) {
        final perSet = Progression.xpForSet(
          share: share,
          isLagging: lagging.contains(part),
          validity: validity,
        );
        raw[part] = (raw[part] ?? 0) + perSet * countedSets;
      }
    }
    return raw.map((part, xp) => MapEntry(part, xp.round()));
  }
}
