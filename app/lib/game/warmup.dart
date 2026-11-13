import 'body_part.dart';
import 'exercise_catalog.dart';
import 'program.dart';

/// Разминка перед тренировкой (пункт 26 бэклога): лёгкое кардио и движения
/// для суставов и мышц, которые будут работать в основной части.
class Warmup {
  const Warmup._();

  static const maxMoves = 4;

  static bool _available(ExerciseGear gear, Equipment equipment) =>
      switch (gear) {
        ExerciseGear.none => true,
        ExerciseGear.dumbbells => true,
        ExerciseGear.gym => equipment == Equipment.gym,
      };

  /// Части тела, на которые приходится заметная доля нагрузки дня.
  static Set<BodyPart> partsOf(List<Exercise> exercises) {
    final parts = {
      for (final e in exercises)
        for (final s in e.shares.entries)
          if (s.value >= 0.2 && s.key != BodyPart.cardio) s.key,
    };
    return parts.isEmpty
        ? {BodyPart.chest, BodyPart.back, BodyPart.legs, BodyPart.core}
        : parts;
  }

  /// Кардио в начале, потом движения, покрывающие части тела дня (жадно).
  static List<WarmupMove> forExercises(
    List<Exercise> exercises,
    Equipment equipment,
  ) {
    final parts = partsOf(exercises);
    final moves = ExerciseCatalog.warmups
        .where((m) => _available(m.gear, equipment))
        .toList();
    final cardioOptions = moves.where((m) => m.isCardio).toList()
      // В зале — тренажёр; гребля, если день про спину. Дома — без прыжков сначала.
      ..sort((a, b) => _cardioRank(a, parts).compareTo(_cardioRank(b, parts)));
    final out = <WarmupMove>[if (cardioOptions.isNotEmpty) cardioOptions.first];
    final uncovered = {...parts};
    final mobility = moves.where((m) => !m.isCardio).toList();
    while (out.length <= maxMoves) {
      WarmupMove? best;
      var bestScore = 0;
      for (final m in mobility) {
        if (out.contains(m)) continue;
        final score = m.targets.where(uncovered.contains).length;
        if (score > bestScore) {
          best = m;
          bestScore = score;
        }
      }
      if (best == null) break;
      out.add(best);
      uncovered.removeAll(best.targets);
    }
    return out;
  }

  static int _cardioRank(WarmupMove m, Set<BodyPart> parts) {
    var rank = m.gear == ExerciseGear.gym ? 0 : 10;
    if (m.id == 'warm_rower' && !parts.contains(BodyPart.back)) rank += 5;
    if (m.id == 'warm_jumping_jacks') rank += 2;
    return rank;
  }

  /// Примерная длительность: секунды как есть, повтор ≈ 3 с, переходы по 15 с.
  static Duration duration(List<WarmupMove> moves) => Duration(
    seconds: moves.fold(
      0,
      (s, m) => s + (m.seconds ? m.amount : m.amount * 3) + 15,
    ),
  );
}
