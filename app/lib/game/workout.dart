import 'body_part.dart';
import 'exercise_catalog.dart';
import 'game_config.dart';
import 'progression.dart';

class SetRecord {
  const SetRecord({required this.weight, required this.reps});

  final double weight;

  /// Повторы или секунды, в зависимости от упражнения.
  final int reps;
}

class ExerciseEntry {
  const ExerciseEntry({required this.exercise, this.sets = const []});

  final Exercise exercise;
  final List<SetRecord> sets;

  bool get isFull => sets.length >= GameConfig.maxSetsPerExercise;

  ExerciseEntry withSet(SetRecord set) =>
      isFull ? this : ExerciseEntry(exercise: exercise, sets: [...sets, set]);

  ExerciseEntry withoutLastSet() => sets.isEmpty
      ? this
      : ExerciseEntry(exercise: exercise, sets: sets.sublist(0, sets.length - 1));
}

class WorkoutSession {
  const WorkoutSession({required this.startedAt, this.entries = const []});

  final DateTime startedAt;
  final List<ExerciseEntry> entries;

  int get totalSets => entries.fold(0, (sum, e) => sum + e.sets.length);

  WorkoutSession copyWith({List<ExerciseEntry>? entries}) =>
      WorkoutSession(startedAt: startedAt, entries: entries ?? this.entries);
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
  });

  final Duration duration;
  final int totalSets;

  /// Только части, получившие опыт, по убыванию опыта.
  final List<PartGain> gains;
  final int coins;
  final double validity;

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
    );
  }

  static Map<BodyPart, int> _earnedXp(
    WorkoutSession session,
    Set<BodyPart> lagging,
    double validity,
  ) {
    final raw = <BodyPart, double>{};
    for (final entry in session.entries) {
      final countedSets = entry.sets.length.clamp(0, GameConfig.maxSetsPerExercise);
      for (final MapEntry(key: part, value: share) in entry.exercise.shares.entries) {
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
